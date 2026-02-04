local MiniTest = require('mini.test')
local T = MiniTest.new_set()

T['OC command'] = MiniTest.new_set()

T['OC command']['is registered after setup'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Check if command exists
  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands['OC'], nil)
  
  child.stop()
end

T['OC command']['creates terminal on first call'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Get initial window count and window ID
  local initial_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  local initial_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])
  
  -- Execute OC command
  child.cmd('OC')
  
  -- Check that a new window was created
  local new_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(new_win_count, initial_win_count + 1)
  
  -- Check that focus remained on original window
  local current_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])
  MiniTest.expect.equality(current_win_id, initial_win_id)
  
  -- Check that a terminal buffer exists
  local is_terminal = child.lua_get([[
    (function()
      local wins = vim.api.nvim_list_wins()
      for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
        if buftype == 'terminal' then
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
  
  -- First call: create terminal
  child.cmd('OC')
  local after_create_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(after_create_count, initial_win_count + 1)
  
  -- Second call: hide terminal
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
  
  -- First call: create terminal
  child.cmd('OC')
  
  -- Second call: hide terminal
  child.cmd('OC')
  
  -- Third call: show terminal again
  child.cmd('OC')
  local after_show_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(after_show_count, initial_win_count + 1)
  
  -- Check that focus remained on original window
  local current_win_id = child.lua_get([[vim.api.nvim_get_current_win()]])
  MiniTest.expect.equality(current_win_id, initial_win_id)
  
  -- Check that terminal still exists
  local is_terminal = child.lua_get([[
    (function()
      local wins = vim.api.nvim_list_wins()
      for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
        if buftype == 'terminal' then
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
  
  -- Create terminal
  child.cmd('OC')
  
  -- Check that terminal buffer is not listed
  local is_unlisted = child.lua_get([[
    (function()
      local wins = vim.api.nvim_list_wins()
      for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
        if buftype == 'terminal' then
          local buflisted = vim.api.nvim_get_option_value('buflisted', { buf = buf })
          return not buflisted
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
  
  -- Create terminal
  child.cmd('OC')
  
  -- Get terminal buffer name (should contain the command)
  local term_buf_name = child.lua_get([[
    (function()
      local wins = vim.api.nvim_list_wins()
      for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
        if buftype == 'terminal' then
          return vim.api.nvim_buf_get_name(buf)
        end
      end
      return ''
    end)()
  ]])
  
  -- Terminal buffer name should contain 'opencode'
  -- Buffer names for terminals typically look like: term://path//pid:command
  local contains_opencode = term_buf_name:match('opencode') ~= nil
  MiniTest.expect.equality(contains_opencode, true)
  
  -- Verify the exact command includes the port flag
  local contains_port = term_buf_name:match('60000') ~= nil
  MiniTest.expect.equality(contains_port, true)
  
  child.stop()
end

return T
