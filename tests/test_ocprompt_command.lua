local MiniTest = require('mini.test')
local T = MiniTest.new_set()

T['OCPrompt command'] = MiniTest.new_set()

T['OCPrompt command']['is registered after setup'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Check if command exists
  local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
  MiniTest.expect.no_equality(commands['OCPrompt'], nil)
  
  child.stop()
end

T['OCPrompt command']['creates buffer on first call'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Execute OCPrompt command
  child.cmd('OCPrompt')
  
  -- Check that current buffer name ends with OCPrompt
  local buf_name = child.lua_get([[vim.api.nvim_buf_get_name(0)]])
  local name_matches = buf_name:match('OCPrompt$') ~= nil
  MiniTest.expect.equality(name_matches, true)
  
  child.stop()
end

T['OCPrompt command']['sets correct buffer options'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Check buffer-local options set at creation
  local buftype = child.lua_get([[vim.bo.buftype]])
  MiniTest.expect.equality(buftype, 'nofile')
  
  local filetype = child.lua_get([[vim.bo.filetype]])
  MiniTest.expect.equality(filetype, 'OCPrompt')
  
  -- Check buffer-local options set in ftplugin
  local buflisted = child.lua_get([[vim.bo.buflisted]])
  MiniTest.expect.equality(buflisted, true)
  
  local bufhidden = child.lua_get([[vim.bo.bufhidden]])
  MiniTest.expect.equality(bufhidden, 'hide')
  
  local swapfile = child.lua_get([[vim.bo.swapfile]])
  MiniTest.expect.equality(swapfile, false)
  
  local spellcapcheck = child.lua_get([[vim.bo.spellcapcheck]])
  MiniTest.expect.equality(spellcapcheck, '')
  
  child.stop()
end

T['OCPrompt command']['sets correct window options'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Check window-local options set in ftplugin
  local number = child.lua_get([[vim.wo.number]])
  MiniTest.expect.equality(number, false)
  
  local relativenumber = child.lua_get([[vim.wo.relativenumber]])
  MiniTest.expect.equality(relativenumber, false)
  
  local wrap = child.lua_get([[vim.wo.wrap]])
  MiniTest.expect.equality(wrap, true)
  
  local linebreak = child.lua_get([[vim.wo.linebreak]])
  MiniTest.expect.equality(linebreak, true)
  
  local breakindent = child.lua_get([[vim.wo.breakindent]])
  MiniTest.expect.equality(breakindent, true)
  
  -- Note: spell option behavior can vary in headless mode, so we skip testing it
  
  child.stop()
end

T['OCPrompt command']['reuses buffer on subsequent calls'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- First call
  child.cmd('OCPrompt')
  local first_bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
  
  -- Add some text
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'test content'})]])
  
  -- Switch to another buffer
  child.cmd('enew')
  local other_bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
  MiniTest.expect.no_equality(first_bufnr, other_bufnr)
  
  -- Second call - should reuse same buffer
  child.cmd('OCPrompt')
  local second_bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
  MiniTest.expect.equality(second_bufnr, first_bufnr)
  
  -- Check that content is preserved
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
  MiniTest.expect.equality(lines, { 'test content' })
  
  child.stop()
end

T['OCPrompt command']['enters insert mode on open'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Start in normal mode
  local initial_mode = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(initial_mode, 'n')
  
  -- Execute OCPrompt command
  child.cmd('OCPrompt')
  
  -- Should be in insert mode
  local mode = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode, 'i')
  
  child.stop()
end

T['OCPrompt command']['opens in current window'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Get initial window count
  local initial_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  
  -- Execute OCPrompt command
  child.cmd('OCPrompt')
  
  -- Window count should not increase (no split)
  local new_win_count = child.lua_get([[#vim.api.nvim_list_wins()]])
  MiniTest.expect.equality(new_win_count, initial_win_count)
  
  child.stop()
end

T['OCPrompt command']['buffer persists after switching away'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Create OCPrompt buffer and add content
  child.cmd('OCPrompt')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'persistent content'})]])
  local prompt_bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
  
  -- Switch to new buffer
  child.cmd('enew')
  
  -- Check that OCPrompt buffer still exists and is listed
  local buf_valid = child.lua_get(string.format([[vim.api.nvim_buf_is_valid(%d)]], prompt_bufnr))
  MiniTest.expect.equality(buf_valid, true)
  
  local buf_listed = child.lua_get(string.format([[vim.bo[%d].buflisted]], prompt_bufnr))
  MiniTest.expect.equality(buf_listed, true)
  
  -- Check that buffer appears in buffer list
  local in_buf_list = child.lua_get(string.format([[
    (function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf == %d and vim.fn.buflisted(buf) == 1 then
          return true
        end
      end
      return false
    end)()
  ]], prompt_bufnr))
  MiniTest.expect.equality(in_buf_list, true)
  
  child.stop()
end

T['OCPrompt command']['<C-x> keymap clears buffer in normal mode'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Create OCPrompt and add content
  child.cmd('OCPrompt')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'line 1', 'line 2', 'line 3'})]])
  
  -- Exit insert mode
  child.type_keys('<Esc>')
  
  -- Press <C-x> in normal mode
  child.type_keys('<C-x>')
  
  -- Check buffer is cleared (may have one empty line)
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
  local is_empty = #lines == 0 or (#lines == 1 and lines[1] == '')
  MiniTest.expect.equality(is_empty, true)
  
  -- Should still be in normal mode
  local mode = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode, 'n')
  
  child.stop()
end

T['OCPrompt command']['<C-x> keymap clears buffer in insert mode'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Create OCPrompt and add content
  child.cmd('OCPrompt')
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'line 1', 'line 2'})]])
  
  -- Enter insert mode
  child.type_keys('i')
  
  -- Press <C-x> in insert mode
  child.type_keys('<C-x>')
  
  -- Check buffer is cleared (may have one empty line)
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
  local is_empty = #lines == 0 or (#lines == 1 and lines[1] == '')
  MiniTest.expect.equality(is_empty, true)
  
  -- Should still be in insert mode
  local mode = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode, 'i')
  
  child.stop()
end

T['OCPrompt command']['window options are buffer-specific'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Create a normal buffer with specific window options
  child.cmd('enew')
  child.lua([[
    vim.wo.number = true
    vim.wo.relativenumber = true
    vim.wo.wrap = false
  ]])
  
  -- Verify normal buffer has those options
  local normal_number = child.lua_get([[vim.wo.number]])
  MiniTest.expect.equality(normal_number, true)
  
  -- Open OCPrompt in same window
  child.cmd('OCPrompt')
  
  -- Verify OCPrompt has its own window options
  local oc_number = child.lua_get([[vim.wo.number]])
  MiniTest.expect.equality(oc_number, false)
  
  local oc_wrap = child.lua_get([[vim.wo.wrap]])
  MiniTest.expect.equality(oc_wrap, true)
  
  child.stop()
end

T['OCPrompt command']['state is cleared when buffer is deleted'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  
  -- Create OCPrompt
  child.cmd('OCPrompt')
  local first_bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
  
  -- Delete the buffer
  child.type_keys('<Esc>')
  child.cmd('bdelete!')
  
  -- Create OCPrompt again - should get a new buffer
  child.cmd('OCPrompt')
  local second_bufnr = child.lua_get([[vim.api.nvim_get_current_buf()]])
  
  -- Should be a different buffer
  MiniTest.expect.no_equality(first_bufnr, second_bufnr)
  
  child.stop()
end

return T
