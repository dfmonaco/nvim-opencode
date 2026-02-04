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
			-- Try \r\n\r\n first (Windows/standard), then \n\n (Unix)
			local header_end, body_start
			local crlfcrlf_start, crlfcrlf_end = raw_response:find("\r\n\r\n")
			if crlfcrlf_start then
				header_end = crlfcrlf_start - 1
				body_start = crlfcrlf_end + 1
			else
				local lflf_start, lflf_end = raw_response:find("\n\n")
				if lflf_start then
					header_end = lflf_start - 1
					body_start = lflf_end + 1
				end
			end

			if header_end and body_start then
				local header_section = raw_response:sub(1, header_end)
				body = raw_response:sub(body_start)

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

return Client
