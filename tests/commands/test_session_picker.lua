local MiniTest = require("mini.test")
local T = MiniTest.new_set()

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local NOTIFY_HOOK = [[
  _G.notifications = {}
  vim.notify = function(msg, level)
    table.insert(_G.notifications, { msg = msg, level = level })
  end
]]

-- Two stub sessions returned by mock list_sessions
local MOCK_SESSIONS_HOOK = [[
  _G.mock_sessions = {
    { id = "ses_abc123", title = "Refactor auth module", slug = "refactor-auth", projectID = "proj_1", directory = "/tmp", version = 1, time = { created = 1000, updated = 2000 } },
    { id = "ses_def456", title = "",                    slug = "untitled",       projectID = "proj_1", directory = "/tmp", version = 1, time = { created = 900,  updated = 1900 } },
  }
  local Client = require('plugin.client')
  function Client:list_sessions(callback)
    callback(nil, _G.mock_sessions)
  end
]]

-- ---------------------------------------------------------------------------
-- Command registration
-- ---------------------------------------------------------------------------

T["OCSessionPick command"] = MiniTest.new_set()

T["OCSessionPick command"]["is registered after setup"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])

  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands["OCSessionPick"], nil)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- session_picker.pick() — guard conditions
-- ---------------------------------------------------------------------------

T["session_picker.pick()"] = MiniTest.new_set()

T["session_picker.pick()"]["shows error when list_sessions fails"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    local Client = require('plugin.client')
    function Client:list_sessions(callback)
      callback("connection refused", nil)
    end
  ]])

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("Failed to fetch sessions") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

  child.stop()
end

T["session_picker.pick()"]["shows warning when no sessions are available"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    local Client = require('plugin.client')
    function Client:list_sessions(callback)
      callback(nil, {})
    end
  ]])

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("No sessions available") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.WARN)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- session_picker.pick() — picker interaction & TUI navigation
-- ---------------------------------------------------------------------------

T["session_picker.pick()"]["opens picker with all sessions from list_sessions"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_SESSIONS_HOOK)

  -- Stub vim.ui.select to capture items and cancel
  child.lua([[
    _G.picker_items = nil
    vim.ui.select = function(items, opts, callback)
      _G.picker_items = items
      callback(nil)   -- simulate cancel
    end
  ]])

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local items = child.lua_get([[_G.picker_items]])
  MiniTest.expect.no_equality(items, nil)
  MiniTest.expect.equality(#items, 2)
  MiniTest.expect.equality(items[1].id, "ses_abc123")
  MiniTest.expect.equality(items[2].id, "ses_def456")

  -- No notifications on cancel
  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

T["session_picker.pick()"]["calls tui_publish with selected session ID"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_SESSIONS_HOOK)

  -- Stub vim.ui.select to select the first session
  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(items[1])
    end
  ]])

  -- Track tui_publish calls
  child.lua([[
    _G.published = nil
    local Client = require('plugin.client')
    function Client:tui_publish(event_type, properties, callback)
      _G.published = { event_type = event_type, properties = properties }
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local published = child.lua_get([[_G.published]])
  MiniTest.expect.no_equality(published, nil)
  MiniTest.expect.equality(published.event_type, "tui.session.select")
  MiniTest.expect.equality(published.properties.sessionID, "ses_abc123")

  -- No notifications on success (silent navigation)
  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

T["session_picker.pick()"]["shows error when tui_publish fails"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_SESSIONS_HOOK)

  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(items[1])
    end
  ]])

  child.lua([[
    local Client = require('plugin.client')
    function Client:tui_publish(event_type, properties, callback)
      callback("server error", nil)
    end
  ]])

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("Failed to navigate to session") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.ERROR)

  child.stop()
end

T["session_picker.pick()"]["does not call tui_publish when user cancels picker"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)
  child.lua(MOCK_SESSIONS_HOOK)

  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(nil)  -- simulate cancel
    end
  ]])

  child.lua([[
    _G.publish_called = false
    local Client = require('plugin.client')
    function Client:tui_publish(event_type, properties, callback)
      _G.publish_called = true
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local publish_called = child.lua_get([[_G.publish_called]])
  MiniTest.expect.equality(publish_called, false)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- Picker format_item
-- ---------------------------------------------------------------------------

T["session_picker.pick()"]["format_item shows title when non-empty"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    local Client = require('plugin.client')
    function Client:list_sessions(callback)
      callback(nil, {
        { id = "ses_abc123", title = "Refactor auth module", slug = "s1", projectID = "p1", directory = "/tmp", version = 1, time = { created = 1, updated = 2 } },
        { id = "ses_def456", title = "",                    slug = "s2", projectID = "p1", directory = "/tmp", version = 1, time = { created = 1, updated = 2 } },
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

  child.lua([[require('plugin.commands.session_picker').pick()]])

  vim.uv.sleep(100)

  local formatted = child.lua_get([[_G.formatted]])
  MiniTest.expect.equality(#formatted, 2)
  -- With title: show title
  MiniTest.expect.equality(formatted[1], "Refactor auth module")
  -- Without title: fall back to ID
  MiniTest.expect.equality(formatted[2], "ses_def456")

  child.stop()
end

-- ---------------------------------------------------------------------------
-- Keymap
-- ---------------------------------------------------------------------------

T["session_picker keymap"] = MiniTest.new_set()

T["session_picker keymap"]["<leader>oss triggers OCSessionPick"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua([[require('plugin.state').set_port(4096)]])

  child.lua([[
    _G.pick_called = false
    local Client = require('plugin.client')
    function Client:list_sessions(callback)
      _G.pick_called = true
      callback(nil, {})
    end
  ]])

  child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>oss', true, false, true), 'x', false)]])
  vim.uv.sleep(100)

  local pick_called = child.lua_get([[_G.pick_called]])
  MiniTest.expect.equality(pick_called, true)

  child.stop()
end

return T
