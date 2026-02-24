---@module 'plugin.commands.slash_command'
local State = require('plugin.state')
local Client = require('plugin.client')
local Notify = require('plugin.notify')

local M = {}

---Format a slash command for display in the picker.
---@param cmd SlashCommand
---@return string
local function format_command(cmd)
  if cmd.description and cmd.description ~= '' then
    return '/' .. cmd.name .. '  ' .. cmd.description
  end
  return '/' .. cmd.name
end

---Open a picker showing all available slash commands and execute the selected one
---in the current session via POST /session/{sessionID}/command.
---@return nil
function M.pick()
  local client = Client.get_or_create_client()

  local session_id = State.get_session_id()
  if not session_id then
    Notify.error('No active session. Please open OC terminal first.')
    return
  end

  client:list_commands(function(err, commands)
    if err then
      Notify.error('Failed to fetch slash commands: ' .. err)
      return
    end

    if not commands or #commands == 0 then
      Notify.warn('No slash commands available.')
      return
    end

    vim.ui.select(commands, {
      prompt = 'Select slash command:',
      format_item = format_command,
    }, function(selected)
      if not selected then return end

      client:execute_command(session_id, selected.name, {}, function(exec_err, _)
        if exec_err then
          Notify.error('Failed to execute /' .. selected.name .. ': ' .. exec_err)
        else
          Notify.info('Executed /' .. selected.name)
        end
      end)
    end)
  end)
end

return M
