---@module 'plugin.commands.session_picker'
local State = require('plugin.state')
local Client = require('plugin.client')
local Notify = require('plugin.notify')

local M = {}

---Return a ready-to-use HTTP client, or notify and return nil if no server port is set.
---@return OpenCodeClient|nil
local function get_client()
  local port = State.get_port()
  if not port then
    Notify.error('No OpenCode server port found. Please open OC terminal first.')
    return nil
  end
  return Client.get_or_create_client(port)
end

---Format a session for display in the picker.
---Shows the session title when non-empty, otherwise falls back to the session ID.
---@param session Session
---@return string
local function format_session(session)
  if session.title and session.title ~= '' then
    return session.title
  end
  return session.id
end

---Open a fuzzy picker showing all available sessions and navigate the TUI to the selected one
---via POST /tui/select-session.
---@return nil
function M.pick()
  local client = get_client()
  if not client then return end

  client:list_sessions(function(err, sessions)
    if err then
      Notify.error('Failed to fetch sessions: ' .. err)
      return
    end

    if not sessions or #sessions == 0 then
      Notify.warn('No sessions available.')
      return
    end

    vim.ui.select(sessions, {
      prompt = 'Select session:',
      format_item = format_session,
    }, function(selected)
      if not selected then return end

      client:tui_publish('tui.session.select', { sessionID = selected.id }, function(nav_err, _)
        if nav_err then
          Notify.error('Failed to navigate to session: ' .. nav_err)
        end
      end)
    end)
  end)
end

return M
