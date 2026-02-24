local State = require("plugin.state")
local Client = require("plugin.client")
local Notify = require("plugin.notify")
local Content = require("plugin.util.content")

local M = {}

---@alias TuiCommandName
---| "session.list"
---| "session.new"
---| "session.timeline"
---| "session.compact"
---| "session.share"
---| "session.unshare"
---| "session.undo"
---| "session.redo"
---| "session.sidebar.toggle"
---| "session.username_visible.toggle"
---| "session.toggle.conceal"
---| "session.toggle.timestamps"
---| "session.toggle.thinking"
---| "session.toggle.diffwrap"
---| "session.toggle.actions"
---| "session.toggle.scrollbar"
---| "session.page.up"
---| "session.page.down"
---| "session.line.up"
---| "session.line.down"
---| "session.half.page.up"
---| "session.half.page.down"
---| "session.first"
---| "session.last"
---| "session.messages_last_user"
---| "messages.copy"
---| "session.copy"
---| "session.export"
---| "session.child.next"
---| "session.child.previous"
---| "session.interrupt"
---| "prompt.submit"
---| "prompt.clear"
---| "prompt.paste"
---| "prompt.editor"
---| "model.list"
---| "model.cycle_recent"
---| "model.cycle_recent_reverse"
---| "model.cycle_favorite"
---| "model.cycle_favorite_reverse"
---| "agent.list"
---| "agent.cycle"
---| "agent.cycle.reverse"
---| "mcp.list"
---| "provider.connect"
---| "opencode.status"
---| "theme.switch"
---| "theme.switch_mode"
---| "help.show"
---| "docs.open"
---| "app.exit"
---| "app.debug"
---| "app.fps"
---| "terminal.suspend"
---| "terminal.title.toggle"

---Append the current buffer or visual selection to the TUI prompt.
---The TUI prompt is pre-filled; the user submits manually from the TUI.
---@return nil
function M.append()
	local client = Client.get_or_create_client()

	local content, err = Content.get_content()
	if not content then
		Notify.warn(err or "Buffer is empty, nothing to append.")
		return
	end

	client:tui_publish("tui.prompt.append", { text = content }, function(req_err, success)
		if req_err then
			Notify.error("Failed to append to TUI prompt: " .. req_err)
		elseif success then
			Notify.info("Appended to TUI prompt")
		end
	end)
end

---Append the current buffer or visual selection to the TUI prompt and immediately submit it.
---Equivalent to appending text then pressing Enter in the TUI.
---@param on_success? fun() Optional callback invoked after successful submit
---@return nil
function M.append_and_submit(on_success)
	local client = Client.get_or_create_client()

	local content, err = Content.get_content()
	if not content then
		Notify.warn(err or "Buffer is empty, nothing to send.")
		return
	end

	client:tui_publish("tui.prompt.append", { text = content }, function(append_err, success)
		if append_err then
			Notify.error("Failed to append to TUI prompt: " .. append_err)
			return
		end

		if not success then
			Notify.error("TUI append returned unexpected response")
			return
		end

		client:tui_publish("tui.command.execute", { command = "prompt.submit" }, function(submit_err, submitted)
			if submit_err then
				Notify.error("Failed to submit TUI prompt: " .. submit_err)
			elseif submitted then
				Notify.info("Prompt submitted to TUI")
				if on_success then
					on_success()
				end
			end
		end)
	end)
end

---@class TuiExecuteOpts
---@field silent? boolean Suppress success notification (errors are always shown)

---Execute a named TUI command (e.g. "session.interrupt", "session.new", "agent.cycle").
---This is the generic escape hatch; prefer named actions (interrupt, new_session) for known commands.
---@param command TuiCommandName|string TUI command name
---@param opts? TuiExecuteOpts
---@return nil
function M.execute(command, opts)
	if not command or command == "" then
		Notify.error("No TUI command specified.")
		return
	end

	local client = Client.get_or_create_client()

	client:tui_publish("tui.command.execute", { command = command }, function(req_err, success)
		if req_err then
			Notify.error("Failed to execute TUI command '" .. command .. "': " .. req_err)
		elseif success and not (opts and opts.silent) then
			Notify.info("TUI command '" .. command .. "' executed")
		end
	end)
end

---Interrupt the current AI run in the TUI.
---@return nil
function M.interrupt()
	M.execute("session.interrupt")
end

---Start a new session in the TUI.
---Creates a session via POST /session (which publishes session.created on the Bus so our SSE
---listener can track the new session ID), then navigates the TUI to the new session via
---tui.session.select. Sending tui.command.execute "session.new" is intentionally NOT used here
---because it only navigates the TUI to a blank home state without creating a session.
---@return nil
function M.new_session()
	local client = Client.get_or_create_client()

	client:create_session(function(err, session)
		if err then
			Notify.error("Failed to create session: " .. err)
			return
		end
		if not session or not session.id then
			Notify.error("Create session returned no ID")
			return
		end
		-- Navigate the TUI to the newly created session
		client:tui_publish("tui.session.select", { sessionID = session.id }, function(nav_err, _)
			if nav_err then
				Notify.warn("Session created but TUI navigation failed: " .. nav_err)
			end
		end)
	end)
end

return M
