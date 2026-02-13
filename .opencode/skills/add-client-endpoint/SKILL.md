---
name: add-client-endpoint
description: "Comprehensive guide for adding new HTTP endpoint methods to lua/plugin/client.lua in the nvim-opencode plugin. Use when: (1) Implementing new OpenCode server API endpoints in the Neovim client, (2) Adding client methods for GET/POST/PUT/PATCH/DELETE requests, (3) Writing integration tests for client functionality, (4) Working with async HTTP requests and JSON responses, (5) Following the plugin's strict type safety and async patterns for API communication."
---

# Add Client Endpoint

Guide for implementing new HTTP endpoint methods in the OpenCode Neovim plugin client.

---

## Quick Start Checklist

When adding a new endpoint, follow these steps:

1. **Choose endpoint** from [references/server-api.md](references/server-api.md)
2. **Define response type** with EmmyLua annotations in `client.lua`
3. **Implement method** following templates below
4. **Write tests** in `test_client.lua` (success + error cases)
5. **Run tests** with `make test_file FILE=tests/test_client.lua`

---

## Implementation Templates

### Template 1: Simple GET Request (JSON Response)

Use for: `GET /endpoint` that returns JSON.

```lua
-- In lua/plugin/client.lua

---@class YourResponseType
---@field field_name type Description of field
---@field another_field type Description

---Brief description of what this endpoint does
---@param callback fun(err: string|nil, result: YourResponseType|nil)
---@return nil
function Client:your_method_name(callback)
	self:request("GET", "/path/to/endpoint", function(err, response)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("Operation failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		-- Parse JSON response
		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse response: " .. tostring(decoded), nil)
			return
		end

		---@type YourResponseType
		local result = {
			field_name = decoded.field_name or default_value,
			another_field = decoded.another_field or default_value,
		}

		callback(nil, result)
	end)
end
```

**See:** [references/examples.md](references/examples.md) - Example 1 for complete `get_health` implementation.

---

### Template 2: GET with Query Parameters

Use for: `GET /endpoint?param1=value1&param2=value2`

```lua
---@class YourResponseType
---@field results table Array or object of results

---Brief description
---@param query string Main search/query parameter
---@param opts? { limit?: number, type?: string } Optional parameters
---@param callback fun(err: string|nil, result: YourResponseType|nil)
---@return nil
function Client:your_method_name(query, opts, callback)
	opts = opts or {}
	
	-- Build query parameters
	local params = { "query=" .. vim.fn.shellescape(query) }
	if opts.limit then
		table.insert(params, "limit=" .. tostring(opts.limit))
	end
	if opts.type then
		table.insert(params, "type=" .. opts.type)
	end
	
	local path = "/path/to/endpoint?" .. table.concat(params, "&")
	
	self:request("GET", path, function(err, response)
		-- Standard error handling (same as Template 1)
		if err then
			callback(err, nil)
			return
		end

		if not response or response.status ~= 200 then
			callback("Operation failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		local ok, decoded = pcall(vim.json.decode, response.body)
		if not ok then
			callback("Failed to parse response: " .. tostring(decoded), nil)
			return
		end

		---@type YourResponseType
		local result = {
			results = decoded or {},
		}

		callback(nil, result)
	end)
end
```

**See:** [references/examples.md](references/examples.md) - Example 2 for complete implementation.

---

### Template 3: POST/PUT/PATCH with JSON Body

Use for: `POST /endpoint` with request body.

