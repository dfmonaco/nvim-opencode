local MiniTest = require('mini.test')
local T = MiniTest.new_set()

---Helper to spawn an OpenCode server for testing
---@param port number Port to run the server on
---@return table|nil server_handle Handle to the spawned server, or nil if failed
local function spawn_server(port)
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
	local server = spawn_server(17000)
	if not server then
		MiniTest.skip("Failed to spawn OpenCode server (is opencode installed?)")
		return
	end

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
	local server = spawn_server(17001)
	if not server then
		MiniTest.skip("Failed to spawn OpenCode server (is opencode installed?)")
		return
	end

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

return T
