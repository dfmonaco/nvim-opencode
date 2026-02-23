local MiniTest = require('mini.test')
local T = MiniTest.new_set()

T['OC command'] = MiniTest.new_set()

-- Helper: wait up to `ms` milliseconds for a terminal buffer to appear in any window.
local function wait_for_terminal(child, ms)
  child.lua(string.format([[
    vim.wait(%d, function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal' then
          return true
        end
      end
      return false
    end, 20)
  ]], ms or 2000))
end

T['OC command']['is registered after setup'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands['OC'], nil)

  child.stop()
end

T['OC command']['creates terminal on first call'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  local initial_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  local initial_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])

  child.cmd('OC')
  wait_for_terminal(child)

  local new_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(new_win_count, initial_win_count + 1)

  local current_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])
  MiniTest.expect.equality(current_win_id, initial_win_id)

  local is_terminal = child.lua_get([[
    (function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal' then
          return true
        end
      end
      return false
    end)()
  ]])
  MiniTest.expect.equality(is_terminal, true)

  child.stop()
end

T['OC command']['hides terminal on second call'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  local initial_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])

  child.cmd('OC')
  wait_for_terminal(child)
  local after_create_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(after_create_count, initial_win_count + 1)

  child.cmd('OC')
  local after_hide_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(after_hide_count, initial_win_count)

  child.stop()
end

T['OC command']['shows terminal on third call'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  local initial_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  local initial_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])

  child.cmd('OC')
  wait_for_terminal(child)

  child.cmd('OC')
  child.cmd('OC')

  local after_show_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(after_show_count, initial_win_count + 1)

  local current_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])
  MiniTest.expect.equality(current_win_id, initial_win_id)

  local is_terminal = child.lua_get([[
    (function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal' then
          return true
        end
      end
      return false
    end)()
  ]])
  MiniTest.expect.equality(is_terminal, true)

  child.stop()
end

T['OC command']['terminal buffer is not listed'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  child.cmd('OC')
  wait_for_terminal(child)

  local is_unlisted = child.lua_get([[
    (function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal' then
          return not vim.api.nvim_get_option_value('buflisted', { buf = buf })
        end
      end
      return false
    end)()
  ]])
  MiniTest.expect.equality(is_unlisted, true)

  child.stop()
end

T['OC command']['launches opencode process on terminal creation'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  child.cmd('OC')
  wait_for_terminal(child)

  local term_buf_name = child.lua_get([[
    (function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal' then
          return vim.api.nvim_buf_get_name(buf)
        end
      end
      return ''
    end)()
  ]])

  local contains_opencode = term_buf_name:match('opencode') ~= nil
  MiniTest.expect.equality(contains_opencode, true)

  local port_pattern = term_buf_name:match('%-%-port%s+(%d+)')
  local port = tonumber(port_pattern)
  MiniTest.expect.equality(port ~= nil, true, "Port should be present in terminal command")
  MiniTest.expect.equality(port >= 60000 and port <= 61000, true, "Port should be in allocated range")

  child.stop()
end

T['OC command']['stores session ID after server starts'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  child.cmd('OC')

  child.lua([[
    _G.session_id = nil
    _G.found = vim.wait(6000, function()
      local State = require('plugin.state')
      _G.session_id = State.get_session_id()
      return _G.session_id ~= nil
    end, 100)
  ]])

  local found = child.lua_get([[_G.found]])
  local session_id = child.lua_get([[_G.session_id]])

  MiniTest.expect.equality(found, true, "Session ID should be stored within 6 seconds")
  MiniTest.expect.no_equality(session_id, vim.NIL, "Session ID should not be nil")
  MiniTest.expect.equality(type(session_id), "string", "Session ID should be a string")
  MiniTest.expect.equality(session_id:sub(1, 4), "ses_", "Session ID should start with 'ses_'")

  child.stop()
end

T['OC command']['session ID can be retrieved from state'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])

  child.cmd('OC')

  child.lua([[
    vim.wait(6000, function()
      return require('plugin.state').get_session_id() ~= nil
    end, 100)
  ]])

  child.lua([[
    _G.retrieved_session_id = require('plugin.state').get_session_id()
  ]])
  local session_id = child.lua_get([[_G.retrieved_session_id]])

  MiniTest.expect.no_equality(session_id, vim.NIL, "Should be able to retrieve session ID from state")
  MiniTest.expect.equality(type(session_id), "string", "Retrieved session ID should be a string")

  child.stop()
end

return T