```lua
---@class YourRequestType
---@field field1? string Optional field
---@field field2 string Required field

---@class YourResponseType
---@field id string Created/updated resource ID
---@field status string Operation status

---Brief description
---@param data YourRequestType Request data
---@param callback fun(err: string|nil, result: YourResponseType|nil)
---@return nil
function Client:your_method_name(data, callback)
	-- Encode request body
	local ok, body_json = pcall(vim.json.encode, data)
	if not ok then
		callback("Failed to encode request body: " .. tostring(body_json), nil)
		return
	end
	
	-- Build curl command with body
	local url = self.base_url .. "/path/to/endpoint"
	local curl_args = {
		"curl",
		"-s",
		"-i",
		"-X", "POST",  -- or "PUT", "PATCH"
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

			-- Parse response headers and body
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

			-- Check for success status (200 or 201 for creates)
			if status ~= 200 and status ~= 201 then
				callback("Operation failed with status: " .. status, nil)
				return
			end

			local ok_decode, decoded = pcall(vim.json.decode, body)
			if not ok_decode then
				callback("Failed to parse response: " .. tostring(decoded), nil)
				return
			end

			---@type YourResponseType
			local result = {
				id = decoded.id or "",
				status = decoded.status or "unknown",
			}

			callback(nil, result)
		end)
	end)
end
```

**See:** [references/examples.md](references/examples.md) - Example 3 for complete POST implementation.

---

### Template 4: DELETE Request

Use for: `DELETE /endpoint/:id`

```lua
---Delete a resource
---@param resource_id string Resource ID to delete
---@param callback fun(err: string|nil, success: boolean|nil)
---@return nil
function Client:delete_resource(resource_id, callback)
	local path = "/path/to/endpoint/" .. resource_id
	
	self:request("DELETE", path, function(err, response)
		if err then
			callback(err, nil)
			return
		end

		-- DELETE can return 200 or 204 (No Content)
		if not response or (response.status ~= 200 and response.status ~= 204) then
			callback("Delete failed with status: " .. (response and response.status or "unknown"), nil)
			return
		end

		-- Response might be empty for 204, or boolean for 200
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

**See:** [references/examples.md](references/examples.md) - Example 4 for complete DELETE implementation.

---

## Testing Pattern

Every endpoint needs two tests: success case and error case.

### Test Structure

```lua
-- In tests/test_client.lua

T["OpenCodeClient"]["your_method_name()"] = MiniTest.new_set()

T["OpenCodeClient"]["your_method_name()"]["success case description"] = function()
	-- 1. Spawn test server with unique port
	local server = spawn_headless_server(17XXX)  -- Use unique port 17000+
	
	-- 2. Create child Neovim process
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })
	
	-- 3. Execute test in child process
	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://127.0.0.1:17XXX' })
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		_G.client:your_method_name(function(err, result)
			_G.error = err
			_G.result = result
			_G.done = true
		end)
	]])
	
	-- 4. Wait for async callback
	child.lua([[vim.wait(5000, function() return _G.done end)]])
	
	-- 5. Extract and verify results
	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])
	
	MiniTest.expect.equality(error, vim.NIL)
	MiniTest.expect.no_equality(result, vim.NIL)
	-- Add specific field checks
	MiniTest.expect.equality(result.field_name, expected_value)
	
	-- 6. Cleanup
	child.stop()
	server:kill()
end

T["OpenCodeClient"]["your_method_name()"]["handles server errors"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })
	
	-- Point to non-existent server
	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://localhost:9999' })
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		_G.client:your_method_name(function(err, result)
			_G.error = err
			_G.result = result
			_G.done = true
		end)
	]])
	
	child.lua([[vim.wait(6000, function() return _G.done end)]])
	
	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])
	
	MiniTest.expect.no_equality(error, vim.NIL)
	MiniTest.expect.equality(result, vim.NIL)
	
	child.stop()
end
```

**Key Testing Concepts:**
- **Process Isolation:** Each test runs in separate Neovim child process
- **Async Handling:** Use `vim.wait()` with done flag to wait for callbacks
- **vim.NIL:** Lua nil values become `vim.NIL` when crossing process boundaries
- **Unique Ports:** Use ports 17000+ to enable parallel test execution
- **Always Cleanup:** Call `child.stop()` and `server:kill()` in every test

**See:** [references/examples.md](references/examples.md) for complete test examples.

---

## Running Tests

```bash
# Run all client tests
make test_file FILE=tests/test_client.lua

# Run all tests
make test

