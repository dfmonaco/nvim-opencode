local M = {}

---Returns a statusline component string showing the active OpenCode server port.
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
  local port = require('plugin.state').get_port()
  if port then
    return '[OC:' .. tostring(port) .. ']'
  end
  return ''
end

return M
