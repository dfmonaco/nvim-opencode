---@class SseSubscriber
---@field id number Unique subscriber ID
---@field pattern string Event type pattern ("*" for all, or exact type e.g. "session.idle")
---@field callback fun(event: table)

---@class SseState
---@field port number|nil Current server port
---@field directory string|nil Project root directory used to scope the SSE subscription
---@field job_id number|nil Job ID returned by vim.fn.jobstart()
---@field subscribers SseSubscriber[] Registered event subscribers
---@field connected boolean Whether currently connected
---@field next_subscriber_id number Next subscriber ID to assign
---@field line_buffer string Accumulated incomplete line data from on_stdout chunks

local Notify = require('plugin.notify')

local M = {}

---Internal state for SSE connection
---@type SseState
local state = {
	port = nil,
	directory = nil,
	job_id = nil,
	subscribers = {},
	connected = false,
	next_subscriber_id = 1,
	line_buffer = "",
}

-- ============================================================================
-- Subscriber Management
-- ============================================================================

---Subscribe to SSE events
---@param pattern string Event type pattern ("*" for all, or exact type e.g. "session.idle")
---@param callback fun(event: table)
---@return number subscriber_id ID that can be passed to unsubscribe()
function M.subscribe(pattern, callback)
	local id = state.next_subscriber_id
	state.next_subscriber_id = state.next_subscriber_id + 1
	table.insert(state.subscribers, { id = id, pattern = pattern, callback = callback })
	return id
end

---Unsubscribe a previously registered subscriber
---@param subscriber_id number ID returned from subscribe()
function M.unsubscribe(subscriber_id)
	for i, sub in ipairs(state.subscribers) do
		if sub.id == subscriber_id then
			table.remove(state.subscribers, i)
			return
		end
	end
end

-- ============================================================================
-- Event Dispatch
-- ============================================================================

---Dispatch a decoded event to all matching subscribers and fire the User autocmd.
---Each subscriber callback is pcall-wrapped so one bad handler cannot break others.
---@param event table Decoded SSE event (always has a "type" field)
local function dispatch_event(event)
	-- Fire Neovim User autocmd — primary extension point for users and internal modules
	vim.api.nvim_exec_autocmds("User", {
		pattern = "OpenCodeEvent",
		data = event,
	})

	-- Dispatch to programmatic subscribers (for internal plugin modules)
	for _, sub in ipairs(state.subscribers) do
		if sub.pattern == "*" or sub.pattern == event.type then
			local ok, err = pcall(sub.callback, event)
			if not ok then
				Notify.error(string.format("SSE subscriber error (pattern: %s): %s", sub.pattern, tostring(err)))
			end
		end
	end
end

-- ============================================================================
-- SSE Line Parsing
-- ============================================================================

---Process a chunk of raw stdout text from the curl SSE stream.
---Buffers incomplete lines across chunks, strips "data: " prefix, and dispatches
---complete events (delimited by blank lines) once fully accumulated.
---@param chunk string Raw stdout chunk from vim.system on_stdout
local function process_chunk(chunk)
	-- Append new chunk to any leftover partial line
	local buffer = state.line_buffer .. chunk

	-- Split on newlines — last element may be an incomplete line
	local lines = vim.split(buffer, "\n", { plain = true })

	-- The last element is either "" (chunk ended with \n) or a partial line
	state.line_buffer = table.remove(lines)

	local event_data_lines = {}

	for _, line in ipairs(lines) do
		-- Normalise Windows-style line endings
		line = line:gsub("\r$", "")

		if line == "" then
			-- Blank line = end of one SSE event
			if #event_data_lines > 0 then
				local json_str = table.concat(event_data_lines, "")
				event_data_lines = {}

				local ok, decoded = pcall(vim.json.decode, json_str)
				if ok and type(decoded) == "table" then
					dispatch_event(decoded)
				else
					Notify.warn(string.format("SSE: failed to decode event: %s", tostring(decoded)))
				end
			end
		else
			-- Accumulate data lines, stripping the "data: " SSE prefix
			local data = line:match("^data:%s?(.*)$")
			if data then
				table.insert(event_data_lines, data)
			end
			-- Lines starting with "event:", "id:", ":" (comments) etc. are intentionally ignored
		end
	end
end

-- ============================================================================
-- Connection Management
-- ============================================================================

---Connect to the OpenCode server SSE event stream at GET /event?directory=<dir>.
---Reads the project root from plugin state (set after GET /path succeeds).
---No-op if already connected to the same port.
---@param port number OpenCode server port
function M.connect(port)
	if state.connected and state.port == port and state.job_id then
		return
	end

	-- Disconnect from any previous port before switching
	if state.port and state.port ~= port then
		M.disconnect()
	end

	local directory = require('plugin.state').get_project_root()
	local encoded_dir = directory and vim.uri_encode(directory) or ''
	local url = string.format("http://127.0.0.1:%d/event?directory=%s", port, encoded_dir)

	state.port = port
	state.directory = directory
	state.connected = true
	state.line_buffer = ""

	-- Use vim.fn.jobstart (not vim.system) for SSE streaming.
	-- vim.system has been observed to drop rapid SSE events; jobstart with
	-- on_stdout delivers each chunk reliably as it arrives.
	local stderr_lines = {}
	state.job_id = vim.fn.jobstart(
		{ "curl", "-s", "-N", "-H", "Accept: text/event-stream", url },
		{
			on_stdout = vim.schedule_wrap(function(_, data)
				if not data then
					return
				end
				-- jobstart delivers stdout as a list of lines (already split on \n).
				-- Re-join with \n so process_chunk can handle line buffering uniformly.
				local chunk = table.concat(data, "\n")
				process_chunk(chunk)
			end),
			on_stderr = function(_, data)
				if data then
					for _, line in ipairs(data) do
						if line ~= "" then
							table.insert(stderr_lines, line)
						end
					end
				end
			end,
			on_exit = vim.schedule_wrap(function(_, code)
				state.connected = false
				state.job_id = nil
				state.line_buffer = ""

				-- 143 = SIGTERM (intentional disconnect via jobstop)
				if code ~= 0 and code ~= 143 then
					Notify.warn(string.format("SSE connection closed (exit %d)", code))
				end
			end),
		}
	)
end

---Disconnect from the SSE stream and clear all connection state.
function M.disconnect()
	if state.job_id then
		vim.fn.jobstop(state.job_id)
		state.job_id = nil
	end

	state.port = nil
	state.directory = nil
	state.connected = false
	state.line_buffer = ""
end

-- ============================================================================
-- Introspection (for testing)
-- ============================================================================

---Return a snapshot of internal state. Intended for use in tests only.
---@return SseState
function M.get_state()
	return {
		port = state.port,
		directory = state.directory,
		job_id = state.job_id,
		subscribers = vim.deepcopy(state.subscribers),
		connected = state.connected,
		next_subscriber_id = state.next_subscriber_id,
		line_buffer = state.line_buffer,
	}
end

return M
