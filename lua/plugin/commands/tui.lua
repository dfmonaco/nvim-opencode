local State = require("plugin.state")
local Client = require("plugin.client")
local Notify = require("plugin.notify")
local Content = require("plugin.util.content")

local M = {}

---Append the current buffer or visual selection to the TUI prompt.
---The TUI prompt is pre-filled; the user submits manually from the TUI.
---Requires the OpenCode TUI to be running (port must be set in state).
---@return nil
function M.append()
	local port = State.get_port()
	if not port then
		Notify.error("No OpenCode server port found. Please open OC terminal first.")
		return
	end

	local content, err = Content.get_content()
	if not content then
		Notify.warn(err or "Buffer is empty, nothing to append.")
		return
	end

	local client = Client.get_or_create_client(port)
	client:tui_append_prompt(content, function(req_err, success)
		if req_err then
			Notify.error("Failed to append to TUI prompt: " .. req_err)
		elseif success then
			Notify.info("Appended to TUI prompt")
		end
	end)
end

---Append the current buffer or visual selection to the TUI prompt and immediately submit it.
---Equivalent to appending text then pressing Enter in the TUI.
---Requires the OpenCode TUI to be running (port must be set in state).
---@return nil
function M.append_and_submit()
	local port = State.get_port()
	if not port then
		Notify.error("No OpenCode server port found. Please open OC terminal first.")
		return
	end

	local content, err = Content.get_content()
	if not content then
		Notify.warn(err or "Buffer is empty, nothing to send.")
		return
	end

	local client = Client.get_or_create_client(port)
	client:tui_append_prompt(content, function(append_err, success)
		if append_err then
			Notify.error("Failed to append to TUI prompt: " .. append_err)
			return
		end

		if not success then
			Notify.error("TUI append returned unexpected response")
			return
		end

		client:tui_submit_prompt(function(submit_err, submitted)
			if submit_err then
				Notify.error("Failed to submit TUI prompt: " .. submit_err)
			elseif submitted then
				Notify.info("Prompt submitted to TUI")
			end
		end)
	end)
end

---Execute a named TUI command (e.g. "session.interrupt", "session.new", "agent.cycle").
---Requires the OpenCode TUI to be running (port must be set in state).
---@param command string TUI command name (see TuiCommandName type in client.lua)
---@return nil
function M.execute(command)
	if not command or command == "" then
		Notify.error("No TUI command specified.")
		return
	end

	local port = State.get_port()
	if not port then
		Notify.error("No OpenCode server port found. Please open OC terminal first.")
		return
	end

	local client = Client.get_or_create_client(port)
	client:tui_execute_command(command, function(req_err, success)
		if req_err then
			Notify.error("Failed to execute TUI command '" .. command .. "': " .. req_err)
		elseif success then
			Notify.info("TUI command '" .. command .. "' executed")
		end
	end)
end

return M
