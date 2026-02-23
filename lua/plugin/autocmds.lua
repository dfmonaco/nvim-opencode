local M = {}

local Notify = require('plugin.notify')
local State = require('plugin.state')

---Register all plugin autocommands
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- React to OpenCode server-sent events via the User OpenCodeEvent autocmd.
  -- This is the central place for all event-driven notifications and side effects.
  -- Other modules and user config can register additional handlers on the same autocmd.
  vim.api.nvim_create_autocmd('User', {
    pattern = 'OpenCodeEvent',
    desc = 'Handle OpenCode SSE events',
    callback = function(ev)
      local event = ev.data
      if type(event) ~= 'table' then
        return
      end

      if event.type == 'session.idle' then
        Notify.info('Agent Finished')
      end

      if event.type == 'session.created' then
        local info = event.properties and event.properties.info
        if info and info.id then
          State.set_session_id(info.id)
        end
      end
    end,
  })
end

return M
