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

-- Two stub slash commands returned by mock list_commands
local MOCK_COMMANDS_HOOK = [[
  _G.mock_commands = {
    { name = "compact", description = "Compact the session", template = "", hints = {}, subtask = false },
    { name = "review",  description = "Review the code",    template = "", hints = {}, subtask = false },
  }
  local Client = require('plugin.client')
  function Client:list_commands(callback)
    callback(nil, _G.mock_commands)
  end
]]

-- ---------------------------------------------------------------------------
-- Command registration
-- ---------------------------------------------------------------------------

T["OCSlashCommand command"] = MiniTest.new_set()

T["OCSlashCommand command"]["is registered after setup"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])

  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands["OCSlashCommand"], nil)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- slash_command.pick() — guard conditions
-- ---------------------------------------------------------------------------

T["slash_command.pick()"] = MiniTest.new_set()

T["slash_command.pick()"]["shows error when session is not set"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id(nil)]])
  child.lua(NOTIFY_HOOK)

  child.lua([[require('plugin.commands.slash_command').pick()]])

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("No active session") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

  child.stop()
end

T["slash_command.pick()"]["shows error when list_commands fails"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_test123')]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    local Client = require('plugin.client')
    function Client:list_commands(callback)
      callback("connection refused", nil)
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("Failed to fetch slash commands") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

  child.stop()
end

T["slash_command.pick()"]["shows warning when no commands are available"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_test123')]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    local Client = require('plugin.client')
    function Client:list_commands(callback)
      callback(nil, {})
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("No slash commands available") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.WARN)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- slash_command.pick() — picker interaction & execution
-- ---------------------------------------------------------------------------

T["slash_command.pick()"]["opens picker with all commands from list_commands"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_test123')]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_COMMANDS_HOOK)

  -- Stub vim.ui.select to capture items and cancel (nil selection)
  child.lua([[
    _G.picker_items = nil
    vim.ui.select = function(items, opts, callback)
      _G.picker_items = items
      callback(nil)   -- simulate cancel
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local items = child.lua_get([[_G.picker_items]])
  MiniTest.expect.no_equality(items, nil)
  MiniTest.expect.equality(#items, 2)
  MiniTest.expect.equality(items[1].name, "compact")
  MiniTest.expect.equality(items[2].name, "review")

  -- No notifications on cancel
  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

T["slash_command.pick()"]["calls execute_command with selected command name"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_abc')]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_COMMANDS_HOOK)

  -- Stub vim.ui.select to select the first command ("compact")
  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(items[1])
    end
  ]])

  -- Track execute_command calls
  child.lua([[
    _G.executed = nil
    local Client = require('plugin.client')
    function Client:execute_command(session_id, command_name, opts, callback)
      _G.executed = { session_id = session_id, command_name = command_name }
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local executed = child.lua_get([[_G.executed]])
  MiniTest.expect.no_equality(executed, nil)
  MiniTest.expect.equality(executed.session_id, "ses_abc")
  MiniTest.expect.equality(executed.command_name, "compact")

  -- Success notification
  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("Executed /compact") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.INFO)

  child.stop()
end

T["slash_command.pick()"]["shows error when execute_command fails"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_abc')]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_COMMANDS_HOOK)

  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(items[1])   -- select "compact"
    end
  ]])

  child.lua([[
    local Client = require('plugin.client')
    function Client:execute_command(session_id, command_name, opts, callback)
      callback("server error", nil)
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("Failed to execute /compact") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

  child.stop()
end

T["slash_command.pick()"]["does not call execute_command when user cancels picker"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_abc')]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_COMMANDS_HOOK)

  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(nil)  -- simulate cancel
    end
  ]])

  child.lua([[
    _G.execute_called = false
    local Client = require('plugin.client')
    function Client:execute_command(session_id, command_name, opts, callback)
      _G.execute_called = true
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local execute_called = child.lua_get([[_G.execute_called]])
  MiniTest.expect.equality(execute_called, false)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- Picker format_item
-- ---------------------------------------------------------------------------

T["slash_command.pick()"]["format_item includes description when present"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_abc')]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    local Client = require('plugin.client')
    function Client:list_commands(callback)
      callback(nil, {
        { name = "compact", description = "Compact the session", template = "", hints = {} },
        { name = "nodesc",  description = "",                    template = "", hints = {} },
      })
    end
  ]])

  child.lua([[
    _G.formatted = {}
    vim.ui.select = function(items, opts, callback)
      for _, item in ipairs(items) do
        table.insert(_G.formatted, opts.format_item(item))
      end
      callback(nil)
    end
  ]])

  child.lua([[require('plugin.commands.slash_command').pick()]])

  vim.uv.sleep(100)

  local formatted = child.lua_get([[_G.formatted]])
  MiniTest.expect.equality(#formatted, 2)
  -- With description: "/compact  Compact the session"
  MiniTest.expect.equality(formatted[1]:match("^/compact") ~= nil, true)
  MiniTest.expect.equality(formatted[1]:match("Compact the session") ~= nil, true)
  -- Without description: "/nodesc"
  MiniTest.expect.equality(formatted[2], "/nodesc")

  child.stop()
end

-- ---------------------------------------------------------------------------
-- Keymap
-- ---------------------------------------------------------------------------

T["slash_command keymap"] = MiniTest.new_set()

T["slash_command keymap"]["<leader>o/ triggers OCSlashCommand"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua([[require('plugin.state').set_session_id('ses_abc')]])

  child.lua([[
    _G.pick_called = false
    local Client = require('plugin.client')
    function Client:list_commands(callback)
      _G.pick_called = true
      callback(nil, {})
    end
  ]])

  child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>o/', true, false, true), 'x', false)]])
  vim.uv.sleep(100)

  local pick_called = child.lua_get([[_G.pick_called]])
  MiniTest.expect.equality(pick_called, true)

  child.stop()
end

return T
