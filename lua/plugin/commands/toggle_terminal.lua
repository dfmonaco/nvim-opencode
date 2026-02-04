local state = require('plugin.state')

---Toggles the terminal window
---Creates if it doesn't exist, hides if visible, shows if hidden
---Focus always returns to the original window
---@return nil
local function toggle_terminal()
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

  -- No buffer: create terminal in right split
  vim.cmd('vsplit | terminal opencode --port 60000')
  local new_buf = vim.api.nvim_get_current_buf()
  vim.bo[new_buf].buflisted = false
  state.set_terminal_buffer(new_buf)
  vim.api.nvim_set_current_win(current_win)
end

return toggle_terminal
