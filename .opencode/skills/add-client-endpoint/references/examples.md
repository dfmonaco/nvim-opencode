# Complete Endpoint Implementation Examples

This document provides complete, working examples of endpoint implementations in `client.lua` and their corresponding tests. Use these as reference when implementing new endpoints.

---

## Table of Contents

- [Example 1: Simple GET with JSON Response (get_health)](#example-1-simple-get-with-json-response-get_health)
- [Example 2: GET with Query Parameters](#example-2-get-with-query-parameters)
- [Example 3: POST with JSON Body](#example-3-post-with-json-body)
- [Example 4: DELETE Endpoint](#example-4-delete-endpoint)
- [Example 5: PATCH with Partial Update](#example-5-patch-with-partial-update)
- [Test Helper: spawn_headless_server](#test-helper-spawn_headless_server)

---

## Example 1: Simple GET with JSON Response (get_health)

This is the canonical example from the actual codebase.

### Implementation in `client.lua`

```lua
---@class HealthResponse
---@field healthy boolean Server health status
---@field version string Server version

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
```

### Tests in `test_client.lua`

```lua
T["OpenCodeClient"]["get_health()"] = MiniTest.new_set()

T["OpenCodeClient"]["get_health()"]["returns health status when server is available"] = function()
	-- Spawn a test server on port 17001
	local server = spawn_headless_server(17001)

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({ base_url = 'http://127.0.0.1:17001' })
    _G.health = nil
    _G.error = nil
    _G.done = false
    
    _G.client:get_health(function(err, health)
      _G.error = err
      _G.health = health
      _G.done = true
    end)
  ]])

	-- Wait for async callback to complete
	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local health = child.lua_get([[_G.health]])

	MiniTest.expect.equality(error, vim.NIL)
	MiniTest.expect.no_equality(health, vim.NIL)
	MiniTest.expect.equality(type(health.healthy), "boolean")
	MiniTest.expect.equality(type(health.version), "string")

	child.stop()
	server:kill()
end

T["OpenCodeClient"]["get_health()"]["handles server errors"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({ base_url = 'http://localhost:9999' })
    _G.health = nil
    _G.error = nil
    _G.done = false
    
    _G.client:get_health(function(err, health)
      _G.error = err
      _G.health = health
      _G.done = true
    end)
  ]])

	-- Wait for async callback to complete
	child.lua([[vim.wait(6000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local health = child.lua_get([[_G.health]])

	MiniTest.expect.no_equality(error, vim.NIL)
	MiniTest.expect.equality(health, vim.NIL)

	child.stop()
end
```

---

## Example 2: GET with Query Parameters

For endpoints like `GET /find/file?query=foo&limit=10`.

### Implementation

```lua
---@class FileSearchResponse
---@field paths string[] Array of file paths

---Find files by name
---@param query string Search query
---@param opts? { limit?: number, type?: "file"|"directory" }
---@param callback fun(err: string|nil, result: FileSearchResponse|nil)
---@return nil
function Client:find_files(query, opts, callback)
	opts = opts or {}
	
	-- Build query parameters
	local params = { "query=" .. vim.fn.shellescape(query) }
	if opts.limit then
		table.insert(params, "limit=" .. tostring(opts.limit))
	end
	if opts.type then
		table.insert(params, "type=" .. opts.type)
	end
	
	local path = "/find/file?" .. table.concat(params, "&")
	
	self:request("GET", path, function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("File search failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse file search response: " .. tostring(decoded), nil)
			return
		end

		---@type FileSearchResponse
		local result = {
			paths = decoded or {},
		}

		callback(nil, result)
	end)
end
```

### Test

```lua
T["OpenCodeClient"]["find_files()"] = MiniTest.new_set()

T["OpenCodeClient"]["find_files()"]["returns matching files"] = function()
	local server = spawn_headless_server(17002)

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({ base_url = 'http://127.0.0.1:17002' })
    _G.result = nil
    _G.error = nil
    _G.done = false
    
    _G.client:find_files('client', { limit = 5 }, function(err, result)
      _G.error = err
      _G.result = result
      _G.done = true
    end)
  ]])

	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.equality(error, vim.NIL)
	MiniTest.expect.no_equality(result, vim.NIL)
	MiniTest.expect.equality(type(result.paths), "table")

	child.stop()
	server:kill()
end
```

---

## Example 3: POST with JSON Body

For endpoints like `POST /session` with a request body.

### Implementation

```lua
---@class CreateSessionRequest
---@field parentID? string Optional parent session ID
---@field title? string Optional session title

---@class Session
---@field id string Session ID
---@field title string Session title
---@field parentID? string Parent session ID

---Create a new session
---@param opts? CreateSessionRequest
---@param callback fun(err: string|nil, session: Session|nil)
---@return nil
function Client:create_session(opts, callback)
	opts = opts or {}
	
	-- Encode request body as JSON
	local ok, body_json = pcall(vim.json.encode, opts)
	if not ok then
		callback("Failed to encode request body: " .. tostring(body_json), nil)
		return
	end
	
	-- Build curl command with POST body
	local url = self.base_url .. "/session"
	local curl_args = {
		"curl",
		"-s",
		"-i",
		"-X", "POST",
		"-H", "Content-Type: application/json",
		"-d", body_json,
		"--max-time", tostring(math.floor(self.timeout / 1000)),
		url,
	}

	vim.system(curl_args, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback(result.stderr or "Request failed", nil)
				return
			end

			-- Parse response (same as standard request)
			local raw_response = result.stdout or ""
			local headers = {}
			local body = ""
			local status = 0

			local header_section, body_match = raw_response:match("^(.-)\r?\n\r?\n(.*)$")
			if header_section then
				body = body_match
				local status_line = header_section:match("^HTTP/[%d%.]+%s+(%d+)")
				if status_line then
					status = tonumber(status_line) or 0
				end
			else
				body = raw_response
			end

			if status ~= 200 and status ~= 201 then
				callback("Create session failed with status: " .. status, nil)
				return
			end

			local ok_decode, decoded = pcall(vim.json.decode, body)
			if not ok_decode then
				callback("Failed to parse session response: " .. tostring(decoded), nil)
				return
			end

			---@type Session
			local session = {
				id = decoded.id or "",
				title = decoded.title or "",
				parentID = decoded.parentID,
			}

			callback(nil, session)
		end)
	end)
end
```

### Test

```lua
T["OpenCodeClient"]["create_session()"] = MiniTest.new_set()

T["OpenCodeClient"]["create_session()"]["creates new session"] = function()
	local server = spawn_headless_server(17003)

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({ base_url = 'http://127.0.0.1:17003' })
    _G.result = nil
    _G.error = nil
    _G.done = false
    
    _G.client:create_session({ title = 'Test Session' }, function(err, session)
      _G.error = err
      _G.result = session
      _G.done = true
    end)
  ]])

	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.equality(error, vim.NIL)
	MiniTest.expect.no_equality(result, vim.NIL)
	MiniTest.expect.equality(type(result.id), "string")
	MiniTest.expect.no_equality(result.id, "")

	child.stop()
	server:kill()
end
```

**Note:** For POST/PUT/PATCH/DELETE requests, you need to build the curl command manually (like above) or extend the `request()` method to accept a body parameter.

---

## Example 4: DELETE Endpoint

For endpoints like `DELETE /session/:id`.

### Implementation

```lua
---Delete a session
---@param session_id string Session ID to delete
---@param callback fun(err: string|nil, success: boolean|nil)
---@return nil
function Client:delete_session(session_id, callback)
	local path = "/session/" .. session_id
	
	self:request("DELETE", path, function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or (response.status ~= 200 and response.status ~= 204) then
			callback("Delete session failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		-- For DELETE, response might be empty or boolean
		local success = true
		if response.body and response.body ~= "" then
			local ok, decoded = pcall(vim.json.decode, response.body)
			if ok and type(decoded) == "boolean" then
				success = decoded
			end
		end

		callback(nil, success)
	end)
end
```

**Note:** You'll need to extend the `request()` method to support DELETE method. Currently it only supports the method passed in, so this should work as-is.

---

## Example 5: PATCH with Partial Update

For endpoints like `PATCH /session/:id`.

### Implementation

```lua
---@class UpdateSessionRequest
---@field title? string New session title

---Update session properties
---@param session_id string Session ID
---@param updates UpdateSessionRequest Updates to apply
---@param callback fun(err: string|nil, session: Session|nil)
---@return nil
function Client:update_session(session_id, updates, callback)
	-- Encode request body
	local ok, body_json = pcall(vim.json.encode, updates)
	if not ok then
		callback("Failed to encode request body: " .. tostring(body_json), nil)
		return
	end
	
	local url = self.base_url .. "/session/" .. session_id
	local curl_args = {
		"curl",
		"-s",
		"-i",
		"-X", "PATCH",
		"-H", "Content-Type: application/json",
		"-d", body_json,
		"--max-time", tostring(math.floor(self.timeout / 1000)),
		url,
	}

	vim.system(curl_args, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback(result.stderr or "Request failed", nil)
				return
			end

			-- Parse response
			local raw_response = result.stdout or ""
			local header_section, body_match = raw_response:match("^(.-)\r?\n\r?\n(.*)$")
			local body = body_match or raw_response
			local status = 0
			
			if header_section then
				local status_line = header_section:match("^HTTP/[%d%.]+%s+(%d+)")
				if status_line then
					status = tonumber(status_line) or 0
				end
			end

			if status ~= 200 then
				callback("Update session failed with status: " .. status, nil)
				return
			end

			local ok_decode, decoded = pcall(vim.json.decode, body)
			if not ok_decode then
				callback("Failed to parse session response: " .. tostring(decoded), nil)
				return
			end

			---@type Session
			local session = {
				id = decoded.id or "",
				title = decoded.title or "",
				parentID = decoded.parentID,
			}

			callback(nil, session)
		end)
	end)
end
```

---

## Test Helper: spawn_headless_server

This helper function is essential for integration testing. It's defined at the top of `test_client.lua`:

```lua
---Helper to spawn an OpenCode headless server for testing
---@param port number Port to run the server on
---@return table|nil server_handle Handle to the spawned server, or nil if failed
local function spawn_headless_server(port)
	-- Check if opencode CLI is available
	local opencode_check = io.popen("which opencode 2>/dev/null")
	if not opencode_check then
		return nil
	end
	local opencode_path = opencode_check:read("*a"):gsub("%s+", "")
	opencode_check:close()

	if opencode_path == "" then
		return nil
	end

	-- Spawn server in background
	local cmd = string.format("opencode serve --port %d > /tmp/opencode_test_%d.log 2>&1 & echo $!", port, port)
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end

	local pid = handle:read("*a"):gsub("%s+", "")
	handle:close()

	if pid == "" then
		return nil
	end

	-- Wait for server to be ready (max 5 seconds)
	local ready = false
	for _ = 1, 50 do
		local check_cmd = string.format(
			'curl -s -o /dev/null -w "%%{http_code}" http://127.0.0.1:%d/global/health 2>/dev/null',
			port
		)
		local check_handle = io.popen(check_cmd)
		if check_handle then
			local status = check_handle:read("*a")
			check_handle:close()
			if status == "200" then
				ready = true
				break
			end
		end
		os.execute("sleep 0.1")
	end

	if not ready then
		-- Kill the server if it didn't start properly
		os.execute(string.format("kill %s 2>/dev/null", pid))
		return nil
	end

	return {
		pid = pid,
		port = port,
		kill = function(self)
			os.execute(string.format("kill %s 2>/dev/null", self.pid))
			-- Wait a bit for graceful shutdown
			os.execute("sleep 0.2")
		end,
	}
end
```

**Usage:**
- Spawns real OpenCode server for integration tests
- Waits up to 5 seconds for server to be ready
- Returns handle with `kill()` method for cleanup
- Use unique ports (17000+) for each test to enable parallel execution

---

## Key Patterns Summary

### Error Handling Chain

All endpoint implementations follow this chain:
1. **Network error check:** `if err then callback(err, nil); return end`
2. **HTTP status check:** `if status ~= 200 then callback("error message", nil); return end`
3. **JSON parsing check:** `if not ok then callback("parse error", nil); return end`
4. **Build typed response:** `local result = { ... }`
5. **Success callback:** `callback(nil, result)`

### Testing Patterns

1. **Process isolation:** Every test uses `MiniTest.new_child_neovim()`
2. **Async handling:** Use `vim.wait()` with a done flag
3. **Global variables:** Cross process boundary via `_G.variable_name`
4. **vim.NIL:** Lua nil becomes `vim.NIL` when retrieved via `lua_get()`
5. **Server spawning:** Use unique ports for parallel test execution
6. **Always cleanup:** Call `child.stop()` and `server:kill()` in every test

### Type Annotations

- Define response type with `---@class` before implementation
- Annotate callback parameters: `---@param callback fun(err: string|nil, result: TypeName|nil)`
- Cast result: `---@type TypeName` before building response object
- Use optional fields with `?`: `---@field optionalField? string`
