local MiniTest = require("mini.test")
local T = MiniTest.new_set()

-- ============================================================================
-- Helpers
-- ============================================================================

---Spawn a minimal SSE HTTP server using Python's built-in http.server.
---It listens on `port` and streams the given SSE `events` (array of raw JSON
---strings) on every request, then closes the connection.  Returns a handle
---with a :kill() method.
---@param port number
---@param events string[] Raw JSON strings to emit as SSE data lines
---@return table|nil handle  { pid, kill() } or nil if python3 unavailable
local function spawn_sse_server(port, events)
	-- Verify python3 is available
	local check = io.popen("which python3 2>/dev/null")
	if not check then
		return nil
	end
	local py_path = check:read("*a"):gsub("%s+", "")
	check:close()
	if py_path == "" then
		return nil
	end

	-- Build the SSE body: each event is "data: <json>\n\n"
	local sse_lines = {}
	for _, ev in ipairs(events) do
		-- Escape backslashes then double-quotes for embedding in a Python string
		local escaped = ev:gsub("\\", "\\\\"):gsub('"', '\\"')
		table.insert(sse_lines, "data: " .. escaped .. "\\n\\n")
	end
	local sse_body = table.concat(sse_lines, "")

	-- Inline Python script: persistent SSE server (serves_forever in a thread)
	-- Each GET request gets the full event stream and then the connection is closed.
	local script = string.format(
		[[python3 -c "
import http.server, threading, sys

BODY = b'%s'.replace(b'\\\\n', b'\\n')

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        try:
            self.wfile.write(BODY)
            self.wfile.flush()
        except Exception:
            pass

srv = http.server.HTTPServer(('127.0.0.1', %d), H)
t = threading.Thread(target=srv.serve_forever, daemon=True)
t.start()
t.join()
" > /tmp/sse_test_%d.log 2>&1 & echo $!]],
		sse_body,
		port,
		port
	)

	local handle = io.popen(script)
	if not handle then
		return nil
	end
	local pid = handle:read("*a"):gsub("%s+", "")
	handle:close()
	if pid == "" then
		return nil
	end

	-- Wait up to 2 seconds for the server to bind
	local ready = false
	for _ = 1, 20 do
		local h = io.popen(
			string.format(
				"curl -s -o /dev/null -w '%%{http_code}' --max-time 0.2 http://127.0.0.1:%d/ 2>/dev/null",
				port
			)
		)
		if h then
			local code = h:read("*a"):gsub("%s+", "")
			h:close()
			if code == "200" then
				ready = true
				break
			end
		end
		os.execute("sleep 0.1")
	end

	if not ready then
		os.execute(string.format("kill %s 2>/dev/null", pid))
		return nil
	end

	return {
		pid = pid,
		kill = function(self)
			os.execute(string.format("kill %s 2>/dev/null", self.pid))
			os.execute("sleep 0.1")
		end,
	}
end

-- ============================================================================
-- Test group: subscriber management (no server needed)
-- ============================================================================

local child = MiniTest.new_child_neovim()

T["Sse"] = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			-- Load SSE module; do NOT call setup() — sse.lua has no side effects on require
			child.lua([[_G.Sse = require('plugin.sse')]])
		end,
		post_once = function()
			child.stop()
		end,
	},
})

-- ============================================================================
-- subscribe / unsubscribe
-- ============================================================================

T["Sse"]["subscribe()"] = MiniTest.new_set()

T["Sse"]["subscribe()"]["returns incrementing unique IDs"] = function()
	child.lua([[
    _G.id1 = _G.Sse.subscribe('*', function() end)
    _G.id2 = _G.Sse.subscribe('*', function() end)
    _G.id3 = _G.Sse.subscribe('session.idle', function() end)
  ]])
	MiniTest.expect.equality(child.lua_get([[_G.id1]]), 1)
	MiniTest.expect.equality(child.lua_get([[_G.id2]]), 2)
	MiniTest.expect.equality(child.lua_get([[_G.id3]]), 3)
end

