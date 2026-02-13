local state = require('plugin.state')
local Client = require('plugin.client')

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
    vim.notify(err or "Failed to allocate port for OpenCode terminal", vim.log.levels.ERROR)
    return
  end

  vim.cmd('vsplit | terminal opencode --port ' .. tostring(port))
  local new_buf = vim.api.nvim_get_current_buf()
  vim.bo[new_buf].buflisted = false
  state.set_terminal_buffer(new_buf)
  vim.api.nvim_set_current_win(current_win)
end

return {
  toggle = toggle,
}
