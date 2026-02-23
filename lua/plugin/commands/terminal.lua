local state = require('plugin.state')
local Client = require('plugin.client')
local Sse = require('plugin.sse')
local Notify = require('plugin.notify')

---Registers a global BufWinEnter autocmd that prevents any buffer other than the
---terminal buffer from being displayed in the terminal window.
---If an intruding buffer lands in the terminal window (e.g. from a file picker,
---file explorer, or :e command), it is redirected to the first non-terminal window
---and the terminal buffer is restored.
---This autocmd is registered once at terminal creation and lives for the lifetime
---of the terminal buffer (cleaned up via the BufDelete autocmd).
---@param buf number Terminal buffer number
local function setup_buf_guard(buf)
  vim.api.nvim_create_autocmd('BufWinEnter', {
    desc = 'Prevent non-terminal buffers from opening in the opencode terminal window',
    callback = function(ev)
      -- The terminal buffer itself entered — that's expected, do nothing
      if ev.buf == buf then
        return
      end
      -- Check all windows currently showing the intruder buffer.
      -- If any of them is tagged as the terminal window, an intrusion occurred.
      local intruder_term_win = nil
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        if vim.w[win].is_opencode_terminal then
          intruder_term_win = win
          break
        end
      end
      if not intruder_term_win then
        return
      end
      -- An intruder landed in the terminal window.
      -- Defer the swap to avoid re-entrancy issues during BufWinEnter.
      -- Restore the terminal buffer and redirect the intruder to the
      -- first available non-terminal window.
      local intruder_buf = ev.buf
      local term_win = intruder_term_win
      vim.schedule(function()
        -- Restore terminal buffer in terminal window
        if vim.api.nvim_win_is_valid(term_win) and vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_win_set_buf(term_win, buf)
        end
        -- Find first non-terminal window to redirect the intruder to
        local target_win = nil
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if not vim.w[w].is_opencode_terminal and vim.api.nvim_win_is_valid(w) then
            target_win = w
            break
          end
        end
        if target_win and vim.api.nvim_buf_is_valid(intruder_buf) then
          vim.api.nvim_win_set_buf(target_win, intruder_buf)
        end
        -- Redirect focus if it ended up on the terminal window
        if vim.api.nvim_get_current_win() == term_win and target_win and vim.api.nvim_win_is_valid(target_win) then
          vim.api.nvim_set_current_win(target_win)
        end
      end)
    end,
  })
end

---Finds the window currently displaying the terminal buffer.
---Checks the stored window ID first (O(1) fast path), then falls back to
---scanning all windows in case the stored ID is stale.
---@param buf number|nil Terminal buffer number
---@return number|nil win Window ID, or nil if not visible
local function find_terminal_win(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end

  -- Fast path: use stored window ID
  local stored = state.get_terminal_win()
  if stored and vim.api.nvim_win_is_valid(stored) then
    if vim.api.nvim_win_get_buf(stored) == buf then
      return stored
    end
    -- Stored win exists but no longer shows the terminal buf — clear stale entry
    state.set_terminal_win(nil)
  end

  -- Fallback: scan all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      state.set_terminal_win(win)
      return win
    end
  end

  return nil
end

---Toggles the terminal window.
---Creates if it doesn't exist, hides if visible, shows if hidden.
---Focus always returns to the original window.
---@return nil
local function toggle()
  local current_win = vim.api.nvim_get_current_win()
  local buf = state.get_terminal_buffer()
  local term_win = find_terminal_win(buf)

  -- Terminal window is visible: hide it (buffer stays loaded in memory)
  if term_win then
    vim.api.nvim_win_hide(term_win)
    state.set_terminal_win(nil)
    return
  end

  -- Terminal buffer exists but isn't visible: show it in a new right split
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.cmd('vsplit')
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(new_win, buf)
    state.set_terminal_win(new_win)
    vim.w[new_win].is_opencode_terminal = true
    vim.api.nvim_set_current_win(current_win)
    return
  end

  -- No buffer yet: allocate a port and create the terminal in a new right split
  local port, err = Client.allocate_port()
  if not port then
    Notify.error(err or 'Failed to allocate port for OpenCode terminal')
    return
  end

  vim.cmd('vsplit | terminal opencode --continue --port ' .. tostring(port))
  local new_buf = vim.api.nvim_get_current_buf()
  local new_win = vim.api.nvim_get_current_win()

  vim.bo[new_buf].buflisted = false
  vim.api.nvim_buf_set_name(new_buf, 'opencode://terminal')

  state.set_terminal_buffer(new_buf)
  state.set_port(port)

  state.set_terminal_win(new_win)
  vim.w[new_win].is_opencode_terminal = true
  setup_buf_guard(new_buf)

  vim.api.nvim_set_current_win(current_win)

  -- Disconnect SSE and clear all state when the terminal buffer is wiped
  -- (triggered by the opencode process exiting or an explicit :bdelete)
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = new_buf,
    once = true,
    callback = function()
      Sse.disconnect()
      state.set_terminal_buffer(nil)
      state.set_terminal_win(nil)
      state.set_session_id(nil)
      state.set_port(nil)
      vim.schedule(function()
        vim.cmd('redrawstatus')
      end)
    end,
  })

  -- Poll the health endpoint until the server is ready, then fetch the session ID
  vim.defer_fn(function()
    local client = Client.get_or_create_client()

    local max_attempts = 50
    local attempt = 0

    local function poll_health()
      attempt = attempt + 1

      client:get_health(function(health_err, health)
        if not health_err and health and health.healthy then
          vim.schedule(function()
            Notify.info('Connected to OpenCode Server at port ' .. tostring(port))
          end)
          client:get_latest_session_id(function(err_session, session_id)
            if not err_session and session_id then
              state.set_session_id(session_id)
              vim.schedule(function()
                Notify.info('Session ID: ' .. session_id)
                vim.cmd('redrawstatus')
              end)
              Sse.connect(port)
            else
              vim.schedule(function()
                Notify.warn('Failed to fetch session ID: ' .. (err_session or 'unknown error'))
              end)
            end
          end)
        elseif attempt < max_attempts then
          vim.defer_fn(poll_health, 100)
        else
          vim.schedule(function()
            Notify.warn('OpenCode server did not become healthy after 5 seconds')
          end)
        end
      end)
    end

    poll_health()
  end, 0)
end

return {
  toggle = toggle,
}
