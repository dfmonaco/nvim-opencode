local MiniTest = require("mini.test")
local T = MiniTest.new_set()

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Helper: intercept vim.notify in the child process and collect notifications
local NOTIFY_HOOK = [[
  _G.notifications = {}
  vim.notify = function(msg, level)
    table.insert(_G.notifications, { msg = msg, level = level })
  end
]]

-- ---------------------------------------------------------------------------
-- Command registration
-- ---------------------------------------------------------------------------

T["TUI commands"] = MiniTest.new_set()

T["TUI commands"]["OCTuiAppend is registered after setup"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])

	local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
	MiniTest.expect.no_equality(commands["OCTuiAppend"], nil)

	child.stop()
end

T["TUI commands"]["OCTuiSend is registered after setup"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])

	local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
	MiniTest.expect.no_equality(commands["OCTuiSend"], nil)

	child.stop()
end

T["TUI commands"]["OCTuiCmd is registered after setup"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])

	local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
	MiniTest.expect.no_equality(commands["OCTuiCmd"], nil)

	child.stop()
end

-- ---------------------------------------------------------------------------
-- tui.append() — guard & happy path
-- ---------------------------------------------------------------------------

T["tui.append()"] = MiniTest.new_set()

T["tui.append()"]["shows error when port is not set"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(nil)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'some content'})]])

	child.lua([[require('plugin.commands.tui').append()]])

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("No OpenCode server port") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

T["tui.append()"]["shows warning when buffer is empty"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")

	child.lua([[require('plugin.commands.tui').append()]])

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.WARN)

	child.stop()
end

T["tui.append()"]["calls tui_append_prompt with buffer content"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'hello from neovim', 'line two'})]])

	-- Mock the client method
	child.lua([[
		_G.captured_appends = {}
		local Client = require('plugin.client')
		function Client:tui_append_prompt(text, callback)
			table.insert(_G.captured_appends, text)
			callback(nil, true)
		end
	]])

	child.lua([[require('plugin.commands.tui').append()]])

	vim.uv.sleep(100)

	local captured = child.lua_get([[_G.captured_appends]])
	MiniTest.expect.equality(#captured, 1)
	MiniTest.expect.equality(captured[1], "hello from neovim\nline two")

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("Appended to TUI prompt") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.INFO)

	child.stop()
end

T["tui.append()"]["shows error when client request fails"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'some content'})]])

	child.lua([[
		local Client = require('plugin.client')
		function Client:tui_append_prompt(text, callback)
			callback("connection refused", nil)
		end
	]])

	child.lua([[require('plugin.commands.tui').append()]])

	vim.uv.sleep(100)

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("Failed to append") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

-- ---------------------------------------------------------------------------
-- tui.append_and_submit()
-- ---------------------------------------------------------------------------

T["tui.append_and_submit()"] = MiniTest.new_set()

T["tui.append_and_submit()"]["shows error when port is not set"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(nil)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'some content'})]])

	child.lua([[require('plugin.commands.tui').append_and_submit()]])

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("No OpenCode server port") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

T["tui.append_and_submit()"]["appends then submits and notifies success"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'send and go'})]])

	-- Mock both client methods
	child.lua([[
		_G.append_called = false
		_G.submit_called = false
		local Client = require('plugin.client')
		function Client:tui_append_prompt(text, callback)
			_G.append_called = true
			callback(nil, true)
		end
		function Client:tui_submit_prompt(callback)
			_G.submit_called = true
			callback(nil, true)
		end
	]])

	child.lua([[require('plugin.commands.tui').append_and_submit()]])

	vim.uv.sleep(200)

	local append_called = child.lua_get([[_G.append_called]])
	local submit_called = child.lua_get([[_G.submit_called]])
	MiniTest.expect.equality(append_called, true)
	MiniTest.expect.equality(submit_called, true)

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("Prompt submitted to TUI") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.INFO)

	child.stop()
end

T["tui.append_and_submit()"]["does not submit when append fails"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'content'})]])

	child.lua([[
		_G.submit_called = false
		local Client = require('plugin.client')
		function Client:tui_append_prompt(text, callback)
			callback("append failed", nil)
		end
		function Client:tui_submit_prompt(callback)
			_G.submit_called = true
			callback(nil, true)
		end
	]])

	child.lua([[require('plugin.commands.tui').append_and_submit()]])

	vim.uv.sleep(200)

	local submit_called = child.lua_get([[_G.submit_called]])
	MiniTest.expect.equality(submit_called, false)

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

