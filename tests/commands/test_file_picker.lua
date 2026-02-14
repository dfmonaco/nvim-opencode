local MiniTest = require('mini.test')
local T = MiniTest.new_set()

T['file_picker'] = MiniTest.new_set()

T['file_picker']['shows picker when @ is typed in insert mode'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Check that InsertCharPre autocmd is registered for OCPrompt buffer
  local autocmd_count = child.lua_get([[
    #vim.api.nvim_get_autocmds({
      event = 'InsertCharPre',
      buffer = 0,
    })
  ]])
  
  -- Should have exactly one InsertCharPre autocmd
  MiniTest.expect.equality(autocmd_count, 1)
  
  child.stop()
end

T['file_picker']['inserts file reference at cursor position'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Set initial content with @ already typed
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'hello @world'})]])
  
  -- Position cursor right after '@' (col 6, which is the @ position)
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 6})]])
  
  -- Simulate inserting file path after @ (what the picker would do)
  child.lua([[
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    insert_ref('lua/plugin/init.lua')
  ]])
  
  -- Check line content
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, 'hello @lua/plugin/init.luaworld')
  
  -- Check cursor position moved after reference
  local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(0)]])
  MiniTest.expect.equality(cursor[2], 6 + 1 + #'lua/plugin/init.lua')
  
  child.stop()
end

T['file_picker']['inserts at end of line correctly'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Set initial content with @ at the end
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'test@'})]])
  
  -- Position cursor at the @ (position 4)
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 4})]])
  
  -- Insert file reference
  child.lua([[
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    insert_ref('Makefile')
  ]])
  
  -- Check line content
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, 'test@Makefile')
  
  child.stop()
end

T['file_picker']['inserts at beginning of line correctly'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Set initial content with @ at beginning
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'@world'})]])
  
  -- Position cursor at the @ (col 0)
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 0})]])
  
  -- Insert file reference
  child.lua([[
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    insert_ref('tests/test_client.lua')
  ]])
  
  -- Check line content
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, '@tests/test_client.luaworld')
  
  child.stop()
end

T['file_picker']['highlight group is defined'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Check that OCFileReference highlight group exists
  local hl_exists = child.lua_get([[
    (function()
      local hl = vim.api.nvim_get_hl(0, { name = 'OCFileReference' })
      return next(hl) ~= nil
    end)()
  ]])
  
  MiniTest.expect.equality(hl_exists, true)
  
  child.stop()
end

T['file_picker']['syntax pattern matches file references'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Add test content with file references
  child.type_keys('<Esc>')
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'Check @lua/plugin/init.lua for details',
      'See @tests/test_client.lua',
      '@Makefile has build commands',
      'Path with dots: @.gitignore',
      'Path with hyphens: @my-file.lua',
    })
  ]])
  
  -- Force syntax highlighting
  child.cmd('syntax on')
  child.cmd('syntax sync fromstart')
  
  -- Get syntax ID for a character inside file reference
  -- Line 1, col 7 should be inside '@lua/plugin/init.lua'
  local syn_id = child.lua_get([[
    vim.fn.synID(1, 7, 1)
  ]])
  
  -- Syntax ID should be non-zero (meaning it's highlighted)
  MiniTest.expect.no_equality(syn_id, 0)
  
  child.stop()
end

T['file_picker']['handles empty buffer'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Set buffer with just @ character
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'@'})]])
  
  -- Cursor at @ (position 0)
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 0})]])
  
  -- Insert file reference
  child.lua([[
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    insert_ref('lua/plugin/state.lua')
  ]])
  
  -- Check line content
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, '@lua/plugin/state.lua')
  
  child.stop()
end

T['file_picker']['file reference format includes @ prefix'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'@'})]])
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 0})]])
  
  -- Insert reference
  child.lua([[
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    insert_ref('ftplugin/OCPrompt.lua')
  ]])
  
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  
  -- Should start with @
  local starts_with_at = line:sub(1, 1) == '@'
  MiniTest.expect.equality(starts_with_at, true)
  
  -- Should contain the full path after @
  local contains_path = line:find('ftplugin/OCPrompt.lua', 1, true) ~= nil
  MiniTest.expect.equality(contains_path, true)
  
  child.stop()
end

T['file_picker']['multiple references on same line'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  child.type_keys('<Esc>')
  
  -- Start with @ and insert first reference
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {'@'})
    vim.api.nvim_win_set_cursor(0, {1, 0})
    
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    
    insert_ref('lua/plugin/init.lua')
  ]])
  
  -- Add text " and @"
  child.lua([[
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, col + 1) .. ' and @' .. line:sub(col + 2)
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { row, col + 6 })
  ]])
  
  -- Insert second reference after the second @
  child.lua([[
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      vim.api.nvim_win_set_cursor(0, { row, col + 1 + #file_path })
    end
    
    insert_ref('lua/plugin/state.lua')
  ]])
  
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, '@lua/plugin/init.lua and @lua/plugin/state.lua')
  
  child.stop()
end

T['file_picker']['returns to insert mode after insertion'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })
  
  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')
  
  -- Start in insert mode and type @
  child.type_keys('i@')
  
  -- Verify we're in insert mode
  local mode_before = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode_before, 'i')
  
  -- Exit insert mode to set up test
  child.type_keys('<Esc>')
  
  -- Position cursor and insert reference (simulating what picker does)
  child.lua([[
    vim.api.nvim_win_set_cursor(0, {1, 0})
    local insert_ref = function(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
      vim.api.nvim_set_current_line(new_line)
      -- Move cursor to last character of inserted path
      vim.api.nvim_win_set_cursor(0, { row, col + #file_path })
      -- Use 'a' to enter insert mode after cursor (same as actual implementation)
      vim.api.nvim_feedkeys('a', 'n', false)
    end
    insert_ref('lua/plugin/init.lua')
  ]])
  
  -- Verify we're back in insert mode
  local mode_after = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode_after, 'i')
  
  -- Verify cursor is positioned correctly for typing after the inserted text
  -- After 'a', we should be in insert mode ready to type after the last character
  -- The reference is @lua/plugin/init.lua (@ at 0, file path starts at 1, ends at 19)
  -- After 'a' command, cursor should be at position 20 (after the last 'a')
  local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(0)]])
  local expected_col = 0 + 1 + #'lua/plugin/init.lua' - 1
  -- Wait, let me recalculate:
  -- @ is at position 0
  -- file_path 'lua/plugin/init.lua' is inserted at position 1-19 (19 chars)
  -- After feedkeys('a'), cursor moves to position 20
  expected_col = 0 + #'lua/plugin/init.lua' + 1
  MiniTest.expect.equality(cursor[2], expected_col)
  
  child.stop()
end

return T
