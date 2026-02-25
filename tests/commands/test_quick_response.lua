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

-- ---------------------------------------------------------------------------
-- Command registration
-- ---------------------------------------------------------------------------

T["OCQuickResponse command"] = MiniTest.new_set()

T["OCQuickResponse command"]["is registered after setup"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])

  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands["OCQuickResponse"], nil)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- quick_response.send() — picker
-- ---------------------------------------------------------------------------

T["quick_response.send()"] = MiniTest.new_set()

T["quick_response.send()"]["shows picker with predefined options plus Custom..."] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    _G.picker_items = nil
    vim.ui.select = function(items, opts, callback)
      _G.picker_items = items
      callback(nil)
    end
  ]])

  child.lua([[require('plugin.commands.quick_response').send()]])

  vim.uv.sleep(100)

  local items = child.lua_get([[_G.picker_items]])
  MiniTest.expect.no_equality(items, nil)
  MiniTest.expect.equality(#items, 5)
  MiniTest.expect.equality(items[1], "Yes")
  MiniTest.expect.equality(items[2], "Agree, proceed")
  MiniTest.expect.equality(items[3], "Commit")
  MiniTest.expect.equality(items[4], "Recommendations?")
  MiniTest.expect.equality(items[5], "Custom...")

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

T["quick_response.send()"]["does nothing when user cancels picker"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(nil)
    end
  ]])

  child.lua([[
    _G.tui_publish_called = false
    local Client = require('plugin.client')
    function Client:tui_publish(event, props, callback)
      _G.tui_publish_called = true
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.quick_response').send()]])

  vim.uv.sleep(100)

  local tui_publish_called = child.lua_get([[_G.tui_publish_called]])
  MiniTest.expect.equality(tui_publish_called, false)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

T["quick_response.send()"]["sends predefined response when selected"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    vim.ui.select = function(items, opts, callback)
      callback(items[1])  -- select "Yes"
    end
  ]])

  child.lua([[
    _G.tui_events = {}
    local Client = require('plugin.client')
    function Client:tui_publish(event, props, callback)
      table.insert(_G.tui_events, { event = event, props = props })
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.quick_response').send()]])

  vim.uv.sleep(100)

  local events = child.lua_get([[_G.tui_events]])
  MiniTest.expect.equality(#events, 2)
  MiniTest.expect.equality(events[1].event, "tui.prompt.append")
  MiniTest.expect.equality(events[1].props.text, "Yes")
  MiniTest.expect.equality(events[2].event, "tui.command.execute")
  MiniTest.expect.equality(events[2].props.command, "prompt.submit")

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 1)
  MiniTest.expect.equality(notifications[1].msg:match("Quick response sent") ~= nil, true)
  MiniTest.expect.equality(notifications[1].level, vim.log.levels.INFO)

  child.stop()
end

T["quick_response.send()"]["opens input when Custom... is selected"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    _G.select_count = 0
    vim.ui.select = function(items, opts, callback)
      _G.select_count = _G.select_count + 1
      if _G.select_count == 1 then
        callback(items[5])  -- select "Custom..."
      end
    end

    vim.ui.input = function(opts, input_callback)
      input_callback("my custom response")
    end
  ]])

  child.lua([[
    _G.tui_events = {}
    local Client = require('plugin.client')
    function Client:tui_publish(event, props, callback)
      table.insert(_G.tui_events, { event = event, props = props })
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.quick_response').send()]])

  vim.uv.sleep(100)

  local events = child.lua_get([[_G.tui_events]])
  MiniTest.expect.equality(#events, 2)
  MiniTest.expect.equality(events[1].event, "tui.prompt.append")
  MiniTest.expect.equality(events[1].props.text, "my custom response")

  child.stop()
end

T["quick_response.send()"]["does nothing when custom input is empty"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    _G.select_count = 0
    vim.ui.select = function(items, opts, callback)
      _G.select_count = _G.select_count + 1
      if _G.select_count == 1 then
        callback(items[5])  -- select "Custom..."
      end
    end

    vim.ui.input = function(opts, input_callback)
      input_callback("")
    end
  ]])

  child.lua([[
    _G.tui_publish_called = false
    local Client = require('plugin.client')
    function Client:tui_publish(event, props, callback)
      _G.tui_publish_called = true
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.quick_response').send()]])

  vim.uv.sleep(100)

  local tui_publish_called = child.lua_get([[_G.tui_publish_called]])
  MiniTest.expect.equality(tui_publish_called, false)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

T["quick_response.send()"]["does nothing when custom input is cancelled"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])
  child.lua(NOTIFY_HOOK)

  child.lua([[
    _G.select_count = 0
    vim.ui.select = function(items, opts, callback)
      _G.select_count = _G.select_count + 1
      if _G.select_count == 1 then
        callback(items[5])  -- select "Custom..."
      end
    end

    vim.ui.input = function(opts, input_callback)
      input_callback(nil)
    end
  ]])

  child.lua([[
    _G.tui_publish_called = false
    local Client = require('plugin.client')
    function Client:tui_publish(event, props, callback)
      _G.tui_publish_called = true
      callback(nil, true)
    end
  ]])

  child.lua([[require('plugin.commands.quick_response').send()]])

  vim.uv.sleep(100)

  local tui_publish_called = child.lua_get([[_G.tui_publish_called]])
  MiniTest.expect.equality(tui_publish_called, false)

  local notifications = child.lua_get([[_G.notifications]])
  MiniTest.expect.equality(#notifications, 0)

  child.stop()
end

-- ---------------------------------------------------------------------------
-- Keymap
-- ---------------------------------------------------------------------------

T["quick_response keymap"] = MiniTest.new_set()

T["quick_response keymap"]["<C-y> triggers OCQuickResponse"] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ "-u", "scripts/minimal_init.lua" })

  child.lua([[require('plugin').setup()]])

  child.lua([[
    _G.send_called = false
    local original = require
    _G.require = function(mod)
      if mod == 'plugin.commands.quick_response' then
        return { send = function() _G.send_called = true end }
      end
      return original(mod)
    end
  ]])

  child.lua([[vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-y>', true, false, true), 'x', false)]])
  vim.uv.sleep(100)

  local send_called = child.lua_get([[_G.send_called]])
  MiniTest.expect.equality(send_called, true)

  child.stop()
end

return T
