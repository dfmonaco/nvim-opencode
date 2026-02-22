local M = {}

-- Private state for the plugin. Example shape:
-- {
--   terminal_bufnr = 5,                          -- buffer running the OpenCode process
--   ocprompt_bufnr = 8,                          -- buffer used for prompt input
--   port           = 4096,                       -- port the OpenCode server is listening on
--   session_id     = "ses_abc123",               -- active session ID
--   client_cache   = {                           -- reusable HTTP client instances
--     ["http://127.0.0.1:4096"] = <OpenCodeClient>,
--   },
-- }

-- Private state for plugin buffers
local state = {
  terminal_bufnr = nil, -- Buffer number for the embedded terminal running the OpenCode process
  ocprompt_bufnr = nil, -- Buffer number for the OCPrompt input buffer (opens in current window)
  port = nil, -- Port allocated for client/server
  session_id = nil, -- Currently active OpenCode session ID
  ---@type table<string, any> Singleton cache of OpenCodeClient instances keyed by base_url
  client_cache = {},
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

---Gets the client cache table (keyed by base_url)
---@return table<string, any>
function M.get_client_cache()
  return state.client_cache
end

---Stores a client instance in the cache under the given base_url key
---@param base_url string Cache key (e.g. "http://127.0.0.1:4096")
---@param client any OpenCodeClient instance
function M.set_client_cache_entry(base_url, client)
  state.client_cache[base_url] = client
end

return M
