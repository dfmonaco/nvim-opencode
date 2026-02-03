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

T['OC command']['opens terminal in vertical split'] = function()
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
  
  -- Check that the right window has a terminal buffer
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

return T
