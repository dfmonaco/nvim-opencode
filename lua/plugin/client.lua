local State = require("plugin.state")

-- Constants
local DEFAULT_HOST = "127.0.0.1"
local DEFAULT_PORT = 4096

---@class HttpResponse
---@field status number HTTP status code
---@field body string Response body (raw string)
---@field headers table<string, string> Response headers

---@class HealthResponse
---@field healthy boolean Server health status
---@field version string Server version

---@class MessagePart
---@field type string Part type (e.g., "text")
---@field text string Part text content (for type="text")

---@class SendMessageAsyncOptions
---@field agent? string Optional agent name
---@field system? string Optional system message

---@class RequestOpts
---@field body? string Optional JSON body string
---@field headers? table<string, string> Optional HTTP headers to include

---@class NewClientOpts
---@field base_url? string Base URL of the OpenCode server (default: "http://127.0.0.1:4096")
---@field timeout? number Request timeout in milliseconds (default: 5000)

---@class OpenCodeClient
---@field base_url string Base URL of the OpenCode server
---@field timeout number Request timeout in milliseconds
local Client = {}
Client.__index = Client

---Parse a raw curl -i response into structured status, headers, and body
---@param raw string Raw stdout from curl (includes HTTP headers)
---@return HttpResponse
local function parse_curl_response(raw)
	local headers = {}
	local body = ""
	local status = 0

	local header_section, body_match = raw:match("^(.-)\r?\n\r?\n(.*)$")
	if header_section then
		body = body_match or ""

		local status_line = header_section:match("^HTTP/[%d%.]+%s+(%d+)")
		if status_line then
			status = tonumber(status_line) or 0
		end

		for line in header_section:gmatch("[^\r\n]+") do
			local key, value = line:match("^([^:]+):%s*(.+)$")
			if key and value then
				headers[key:lower()] = value
			end
		end
	else
		body = raw
	end

	return { status = status, headers = headers, body = body }
end

---Create a new OpenCode HTTP client
---@param opts? NewClientOpts
---@return OpenCodeClient
function Client.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Client)
	self.base_url = opts.base_url or string.format("http://%s:%d", DEFAULT_HOST, DEFAULT_PORT)
	self.timeout = opts.timeout or 5000
	return self
end

---Get or create a singleton client instance for the given port.
---Returns a cached client if one exists for the host:port combination, otherwise creates a new one.
---@param port? number Optional port number, defaults to state port or 4096
---@return OpenCodeClient
function Client.get_or_create_client(port)
	port = port or State.get_port() or DEFAULT_PORT
	local base_url = string.format("http://%s:%d", DEFAULT_HOST, port)

	local cache = State.get_client_cache()
	if not cache[base_url] then
		State.set_client_cache_entry(base_url, Client.new({ base_url = base_url }))
	end

	return State.get_client_cache()[base_url]
end

---Execute an HTTP request using curl.
---Supports an optional opts table for request body and custom headers.
---For backward compatibility, opts may be omitted and callback passed as the third argument.
---@param method string HTTP method (GET, POST, PATCH, DELETE, etc.)
---@param path string API endpoint path
---@param opts RequestOpts|fun(err: string|nil, response: HttpResponse|nil) Optional request options or callback
---@param callback? fun(err: string|nil, response: HttpResponse|nil) Callback function
---@return nil
function Client:request(method, path, opts, callback)
	-- Backward compatibility: allow request(method, path, callback)
	if type(opts) == "function" then
		callback = opts
		opts = {}
	end
	opts = opts or {}
	assert(type(callback) == "function", "request(): callback is required")

	local url = self.base_url .. path
	local curl_args = {
		"curl",
		"-s", -- Silent mode
		"-i", -- Include headers in output
		"-X",
		method,
		"--max-time",
		tostring(math.floor(self.timeout / 1000)),
	}

	-- Append custom headers
	if opts.headers then
		for key, value in pairs(opts.headers) do
			table.insert(curl_args, "-H")
			table.insert(curl_args, key .. ": " .. value)
		end
	end

	-- Append request body
	if opts.body then
		table.insert(curl_args, "-d")
		table.insert(curl_args, opts.body)
	end

	table.insert(curl_args, url)

	vim.system(curl_args, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback(result.stderr or "Request failed", nil)
				return
			end

			local response = parse_curl_response(result.stdout or "")
			callback(nil, response)
		end)
	end)
end

---Get server health status
---@param callback fun(err: string|nil, health: HealthResponse|nil)
---@return nil
function Client:get_health(callback)
	self:request("GET", "/global/health", function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("Health check failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse health response: " .. tostring(decoded), nil)
			return
		end

		---@type HealthResponse
		local health = {
			healthy = decoded.healthy or false,
			version = decoded.version or "unknown",
		}

		callback(nil, health)
	end)
end

---@class PathResponse
---@field home string
---@field state string
---@field config string
---@field worktree string
---@field directory string The canonical working directory the server instance was started in

---Get the server's canonical path info.
---The `directory` field is the exact value the server uses as its instance key —
---use this (not git rev-parse) when constructing the SSE ?directory= URL.
---@param callback fun(err: string|nil, path: PathResponse|nil)
---@return nil
function Client:get_path(callback)
	self:request("GET", "/path", function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("get_path failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse path response: " .. tostring(decoded), nil)
			return
		end

		callback(nil, decoded)
	end)
end

