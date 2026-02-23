local MiniTest = require('mini.test')
local T = MiniTest.new_set()

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

T["OpenCodeClient"] = MiniTest.new_set()

T["OpenCodeClient"]["new()"] = MiniTest.new_set()

T["OpenCodeClient"]["new()"]["creates client with default options"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new()
  ]])

	local base_url = child.lua_get([[_G.client.base_url]])
	local timeout = child.lua_get([[_G.client.timeout]])

	MiniTest.expect.equality(base_url, "http://127.0.0.1:4096")
	MiniTest.expect.equality(timeout, 5000)

	child.stop()
end

T["OpenCodeClient"]["new()"]["creates client with custom options"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({
      base_url = 'http://localhost:8080',
      timeout = 10000
    })
  ]])

	local base_url = child.lua_get([[_G.client.base_url]])
	local timeout = child.lua_get([[_G.client.timeout]])

	MiniTest.expect.equality(base_url, "http://localhost:8080")
	MiniTest.expect.equality(timeout, 10000)

	child.stop()
end

T["OpenCodeClient"]["request()"] = MiniTest.new_set()

T["OpenCodeClient"]["request()"]["handles successful GET request"] = function()
	-- Spawn a test server on port 17000
	local server = spawn_headless_server(17000)

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({ base_url = 'http://127.0.0.1:17000' })
    _G.result = nil
    _G.error = nil
    _G.done = false
    
    _G.client:request('GET', '/global/health', function(err, response)
      _G.error = err
      _G.result = response
      _G.done = true
    end)
  ]])

	-- Wait for async callback to complete
	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.equality(error, vim.NIL)
	MiniTest.expect.no_equality(result, vim.NIL)
	MiniTest.expect.equality(result.status, 200)

	child.stop()
	server:kill()
end

T["OpenCodeClient"]["request()"]["handles connection errors"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    _G.client = Client.new({ base_url = 'http://localhost:9999' })
    _G.result = nil
    _G.error = nil
    _G.done = false
    
    _G.client:request('GET', '/global/health', function(err, response)
      _G.error = err
      _G.result = response
      _G.done = true
    end)
  ]])

	-- Wait for async callback to complete
	child.lua([[vim.wait(6000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.no_equality(error, vim.NIL)
	MiniTest.expect.equality(result, vim.NIL)

	child.stop()
end

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

T["OpenCodeClient"]["allocate_port()"] = MiniTest.new_set()

T["OpenCodeClient"]["allocate_port()"]["allocates port in range 60000-61000"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
    local Client = require('plugin.client')
    local port, err = Client.allocate_port()

    _G.test_port = port
    _G.test_err = err
  ]])

	local port = child.lua_get([[_G.test_port]])
	local err = child.lua_get([[_G.test_err]])

	-- Verify port is allocated with no error
	MiniTest.expect.no_equality(port, vim.NIL, "allocate_port() should return a port")
	MiniTest.expect.equality(type(port), "number")
	MiniTest.expect.equality(err, vim.NIL, "allocate_port() should not return an error")

	-- Verify port is in correct range
	MiniTest.expect.equality(port >= 60000 and port <= 61000, true, "Port should be in range 60000-61000")

	child.stop()
end

T["OpenCodeClient"]["allocate_port()"]["skips ports already in use"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	-- Start a headless OpenCode server on port 60000
	local server = spawn_headless_server(60000)
	vim.uv.sleep(200) -- Wait for server to bind to port

	child.lua([[
    local State = require('plugin.state')
    State.set_port(nil) -- Reset state
    
    local Client = require('plugin.client')
    local port, err = Client.allocate_port()
    
    _G.test_port = port
    _G.test_err = err
  ]])

	local port = child.lua_get([[_G.test_port]])
	local err = child.lua_get([[_G.test_err]])

	-- Port should not be 60000 since it's occupied
	MiniTest.expect.no_equality(port, 60000, "Should skip port 60000 that is in use")
	MiniTest.expect.equality(type(port), "number", "Should allocate a different port")
	MiniTest.expect.equality(err, vim.NIL, "Should not return an error")

	-- Should be in range and greater than 60000
	MiniTest.expect.equality(port > 60000 and port <= 61000, true, "Should allocate next available port after 60000")

	-- Cleanup
	if server then
		server:kill()
	end
	child.stop()
end

T["OpenCodeClient"]["send_message_async()"] = MiniTest.new_set()

T["OpenCodeClient"]["send_message_async()"]["sends message asynchronously and returns success"] = function()
	-- Spawn test server on unique port 17003
	local server = spawn_headless_server(17003)
	if not server then
		MiniTest.skip("OpenCode CLI not available or server failed to start")
		return
	end

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	-- First create a session to send message to
	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://127.0.0.1:17003' })
		_G.session_id = nil
		_G.create_done = false
		
		-- Create a session first
		local url = 'http://127.0.0.1:17003/session'
		local curl_args = {
			'curl', '-s', '-X', 'POST',
			'-H', 'Content-Type: application/json',
			'-d', '{}',
			url
		}
		
		vim.system(curl_args, { text = true }, function(result)
			vim.schedule(function()
				if result.code == 0 then
					local ok, session = pcall(vim.json.decode, result.stdout)
					if ok and session and session.id then
						_G.session_id = session.id
					end
				end
				_G.create_done = true
			end)
		end)
	]])

	-- Wait for session creation
	child.lua([[vim.wait(5000, function() return _G.create_done end)]])

	local session_id = child.lua_get([[_G.session_id]])
	if session_id == vim.NIL then
		server:kill()
		child.stop()
		MiniTest.skip("Failed to create test session")
		return
	end

	-- Now send message asynchronously
	child.lua(string.format([[
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		local message_parts = {
			{ type = 'text', text = 'Test message' }
		}
		
		_G.client:send_message_async('%s', message_parts, nil, function(err, result)
			_G.error = err
			_G.result = result
			_G.done = true
		end)
	]], session_id))

	-- Wait for async callback
	child.lua([[vim.wait(5000, function() return _G.done end)]])

	-- Extract and verify results
	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.equality(error, vim.NIL, "Should not return an error")
	MiniTest.expect.equality(result, true, "Should return true for successful async send")

	-- Cleanup
	child.stop()
	server:kill()
