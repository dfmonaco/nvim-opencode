local MiniTest = require("mini.test")
local T = MiniTest.new_set()

-- ============================================================================
-- autocmds tests
-- ============================================================================

local child = MiniTest.new_child_neovim()

T["autocmds"] = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[require('plugin').setup()]])
		end,
		post_once = child.stop,
	},
})

-- ─── session.created ─────────────────────────────────────────────────────────

T["autocmds"]["session.created updates state.session_id"] = function()
	-- Verify state starts empty
	local before = child.lua_get([[require('plugin.state').get_session_id()]])
	MiniTest.expect.equality(before, vim.NIL)

	-- Fire a synthetic session.created SSE event via the User autocmd
	child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "OpenCodeEvent",
      data = {
        type = "session.created",
        properties = {
          info = { id = "ses_new123" },
        },
      },
    })
  ]])

	local after = child.lua_get([[require('plugin.state').get_session_id()]])
	MiniTest.expect.equality(after, "ses_new123")
end

T["autocmds"]["session.created overwrites existing session_id"] = function()
	-- Pre-seed an old session ID (simulates terminal startup)
	child.lua([[require('plugin.state').set_session_id("ses_old456")]])

	local before = child.lua_get([[require('plugin.state').get_session_id()]])
	MiniTest.expect.equality(before, "ses_old456")

	-- Fire session.created with a new session
	child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "OpenCodeEvent",
      data = {
        type = "session.created",
        properties = {
          info = { id = "ses_new789" },
        },
      },
    })
  ]])

	local after = child.lua_get([[require('plugin.state').get_session_id()]])
	MiniTest.expect.equality(after, "ses_new789")
end

T["autocmds"]["session.created with missing info does not update state"] = function()
	child.lua([[require('plugin.state').set_session_id("ses_stable")]])

	-- Fire session.created with malformed payload (no info.id)
	child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "OpenCodeEvent",
      data = {
        type = "session.created",
        properties = {},
      },
    })
  ]])

	local after = child.lua_get([[require('plugin.state').get_session_id()]])
	MiniTest.expect.equality(after, "ses_stable")
end

T["autocmds"]["non-session events do not alter session_id"] = function()
	child.lua([[require('plugin.state').set_session_id("ses_keep")]])

	child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "OpenCodeEvent",
      data = { type = "session.idle", properties = { sessionID = "ses_keep" } },
    })
  ]])

	local after = child.lua_get([[require('plugin.state').get_session_id()]])
	MiniTest.expect.equality(after, "ses_keep")
end

-- ─── VimLeavePre ─────────────────────────────────────────────────────────────

T["autocmds"]["VimLeavePre does not call dispose when port is nil"] = function()
	-- Ensure state has no port or project_root
	child.lua([[
    require('plugin.state').set_port(nil)
    require('plugin.state').set_project_root(nil)
    -- Spy: track whether vim.fn.system was called with a dispose URL
    _G.dispose_called = false
    local orig_system = vim.fn.system
    vim.fn.system = function(cmd)
      if type(cmd) == 'table' then
        for _, v in ipairs(cmd) do
          if type(v) == 'string' and v:find('instance/dispose') then
            _G.dispose_called = true
          end
        end
      end
      return orig_system(cmd)
    end
  ]])

	child.lua([[vim.api.nvim_exec_autocmds('VimLeavePre', {})]])

	local called = child.lua_get([[_G.dispose_called]])
	MiniTest.expect.equality(called, false, "dispose_instance_sync should NOT be called when port is nil")
end

T["autocmds"]["VimLeavePre calls dispose when port and project_root are set"] = function()
	child.lua([[
    require('plugin.state').set_port(60042)
    require('plugin.state').set_project_root('/tmp/test-project')
    -- Spy: capture the args passed to vim.fn.system
    _G.dispose_called = false
    _G.dispose_url = nil
    local orig_system = vim.fn.system
    vim.fn.system = function(cmd)
      if type(cmd) == 'table' then
        for _, v in ipairs(cmd) do
          if type(v) == 'string' and v:find('instance/dispose') then
            _G.dispose_called = true
            _G.dispose_url = v
          end
        end
      end
      -- Return a fake 200 so dispose_instance_sync returns true
      return '200'
    end
  ]])

	child.lua([[vim.api.nvim_exec_autocmds('VimLeavePre', {})]])

	local called = child.lua_get([[_G.dispose_called]])
	local url = child.lua_get([[_G.dispose_url]])

	MiniTest.expect.equality(called, true, "dispose_instance_sync should be called when port and project_root are set")
	MiniTest.expect.equality(
		type(url),
		"string",
		"A URL containing 'instance/dispose' should have been passed to vim.fn.system"
	)
	MiniTest.expect.equality(
		url:find("60042") ~= nil,
		true,
		"URL should contain the correct port"
	)
	MiniTest.expect.equality(
		url:find("/tmp/test%-project") ~= nil,
		true,
		"URL should contain the project root directory"
	)
end

return T