---Get the ID of the most recently active session.
---Returns the session with the latest 'time.updated' timestamp.
---@param callback fun(err: string|nil, session_id: string|nil)
---@return nil
function Client:get_latest_session_id(callback)
	self:request("GET", "/session", function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("Failed to fetch sessions with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse sessions response: " .. tostring(decoded), nil)
			return
		end

		-- Sessions are already sorted by time.updated descending
		if type(decoded) ~= "table" or #decoded == 0 then
			callback("No sessions found", nil)
			return
		end

		local latest_session = decoded[1]
		if not latest_session or not latest_session.id then
			callback("Invalid session data", nil)
			return
		end

		callback(nil, latest_session.id)
	end)
end

---Send a message to a session asynchronously (no wait for AI response).
---The AI response is delivered via Server-Sent Events on the /event endpoint.
---@param session_id string Session ID to send message to
---@param message_parts MessagePart[] Array of message parts
---@param opts? SendMessageAsyncOptions Optional parameters
---@param callback fun(err: string|nil, success: boolean|nil)
---@return nil
function Client:send_message_async(session_id, message_parts, opts, callback)
	opts = opts or {}

	local request_body = { parts = message_parts }

	if opts.agent then
		request_body.agent = opts.agent
	end
	if opts.system then
		request_body.system = opts.system
	end

	local ok, body_json = pcall(vim.json.encode, request_body)
	if not ok then
		callback("Failed to encode request body: " .. tostring(body_json), nil)
		return
	end

	local path = "/session/" .. session_id .. "/prompt_async"
	self:request("POST", path, {
		body = body_json,
		headers = { ["Content-Type"] = "application/json" },
	}, function(err, response)
		if err then
			callback(err, nil)
			return
		end

		-- 204 No Content is the expected success response
		if not response or response.status ~= 204 then
			local error_msg = "Send message failed with status: " .. (response and response.status or "unknown")
			if response and response.body and response.body ~= "" then
				error_msg = error_msg .. " - " .. response.body
			end
			callback(error_msg, nil)
			return
		end

		callback(nil, true)
	end)
end

---@class SessionInfo
---@field id string Session ID
---@field title string Session title
---@field parentID string|nil Parent session ID (if forked)

---Create a new session via POST /session.
---This calls Session.create() on the server, which publishes `session.created` on the Bus.
---The TUI will pick up the new session via its own SSE subscription and navigate to it.
---@param callback fun(err: string|nil, session: SessionInfo|nil)
---@return nil
function Client:create_session(callback)
	self:request("POST", "/session", {
		body = "{}",
		headers = { ["Content-Type"] = "application/json" },
	}, function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			local error_msg = "Create session failed with status: " .. (response and response.status or "unknown")
			if response and response.body and response.body ~= "" then
				error_msg = error_msg .. " - " .. response.body
			end
			callback(error_msg, nil)
			return
		end

		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse session response: " .. tostring(decoded), nil)
			return
		end

		callback(nil, decoded)
	end)
end

---Publish a typed event to the TUI via POST /tui/publish.
---This is the single transport for all TUI interactions.
---@param event_type string Event type string (e.g. "tui.prompt.append", "tui.command.execute")
---@param properties table Event-specific payload
---@param callback fun(err: string|nil, success: boolean|nil)
---@return nil
function Client:tui_publish(event_type, properties, callback)
	local ok, body_json = pcall(vim.json.encode, { type = event_type, properties = properties })
	if not ok then
		callback("Failed to encode request body: " .. tostring(body_json), nil)
		return
	end

	self:request("POST", "/tui/publish", {
		body = body_json,
		headers = { ["Content-Type"] = "application/json" },
	}, function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("TUI publish failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		callback(nil, true)
	end)
end

---Dispose the directory-scoped OpenCode instance using a blocking curl call.
---Intentionally synchronous (vim.fn.system) because it is only called from
---VimLeavePre where Neovim is exiting and async callbacks will never fire.
---@param port number Port the OpenCode server is listening on
---@param directory string The server's canonical working directory (from /path response)
---@return boolean success True if the server acknowledged the dispose request
function Client.dispose_instance_sync(port, directory)
	local url = string.format(
		"http://%s:%d/instance/dispose?directory=%s",
		DEFAULT_HOST,
		port,
		directory
	)
	local result = vim.fn.system({
		"curl",
		"-s",
		"-o",
		"/dev/null",
		"-w",
		"%{http_code}",
		"-X",
		"POST",
		"--max-time",
		"2",
		url,
	})
	return result ~= nil and result:match("^2%d%d") ~= nil
end

---Checks if a port is available by attempting to connect to it.
---@param port number Port number to check
---@return boolean True if port is available (connection fails), false if occupied (connection succeeds)
-- TODO: This function uses vim.fn.sockconnect which blocks the UI thread (violates AGENTS.md).
-- Refactor to use vim.uv.tcp_connect() with a callback to make allocate_port() fully async.
local function is_port_available(port)
	local ok, chan = pcall(vim.fn.sockconnect, "tcp", string.format("localhost:%d", port), {
		rpc = false,
		timeout = 50,
	})

	if not ok or chan == 0 then
		return true -- Connection failed = port is free
	end

	pcall(vim.fn.chanclose, chan)
	return false -- Connection succeeded = port is in use
end

---Allocates a free port in range [60000, 61000].
---The caller is responsible for storing the port in state after any commands
---that may fire autocommands (e.g. vim.cmd('terminal ...')).
---@return number|nil port Allocated port number or nil if all ports occupied
---@return string|nil error Error message if no port available
function Client.allocate_port()
	for port = 60000, 61000 do
		if is_port_available(port) then
			return port, nil
		end
	end
	return nil, "All ports in range 60000-61000 are occupied"
end

return Client