end

T["OpenCodeClient"]["send_message_async()"]["handles server connection errors"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	-- Point to non-existent server
	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://localhost:9999', timeout = 2000 })
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		local message_parts = {
			{ type = 'text', text = 'Test message' }
		}
		
		_G.client:send_message_async('test-session-id', message_parts, nil, function(err, result)
			_G.error = err
			_G.result = result
			_G.done = true
		end)
	]])

	child.lua([[vim.wait(6000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.no_equality(error, vim.NIL, "Should return an error")
	MiniTest.expect.equality(result, vim.NIL, "Should not return a result on error")

	child.stop()
end

T["OpenCodeClient"]["send_message_async()"]["accepts request even with non-existent session"] = function()
	-- Spawn test server
	local server = spawn_headless_server(17004)
	if not server then
		MiniTest.skip("OpenCode CLI not available or server failed to start")
		return
	end

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://127.0.0.1:17004' })
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		local message_parts = {
			{ type = 'text', text = 'Test message' }
		}
		
		-- Send to non-existent session
		-- Async endpoint may still return 204 since validation is deferred
		_G.client:send_message_async('invalid-session-id', message_parts, nil, function(err, result)
			_G.error = err
			_G.result = result
			_G.done = true
		end)
	]])

	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	-- Async endpoint accepts the request (204) even if session doesn't exist
	-- Validation happens later when message is actually processed
	-- So we just verify the client successfully sent the request
	MiniTest.expect.equality(error, vim.NIL, "Client should successfully send request")
	MiniTest.expect.equality(result, true, "Should return true for successful send")

	child.stop()
	server:kill()
end

T["OpenCodeClient"]["send_message_async()"]["supports optional parameters"] = function()
	-- Spawn test server
	local server = spawn_headless_server(17005)
	if not server then
		MiniTest.skip("OpenCode CLI not available or server failed to start")
		return
	end

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	-- Create a session first
	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://127.0.0.1:17005' })
		_G.session_id = nil
		_G.create_done = false
		
		local url = 'http://127.0.0.1:17005/session'
		local curl_args = {
			'curl', '-s', '-X', 'POST',
			'-H', 'Content-Type: application/json',
			'-d', '{}',
			url
		}
		
		vim.system(curl_args, { text = true }, function(result)
			vim.schedule(function()
				if result.code == 0 then
					local ok, session = pcall(vim.json.decode, result.stdout)
					if ok and session and session.id then
						_G.session_id = session.id
					end
				end
				_G.create_done = true
			end)
		end)
	]])

	child.lua([[vim.wait(5000, function() return _G.create_done end)]])

	local session_id = child.lua_get([[_G.session_id]])
	if session_id == vim.NIL then
		server:kill()
		child.stop()
		MiniTest.skip("Failed to create test session")
		return
	end

	-- Send message with optional parameters
	child.lua(string.format([[
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		local message_parts = {
			{ type = 'text', text = 'Test with options' }
		}
		
		local opts = {
			agent = 'test-agent',
			system = 'Test system message'
		}
		
		_G.client:send_message_async('%s', message_parts, opts, function(err, result)
			_G.error = err
			_G.result = result
			_G.done = true
		end)
	]], session_id))

	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	-- Should succeed even with optional parameters
	MiniTest.expect.equality(error, vim.NIL, "Should not return an error with optional params")
	MiniTest.expect.equality(result, true, "Should return true with optional params")

	child.stop()
	server:kill()
