local State = require("plugin.state")

---@class HttpResponse
---@field status number HTTP status code
---@field body string Response body (raw string)
---@field headers table<string, string> Response headers

---@class HealthResponse
---@field healthy boolean Server health status
---@field version string Server version

---@class OpenCodeClient
---@field base_url string Base URL of the OpenCode server
---@field timeout number Request timeout in milliseconds
local Client = {}
Client.__index = Client

---Create a new OpenCode HTTP client
---@param opts? { base_url?: string, timeout?: number }
---@return OpenCodeClient
function Client.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Client)
	self.base_url = opts.base_url or "http://127.0.0.1:4096"
	self.timeout = opts.timeout or 5000
	return self
end

---Execute an HTTP request using curl
---@param method string HTTP method (GET, POST, etc.)
---@param path string API endpoint path
---@param callback fun(err: string|nil, response: HttpResponse|nil) Callback function
---@return nil
function Client:request(method, path, callback)
	local url = self.base_url .. path

	-- Build curl command
	local curl_args = {
		"curl",
		"-s", -- Silent mode
		"-i", -- Include headers in output
		"-X",
		method,
		"--max-time",
		tostring(math.floor(self.timeout / 1000)),
		url,
	}

	vim.system(curl_args, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local error_msg = result.stderr or "Request failed"
				callback(error_msg, nil)
				return
			end

			-- Parse response (headers + body)
			local raw_response = result.stdout or ""
			local headers = {}
			local body = ""
			local status = 0

			-- Split headers and body
			local header_section, body_match = raw_response:match("^(.-)\r?\n\r?\n(.*)$")
			if header_section then
				body = body_match

				-- Parse status line
				local status_line = header_section:match("^HTTP/[%d%.]+%s+(%d+)")
				if status_line then
					status = tonumber(status_line) or 0
				end

				-- Parse headers
				for line in header_section:gmatch("[^\r\n]+") do
					local key, value = line:match("^([^:]+):%s*(.+)$")
					if key and value then
						headers[key:lower()] = value
					end
				end
			else
				-- No header/body separation found
				body = raw_response
			end

			callback(nil, {
				status = status,
				body = body,
				headers = headers,
			})
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

		-- Parse JSON response
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

---Allocates a free port in range [60000, 61000] and stores it in app state
---@return number|nil Allocated port number or nil if not found
function Client.allocate_port()
  for port = 60000, 61000 do
    local sock = vim.uv.new_tcp()
    if sock then
    local err = sock:bind("127.0.0.1", port)
    if err == nil or err == 0 then
      sock:close()
      State.set_port(port)
      return port
    else
    end
    sock:close()
    end
  end
	return nil
end

---Start OpenCode TUI by allocating a free port and launching opencode
---@param opts? { on_exit?: fun(code: number, stdout: string, stderr: string) }
---@return boolean|nil, number|string|nil Returns `true, port` on success, or `nil, <error>` on failure
function Client.start_tui(opts)
  opts = opts or {}
  -- Allocate a fresh port each time this function is called
  local port = Client.allocate_port()
  if not port then
    return nil, "failed to allocate a free port"
  end

  local cmd = { "opencode", "--port", tostring(port) }

  -- Run non-blocking; callback is invoked when the process exits
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if opts.on_exit then
        opts.on_exit(result.code or 0, result.stdout or "", result.stderr or "")
      end
    end)
  end)

  return true, port
end

return Client
