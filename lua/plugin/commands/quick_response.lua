---@module 'plugin.commands.quick_response'
local Client = require('plugin.client')
local Notify = require('plugin.notify')

local M = {}

local QUICK_RESPONSES = {
  'Yes',
  'Agree, proceed',
  'Commit',
  'Recommendations?',
}

local CUSTOM_OPTION = 'Custom...'

---Send a quick response to opencode.
---Shows a menu with predefined options plus "Custom..." for free-form input.
---@return nil
function M.send()
  local client = Client.get_or_create_client()

  local options = vim.list_extend(vim.deepcopy(QUICK_RESPONSES), { CUSTOM_OPTION })

  vim.ui.select(options, {
    prompt = 'Quick response:',
  }, function(choice)
    if not choice then
      return
    end

    if choice == CUSTOM_OPTION then
      vim.ui.input({
        prompt = 'Enter custom response: ',
        default = '',
      }, function(input)
        if not input or input == '' then
          return
        end

        M.send_text(client, input)
      end)
    else
      M.send_text(client, choice)
    end
  end)
end

---Send text to the TUI prompt and submit it.
---@param client OpenCodeClient
---@param text string
---@return nil
local function send_text(client, text)
  client:tui_publish('tui.prompt.append', { text = text }, function(append_err, success)
    if append_err then
      Notify.error('Failed to append to TUI prompt: ' .. append_err)
      return
    end

    if not success then
      Notify.error('TUI append returned unexpected response')
      return
    end

    client:tui_publish('tui.command.execute', { command = 'prompt.submit' }, function(submit_err, submitted)
      if submit_err then
        Notify.error('Failed to submit TUI prompt: ' .. submit_err)
      elseif submitted then
        Notify.info('Quick response sent')
      end
    end)
  end)
end

M.send_text = send_text

return M