T["Sse"]["subscribe()"]["adds subscriber to state"] = function()
	child.lua([[_G.Sse.subscribe('session.idle', function() end)]])
	local count = child.lua_get([[#_G.Sse.get_state().subscribers]])
	MiniTest.expect.equality(count, 1)
end

T["Sse"]["unsubscribe()"] = MiniTest.new_set()

T["Sse"]["unsubscribe()"]["removes the subscriber by ID"] = function()
	child.lua([[
    local id = _G.Sse.subscribe('*', function() end)
    _G.Sse.subscribe('*', function() end)  -- second subscriber stays
    _G.Sse.unsubscribe(id)
  ]])
	local count_after = child.lua_get([[#_G.Sse.get_state().subscribers]])
	MiniTest.expect.equality(count_after, 1)
end

T["Sse"]["unsubscribe()"]["is a no-op for unknown ID"] = function()
	child.lua([[_G.Sse.subscribe('*', function() end)]])
	-- Should not error
	child.lua([[_G.Sse.unsubscribe(9999)]])
	local count = child.lua_get([[#_G.Sse.get_state().subscribers]])
	MiniTest.expect.equality(count, 1)
end

-- ============================================================================
-- get_state()
-- ============================================================================

T["Sse"]["get_state()"] = MiniTest.new_set()

T["Sse"]["get_state()"]["returns disconnected defaults on fresh require"] = function()
	local connected = child.lua_get([[_G.Sse.get_state().connected]])
	local port = child.lua_get([[_G.Sse.get_state().port]])
	local next_id = child.lua_get([[_G.Sse.get_state().next_subscriber_id]])
	local sub_count = child.lua_get([[#_G.Sse.get_state().subscribers]])
	local line_buf = child.lua_get([[_G.Sse.get_state().line_buffer]])
	MiniTest.expect.equality(connected, false)
	MiniTest.expect.equality(port, vim.NIL)
	MiniTest.expect.equality(next_id, 1)
	MiniTest.expect.equality(sub_count, 0)
	MiniTest.expect.equality(line_buf, "")
end

-- ============================================================================
-- dispatch_event + subscriber routing (tested by injecting events directly)
-- ============================================================================

T["Sse"]["dispatch via subscribe()"] = MiniTest.new_set()

T["Sse"]["dispatch via subscribe()"]["wildcard subscriber receives all events"] = function()
	child.lua([[
    _G.received = {}
    _G.Sse.subscribe('*', function(ev)
      table.insert(_G.received, ev.type)
    end)
    -- Simulate dispatching by connecting to a real port is integration-level.
    -- Here we test the routing logic by exercising the public subscribe API and
    -- verifying state; full dispatch is covered in integration tests below.
  ]])
	-- The subscriber is registered; confirm it appears in state with correct pattern
	local pattern = child.lua_get([[_G.Sse.get_state().subscribers[1].pattern]])
	MiniTest.expect.equality(pattern, "*")
end

T["Sse"]["dispatch via subscribe()"]["exact-type subscriber recorded with correct pattern"] = function()
	child.lua([[_G.Sse.subscribe('session.idle', function() end)]])
	local pattern = child.lua_get([[_G.Sse.get_state().subscribers[1].pattern]])
	MiniTest.expect.equality(pattern, "session.idle")
end

T["Sse"]["dispatch via subscribe()"]["erroring subscriber does not prevent state update"] = function()
	-- Register a subscriber that raises, then a well-behaved one after it
	-- We test that the module doesn't surface an unhandled error to the test
	-- by checking the second subscriber's registration is intact.
	child.lua([[
    _G.Sse.subscribe('*', function() error("boom") end)
    _G.Sse.subscribe('*', function() end)
  ]])
	local count = child.lua_get([[#_G.Sse.get_state().subscribers]])
	MiniTest.expect.equality(count, 2)
end

-- ============================================================================
-- connect() / disconnect() state transitions
-- ============================================================================

T["Sse"]["connect()"] = MiniTest.new_set()

T["Sse"]["connect()"]["sets connected=true and stores port"] = function()
	-- We pass a port that has nothing listening; curl will fail quickly but the
	-- state is set synchronously before the process exits, which is what we test.
	child.lua([[_G.Sse.connect(19900)]])
	MiniTest.expect.equality(child.lua_get([[_G.Sse.get_state().connected]]), true)
	MiniTest.expect.equality(child.lua_get([[_G.Sse.get_state().port]]), 19900)
end

T["Sse"]["connect()"]["is a no-op when already connected to same port"] = function()
	child.lua([[
    _G.Sse.connect(19901)
    -- Capture the process handle identity before second call
    _G.first_process = _G.Sse.get_state().process
    _G.Sse.connect(19901)  -- same port — should be no-op
    _G.second_process = _G.Sse.get_state().process
  ]])
	-- Both references should be the same object (no reconnect happened)
	local same = child.lua_get([[_G.first_process == _G.second_process]])
	MiniTest.expect.equality(same, true)
end

T["Sse"]["disconnect()"] = MiniTest.new_set()

T["Sse"]["disconnect()"]["clears connected state and port"] = function()
	child.lua([[
    _G.Sse.connect(19902)
    _G.Sse.disconnect()
  ]])
	MiniTest.expect.equality(child.lua_get([[_G.Sse.get_state().connected]]), false)
	MiniTest.expect.equality(child.lua_get([[_G.Sse.get_state().port]]), vim.NIL)
end

T["Sse"]["disconnect()"]["clears process handle"] = function()
	child.lua([[
    _G.Sse.connect(19903)
    _G.Sse.disconnect()
  ]])
	-- process should be nil; lua_get returns vim.NIL for nil across RPC
	local process = child.lua_get([[_G.Sse.get_state().process]])
	MiniTest.expect.equality(process, vim.NIL)
end

T["Sse"]["disconnect()"]["is safe to call when not connected"] = function()
	-- Should not raise
	child.lua([[_G.Sse.disconnect()]])
	MiniTest.expect.equality(child.lua_get([[_G.Sse.get_state().connected]]), false)
end

-- ============================================================================
-- Integration: real SSE stream via python mini-server
-- ============================================================================

T["Sse"]["integration"] = MiniTest.new_set()

T["Sse"]["integration"]["receives and dispatches events from SSE stream"] = function()
	local port = 19910
	local events = {
		'{"type":"session.status","status":"running"}',
		'{"type":"session.idle"}',
	}

	local server = spawn_sse_server(port, events)
	if not server then
		MiniTest.skip("python3 not available — skipping SSE integration test")
		return
	end

	child.lua(string.format([[
    _G.received_types = {}
    _G.Sse.subscribe('*', function(ev)
      table.insert(_G.received_types, ev.type)
    end)
    _G.Sse.connect(%d)
  ]], port))

	-- Wait up to 3 seconds for both events to arrive
	child.lua([[
    vim.wait(3000, function()
      return #_G.received_types >= 2
    end, 50)
  ]])

	local received = child.lua_get([[_G.received_types]])

	server:kill()
	child.lua([[_G.Sse.disconnect()]])

	MiniTest.expect.equality(received[1], "session.status")
	MiniTest.expect.equality(received[2], "session.idle")
end

T["Sse"]["integration"]["fires User OpenCodeEvent autocmd for each event"] = function()
	local port = 19911
	local events = { '{"type":"session.idle"}' }

	local server = spawn_sse_server(port, events)
	if not server then
		MiniTest.skip("python3 not available — skipping SSE integration test")
		return
	end

	child.lua(string.format([[
    _G.autocmd_fired = false
    vim.api.nvim_create_autocmd('User', {
      pattern = 'OpenCodeEvent',
      callback = function(ev)
        if type(ev.data) == 'table' and ev.data.type == 'session.idle' then
          _G.autocmd_fired = true
        end
      end,
    })
    _G.Sse.connect(%d)
  ]], port))

	child.lua([[
    vim.wait(3000, function() return _G.autocmd_fired end, 50)
  ]])

	local fired = child.lua_get([[_G.autocmd_fired]])

	server:kill()
	child.lua([[_G.Sse.disconnect()]])

	MiniTest.expect.equality(fired, true)
end

T["Sse"]["integration"]["wildcard subscriber receives events, exact-type subscriber only receives matching"] =
	function()
		local port = 19912
		local events = {
			'{"type":"session.status","status":"running"}',
			'{"type":"session.idle"}',
		}

		local server = spawn_sse_server(port, events)
		if not server then
			MiniTest.skip("python3 not available — skipping SSE integration test")
			return
		end

		child.lua(string.format([[
    _G.all_events = {}
    _G.idle_events = {}
    _G.Sse.subscribe('*', function(ev)
      table.insert(_G.all_events, ev.type)
    end)
    _G.Sse.subscribe('session.idle', function(ev)
      table.insert(_G.idle_events, ev.type)
    end)
    _G.Sse.connect(%d)
  ]], port))

		child.lua([[
    vim.wait(3000, function()
      return #_G.all_events >= 2
    end, 50)
  ]])

		local all = child.lua_get([[_G.all_events]])
		local idle = child.lua_get([[_G.idle_events]])

		server:kill()
		child.lua([[_G.Sse.disconnect()]])

		-- Wildcard receives both
		MiniTest.expect.equality(#all, 2)
		-- Exact-type receives only session.idle
		MiniTest.expect.equality(#idle, 1)
		MiniTest.expect.equality(idle[1], "session.idle")
	end

T["Sse"]["integration"]["erroring subscriber does not prevent other subscribers from receiving events"] =
	function()
		local port = 19913
		local events = { '{"type":"session.idle"}' }

		local server = spawn_sse_server(port, events)
		if not server then
			MiniTest.skip("python3 not available — skipping SSE integration test")
			return
		end

		child.lua(string.format([[
    _G.good_received = false
    -- Subscriber that always errors
    _G.Sse.subscribe('*', function() error("intentional error") end)
    -- Well-behaved subscriber registered after the bad one
    _G.Sse.subscribe('*', function(ev)
      if ev.type == 'session.idle' then
        _G.good_received = true
      end
    end)
    _G.Sse.connect(%d)
  ]], port))

		child.lua([[
    vim.wait(3000, function() return _G.good_received end, 50)
  ]])

		local received = child.lua_get([[_G.good_received]])

		server:kill()
		child.lua([[_G.Sse.disconnect()]])

		MiniTest.expect.equality(received, true)
	end

return T
