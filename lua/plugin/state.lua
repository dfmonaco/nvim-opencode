local M = {}

-- Private state for plugin buffers
local state = {
  terminal_bufnr = nil,
  ocprompt_bufnr = nil,
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

---Sets the OCPrompt buffer number
---@param bufnr number
function M.set_ocprompt_buffer(bufnr)
  state.ocprompt_bufnr = bufnr
end

---Gets the OCPrompt buffer number
---@return number|nil
function M.get_ocprompt_buffer()
  return state.ocprompt_bufnr
end

---Clears OCPrompt buffer reference
function M.clear_ocprompt_buffer()
  state.ocprompt_bufnr = nil
end

return M
