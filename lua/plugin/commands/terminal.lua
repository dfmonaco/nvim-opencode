local state = require('plugin.state')
local Client = require('plugin.client')
local Sse = require('plugin.sse')
local Notify = require('plugin.notify')

---Toggles the terminal window
---Creates if it doesn't exist, hides if visible, shows if hidden
---Focus always returns to the original window
---@return nil
local function toggle()
  -- Save current window ID
  local current_win = vim.api.nvim_get_current_win()
  local buf = state.get_terminal_buffer()

  -- Helper: Find a window displaying the terminal buffer
  local function find_terminal_win()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
          return win
        end
      end
    end
    return nil
  end

  local term_win = find_terminal_win()

  -- Hide by closing terminal window
  if term_win then
    vim.api.nvim_win_close(term_win, false)
    return
  end

  -- Terminal buffer exists but isn't visible: show in right split
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.cmd('vsplit')
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(new_win, buf)
    vim.api.nvim_set_current_win(current_win)
    return
  end

  -- No buffer: create terminal in right split with dynamic port
  local port, err = Client.allocate_port()
  if not port then
    Notify.error(err or 'Failed to allocate port for OpenCode terminal')
    return
  end

  vim.cmd('vsplit | terminal opencode --continue --port ' .. tostring(port))
  local new_buf = vim.api.nvim_get_current_buf()
  vim.bo[new_buf].buflisted = false
  state.set_terminal_buffer(new_buf)
  state.set_port(port)
  vim.api.nvim_set_current_win(current_win)

  -- Disconnect SSE when the terminal buffer is wiped (process killed or :bdelete)
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = new_buf,
    once = true,
    callback = function()
      Sse.disconnect()
      state.set_terminal_buffer(nil)
      state.set_session_id(nil)
      state.set_port(nil)
      vim.schedule(function()
        vim.cmd('redrawstatus')
      end)
    end,
  })

  -- Asynchronously fetch and store the latest session ID once server is ready
  vim.defer_fn(function()
    local client = Client.get_or_create_client()

    -- Poll health endpoint until server is ready (max 5 seconds)
    local max_attempts = 50
    local attempt = 0

    local function poll_health()
      attempt = attempt + 1

      client:get_health(function(health_err, health)
        if not health_err and health and health.healthy then
          vim.schedule(function()
            Notify.info('Connected to OpenCode Server at port ' .. tostring(port))
          end)
          -- Server ready, fetch latest session ID
          client:get_latest_session_id(function(err_session, session_id)
            if not err_session and session_id then
              state.set_session_id(session_id)
              vim.schedule(function()
                Notify.info('Session ID: ' .. session_id)
                vim.cmd('redrawstatus')
              end)
              -- Connect SSE stream now that the server is confirmed healthy
              Sse.connect(port)
            else
              vim.schedule(function()
                Notify.warn('Failed to fetch session ID: ' .. (err_session or 'unknown error'))
              end)
            end
          end)
        elseif attempt < max_attempts then
          -- Retry after 100ms
          vim.defer_fn(poll_health, 100)
        else
          -- Max attempts reached
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
