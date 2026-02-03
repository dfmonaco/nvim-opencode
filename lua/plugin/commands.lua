local M = {}

local state = require('plugin.state')

---Toggles the terminal window
---Creates if it doesn't exist, hides if visible, shows if hidden
---Focus always returns to the original window
---@return nil
function M.open_terminal()
  -- Save current window ID
  local current_win = vim.api.nvim_get_current_win()
  
  -- Check if terminal window is currently visible
  if state.is_terminal_window_visible() then
    -- Hide the terminal window
    vim.api.nvim_win_close(state.get_terminal_window(), false)
    state.clear_terminal_window()
    return
  end
  
  -- Check if terminal buffer exists and is valid
  if state.is_terminal_buffer_valid() then
    -- Show the existing terminal buffer in a new window
    vim.cmd('vsplit')
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(new_win, state.get_terminal_buffer())
    state.set_terminal_window(new_win)
    
    -- Return focus to original window
    vim.api.nvim_set_current_win(current_win)
    return
  end
  
  -- Create new terminal buffer and window
  vim.cmd('vsplit | terminal')
  local new_win = vim.api.nvim_get_current_win()
  local new_buf = vim.api.nvim_get_current_buf()
  
  -- Make terminal buffer unlisted so it doesn't appear in buffer list
  vim.bo[new_buf].buflisted = false
  
  -- Store terminal state
  state.set_terminal_buffer(new_buf)
  state.set_terminal_window(new_win)
  
  -- Return focus to original window
  vim.api.nvim_set_current_win(current_win)
end

return M
