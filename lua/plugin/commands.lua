local M = {}

---Opens a new terminal window in a vertical split to the right
---Focus remains on the original window
---@return nil
function M.open_terminal()
  -- Save current window ID
  local current_win = vim.api.nvim_get_current_win()
  
  -- Open terminal in vertical split
  vim.cmd('vsplit | terminal')
  
  -- Return focus to original window
  vim.api.nvim_set_current_win(current_win)
end

return M