# From within Neovim
:lua MiniTest.run_file('tests/test_client.lua')
```

---

## Critical Rules

### 1. Async by Default
- All HTTP operations use `vim.system()` with callbacks
- Never use blocking calls like `vim.fn.system()`
- Always wrap callbacks in `vim.schedule()` when needed

### 2. Type Safety
- Define response type with `---@class` before implementation
- Annotate all function parameters with `---@param`
- Annotate return types with `---@return`
- Cast response objects with `---@type TypeName`

### 3. Error Handling Chain
Every endpoint must handle errors at three levels:
1. **Network errors:** Check `if err then`
2. **HTTP status:** Check `if response.status ~= 200`
3. **JSON parsing:** Use `pcall(vim.json.decode, ...)`

### 4. Callback Signature
All callbacks follow Node.js convention:
```lua
---@param callback fun(err: string|nil, result: TypeName|nil)
```
- First argument is error (nil on success)
- Second argument is result (nil on error)

### 5. Process Isolation in Tests
- Every test uses `MiniTest.new_child_neovim()`
- Global variables cross process boundary via `_G.variable_name`
- Use `vim.wait()` to wait for async operations

---

## File Locations

- **Client implementation:** `lua/plugin/client.lua`
- **Client tests:** `tests/test_client.lua`
- **State management:** `lua/plugin/state.lua` (if persistence needed)
- **Server API docs:** See [references/server-api.md](references/server-api.md)

---

## State Management (Optional)

If your endpoint needs to persist data across calls, use the State module:

```lua
-- In lua/plugin/state.lua, add:

---Sets your data
---@param data YourType
function M.set_your_data(data)
    state.your_data = data
end

---Gets your data
---@return YourType|nil
function M.get_your_data()
    return state.your_data
end
```

Then use in your client method:
```lua
local State = require('plugin.state')
State.set_your_data(result)
```

---

## Resources

### references/server-api.md
Complete OpenCode server API reference. Consult this to:
- Discover available endpoints
- Understand request/response schemas
- Check HTTP methods and status codes
- Find query parameters and body formats

### references/examples.md
Complete, working implementations including:
- `get_health` (simple GET with JSON)
- File search (GET with query parameters)
- Create session (POST with JSON body)
- Delete session (DELETE endpoint)
- Update session (PATCH with partial update)
- Test helper: `spawn_headless_server()`

---

## Common Patterns

### URL Path Parameters
Replace `:id` in path with actual values:
```lua
local path = "/session/" .. session_id .. "/message"
```

### Optional Parameters
Use opts table with defaults:
```lua
---@param opts? { limit?: number, timeout?: number }
function Client:method(opts, callback)
    opts = opts or {}
    local limit = opts.limit or 10
    -- ...
end
```

### Multiple Response Status Codes
Check for multiple valid statuses:
```lua
if status ~= 200 and status ~= 201 and status ~= 204 then
    callback("Failed with status: " .. status, nil)
    return
end
```

### Empty Response Body
Handle empty responses (common with DELETE):
```lua
if response.body == "" or response.status == 204 then
    callback(nil, true)
    return
end
```

---

## Troubleshooting

**Test hangs forever:**
- Check if `_G.done = true` is being set in callback
- Increase `vim.wait()` timeout if server is slow
- Verify server spawned successfully with unique port

**JSON parsing fails:**
- Check if response.body is actually JSON (not HTML error page)
- Verify server returned expected content-type
- Print `response.body` in test for debugging

**vim.NIL confusion:**
- When retrieving `nil` via `lua_get()`, it becomes `vim.NIL`
- Use `MiniTest.expect.equality(value, vim.NIL)` to check for nil
- Use `MiniTest.expect.no_equality(value, vim.NIL)` to check not-nil

**Server not starting in tests:**
- Ensure `opencode` CLI is in PATH
- Check `/tmp/opencode_test_*.log` for errors
- Try running `opencode serve --port 17000` manually

---

## Next Steps After Implementation

1. **Update documentation** if endpoint adds user-facing functionality
2. **Add command/keybinding** if endpoint should be accessible to users
3. **Consider rate limiting** for endpoints that may be called frequently
4. **Add to health check** if endpoint is critical for plugin functionality
