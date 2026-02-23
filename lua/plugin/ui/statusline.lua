local M = {}

---Returns a statusline component string showing the active OpenCode server port
---and session ID (first 12 chars).
---Returns an empty string when no server is connected.
---
---Usage in a plain statusline:
---  vim.o.statusline = "%{%v:lua.require('plugin.ui.statusline').get_component()%} %f"
---
---Usage in lualine:
---  require('lualine').setup({
---    sections = {
---      lualine_x = { require('plugin.ui.statusline').get_component },
---    }
---  })
---
---@return string
function M.get_component()
  local state = require('plugin.state')
  local port = state.get_port()
  if not port then
    return ''
  end

  local session_id = state.get_session_id()
  local session_str = session_id and (' ' .. session_id:sub(1, 12)) or ' no-session'
  return '[OC:' .. tostring(port) .. session_str .. ']'
end

return M
