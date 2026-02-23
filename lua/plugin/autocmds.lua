local M = {}

local Client = require('plugin.client')
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

  -- Gracefully dispose the directory-scoped OpenCode instance when Neovim exits.
  -- Uses a blocking curl call (acceptable here since we are in the shutdown path
  -- and async callbacks would never fire).
  vim.api.nvim_create_autocmd('VimLeavePre', {
    desc = 'Gracefully dispose OpenCode server instance on exit',
    callback = function()
      local port = State.get_port()
      local directory = State.get_project_root()
      if port and directory then
        Client.dispose_instance_sync(port, directory)
      end
    end,
  })
end

return M