-- ---------------------------------------------------------------------------
-- tui.execute()
-- ---------------------------------------------------------------------------

T["tui.execute()"] = MiniTest.new_set()

T["tui.execute()"]["shows error when port is not set"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(nil)]])
	child.lua(NOTIFY_HOOK)

	child.lua([[require('plugin.commands.tui').execute('session.interrupt')]])

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("No OpenCode server port") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

T["tui.execute()"]["shows error when no command is given"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.lua([[require('plugin.commands.tui').execute('')]])

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("No TUI command specified") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

T["tui.execute()"]["calls tui_execute_command with the correct command name"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.lua([[
		_G.captured_commands = {}
		local Client = require('plugin.client')
		function Client:tui_execute_command(command, callback)
			table.insert(_G.captured_commands, command)
			callback(nil, true)
		end
	]])

	child.lua([[require('plugin.commands.tui').execute('session.interrupt')]])

	vim.uv.sleep(100)

	local captured = child.lua_get([[_G.captured_commands]])
	MiniTest.expect.equality(#captured, 1)
	MiniTest.expect.equality(captured[1], "session.interrupt")

	-- execute notifies success
	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("session.interrupt.*executed") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.INFO)

	child.stop()
end

T["tui.execute()"]["shows error when client request fails"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])
	child.lua(NOTIFY_HOOK)

	child.lua([[
		local Client = require('plugin.client')
		function Client:tui_execute_command(command, callback)
			callback("connection refused", nil)
		end
	]])

	child.lua([[require('plugin.commands.tui').execute('session.new')]])

	vim.uv.sleep(100)

	local notifications = child.lua_get([[_G.notifications]])
	MiniTest.expect.equality(#notifications, 1)
	MiniTest.expect.equality(notifications[1].msg:match("Failed to execute TUI command") ~= nil, true)
	MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

	child.stop()
end

-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------

T["TUI keymaps"] = MiniTest.new_set()

T["TUI keymaps"]["<leader>Oa keymap triggers OCTuiAppend"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'content'})]])

	child.lua([[
		_G.append_triggered = false
		local Client = require('plugin.client')
		function Client:tui_append_prompt(text, callback)
			_G.append_triggered = true
			callback(nil, true)
		end
	]])

	child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>Oa', true, false, true), 'x', false)]])
	vim.uv.sleep(200)

	local triggered = child.lua_get([[_G.append_triggered]])
	MiniTest.expect.equality(triggered, true)

	child.stop()
end

T["TUI keymaps"]["<leader>OS keymap triggers OCTuiSend"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])

	child.cmd("enew")
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'content'})]])

	child.lua([[
		_G.submit_triggered = false
		local Client = require('plugin.client')
		function Client:tui_append_prompt(text, callback) callback(nil, true) end
		function Client:tui_submit_prompt(callback)
			_G.submit_triggered = true
			callback(nil, true)
		end
	]])

	child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>OS', true, false, true), 'x', false)]])
	vim.uv.sleep(200)

	local triggered = child.lua_get([[_G.submit_triggered]])
	MiniTest.expect.equality(triggered, true)

	child.stop()
end

T["TUI keymaps"]["<leader>Oi keymap triggers session.interrupt command"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])

	child.lua([[
		_G.interrupt_triggered = false
		local Client = require('plugin.client')
		function Client:tui_execute_command(command, callback)
			if command == 'session.interrupt' then
				_G.interrupt_triggered = true
			end
			callback(nil, true)
		end
	]])

	child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>Oi', true, false, true), 'x', false)]])
	vim.uv.sleep(200)

	local triggered = child.lua_get([[_G.interrupt_triggered]])
	MiniTest.expect.equality(triggered, true)

	child.stop()
end

T["TUI keymaps"]["<leader>On keymap triggers session.new command"] = function()
	local child = MiniTest.new_child_neovim()
	child.restart({ "-u", "scripts/minimal_init.lua" })

	child.lua([[require('plugin').setup()]])
	child.lua([[require('plugin.state').set_port(4096)]])

	child.lua([[
		_G.new_triggered = false
		local Client = require('plugin.client')
		function Client:tui_execute_command(command, callback)
			if command == 'session.new' then
				_G.new_triggered = true
			end
			callback(nil, true)
		end
	]])

	child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>On', true, false, true), 'x', false)]])
	vim.uv.sleep(200)

	local triggered = child.lua_get([[_G.new_triggered]])
	MiniTest.expect.equality(triggered, true)

	child.stop()
end

return T
