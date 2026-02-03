local M = {}

-- Private state for the terminal
local state = {
  terminal_bufnr = nil
}

---Sets the terminal buffer number
---@param bufnr number
function M.set_terminal_buffer(bufnr)
  state.terminal_bufnr = bufnr
end

---Gets the terminal buffer number
---@return number|nil
function M.get_terminal_buffer()
  return state.terminal_bufnr
end

---Checks if terminal buffer is valid
---@return boolean
function M.is_terminal_buffer_valid()
  return state.terminal_bufnr ~= nil and vim.api.nvim_buf_is_valid(state.terminal_bufnr)
end

return M
