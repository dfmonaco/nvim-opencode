local State = require("plugin.state")
local Client = require("plugin.client")
local Notify = require("plugin.notify")
local Content = require("plugin.util.content")

local M = {}

---@alias TuiCommandName
---| "session.list"
---| "session.new"
---| "session.share"
---| "session.interrupt"
---| "session.compact"
---| "session.page.up"
---| "session.page.down"
---| "session.line.up"
---| "session.line.down"
---| "session.half.page.up"
---| "session.half.page.down"
---| "session.first"
---| "session.last"
---| "prompt.clear"
---| "prompt.submit"
---| "agent.cycle"

---Return a ready-to-use HTTP client, or notify and return nil if no server port is set.
---@return OpenCodeClient|nil
local function get_client()
	local port = State.get_port()
	if not port then
		Notify.error("No OpenCode server port found. Please open OC terminal first.")
		return nil
	end
	return Client.get_or_create_client(port)
end

---Append the current buffer or visual selection to the TUI prompt.
---The TUI prompt is pre-filled; the user submits manually from the TUI.
---@return nil
function M.append()
	local client = get_client()
	if not client then return end

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
---@return nil
function M.append_and_submit()
	local client = get_client()
	if not client then return end

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

	local client = get_client()
	if not client then return end

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
---@return nil
function M.new_session()
	M.execute("session.new")
end

return M
