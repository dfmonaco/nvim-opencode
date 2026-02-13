local M = {}

-- Private state for plugin buffers
local state = {
  terminal_bufnr = nil,
  ocprompt_bufnr = nil,
  port = nil, -- Port allocated for client/server
  session_id = nil, -- Currently active OpenCode session ID
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

---Sets the allocated port number
---@param port number|nil
function M.set_port(port)
  state.port = port
end

---Gets the allocated port number
---@return number|nil
function M.get_port()
  return state.port
end

---Sets the session ID
---@param session_id string|nil
function M.set_session_id(session_id)
  state.session_id = session_id
end

---Gets the session ID
---@return string|nil
function M.get_session_id()
  return state.session_id
end

return M