end

T["OpenCodeClient"]["get_latest_session_id()"] = MiniTest.new_set()

T["OpenCodeClient"]["get_latest_session_id()"]["returns latest session ID"] = function()
	local server = spawn_headless_server(17006)
	if not server then
		MiniTest.skip("OpenCode CLI not available or server failed to start")
		return
	end

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://127.0.0.1:17006' })
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		_G.client:get_latest_session_id(function(err, session_id)
			_G.error = err
			_G.result = session_id
			_G.done = true
		end)
	]])

	child.lua([[vim.wait(5000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.equality(error, vim.NIL, "Should not return an error")
	MiniTest.expect.no_equality(result, vim.NIL, "Should return a session ID")
	MiniTest.expect.equality(type(result), "string", "Session ID should be a string")
	-- Session IDs start with "ses_"
	MiniTest.expect.equality(result:sub(1, 4), "ses_", "Session ID should start with 'ses_'")

	child.stop()
	server:kill()
end

T["OpenCodeClient"]["get_latest_session_id()"]["handles server errors"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
		local Client = require('plugin.client')
		_G.client = Client.new({ base_url = 'http://localhost:9999' })
		_G.result = nil
		_G.error = nil
		_G.done = false
		
		_G.client:get_latest_session_id(function(err, session_id)
			_G.error = err
			_G.result = session_id
			_G.done = true
		end)
	]])

	child.lua([[vim.wait(6000, function() return _G.done end)]])

	local error = child.lua_get([[_G.error]])
	local result = child.lua_get([[_G.result]])

	MiniTest.expect.no_equality(error, vim.NIL, "Should return an error")
	MiniTest.expect.equality(result, vim.NIL, "Should not return a result on error")

	child.stop()
end

-- ============================================================================
-- dispose_instance_sync() tests
-- ============================================================================

T["OpenCodeClient"]["dispose_instance_sync()"] = MiniTest.new_set()

T["OpenCodeClient"]["dispose_instance_sync()"]["returns false when no server is running"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[
		local Client = require('plugin.client')
		_G.result = Client.dispose_instance_sync(9999, '/tmp/no-such-project')
	]])

	local result = child.lua_get([[_G.result]])
	MiniTest.expect.equality(result, false, "Should return false when server is unreachable")

	child.stop()
end

T["OpenCodeClient"]["dispose_instance_sync()"]["returns true when server responds with 2xx"] = function()
	local server = spawn_headless_server(60099)
	if not server then
		MiniTest.skip("opencode CLI not available, skipping integration test")
		return
	end

	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua(string.format([[
		local Client = require('plugin.client')
		_G.result = Client.dispose_instance_sync(%d, vim.fn.getcwd())
	]], server.port))

	local result = child.lua_get([[_G.result]])
	MiniTest.expect.equality(result, true, "Should return true when server acknowledges dispose")

	child.stop()
	server:kill()
end

return T
