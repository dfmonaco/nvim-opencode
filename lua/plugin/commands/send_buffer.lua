local state = require("plugin.state")
local Client = require("plugin.client")
local Notify = require("plugin.notify")
local Content = require("plugin.util.content")

---Sends current buffer content (or visual selection) to OpenCode session
---@return nil
local function send()
	local port = state.get_port()
	local session_id = state.get_session_id()

	if not port then
		Notify.error("No OpenCode server port found. Please open OC terminal first.")
		return
	end

	if not session_id then
		Notify.error("No OpenCode session ID found. Please ensure OC terminal is running.")
		return
	end

	local content, err = Content.get_content()
	if not content then
		Notify.warn(err or "Buffer is empty, nothing to send.")
		return
	end

	local client = Client.get_or_create_client()

	local message_parts = {
		{
			type = "text",
			text = content,
		},
	}

	client:send_message_async(session_id, message_parts, nil, function(send_err, success)
		if send_err then
			Notify.error("Failed to send buffer: " .. send_err)
		elseif success then
			Notify.info("Buffer sent to OpenCode session")
		end
	end)
end

return {
	send = send,
}
