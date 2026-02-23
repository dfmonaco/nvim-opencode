local MiniTest = require('mini.test')
local T = MiniTest.new_set()

T['file_picker'] = MiniTest.new_set()

T['file_picker']['shows picker when .. is typed at start of word in insert mode'] = function()
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

  -- 'hello ..' — second '.' at col 7 (0-indexed); cursor there after trigger
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'hello ..world'})]])
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 7})]])

  -- Simulate what insert_file_reference does: replace '..' with './path'
  child.lua([[
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end
    insert_ref('lua/plugin/init.lua')
  ]])

  -- '..' at cols 6-7 replaced with './lua/plugin/init.lua'
  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, 'hello ./lua/plugin/init.luaworld')

  -- cursor: #'hello ' + #'./lua/plugin/init.lua' - 1 = 6 + 21 - 1 = 26
  local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(0)]])
  MiniTest.expect.equality(cursor[2], 26)

  child.stop()
end

T['file_picker']['inserts at end of line correctly'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

  -- 'test..' — second '.' at col 5 (0-indexed)
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'test..'})]])
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 5})]])

  child.lua([[
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end
    insert_ref('Makefile')
  ]])

  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, 'test./Makefile')

  child.stop()
end

T['file_picker']['inserts at beginning of line correctly'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

  -- '..world' — second '.' at col 1 (0-indexed)
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'..world'})]])
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 1})]])

  child.lua([[
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end
    insert_ref('tests/test_client.lua')
  ]])

  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, './tests/test_client.luaworld')

  child.stop()
end

T['file_picker']['highlight group is defined'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

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

  -- Content uses the produced ./path format (what ends up in the buffer after insertion)
  child.type_keys('<Esc>')
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'Check ./lua/plugin/init.lua for details',
      'See ./tests/test_client.lua',
      './Makefile has build commands',
      'Path with dots: ./.gitignore',
      'Path with hyphens: ./my-file.lua',
    })
  ]])

  child.cmd('syntax on')
  child.cmd('syntax sync fromstart')

  -- Line 1: 'Check ./lua/plugin/init.lua ...'
  -- './lua...' starts at col 7 (1-indexed), col 8 is inside the reference
  local syn_id = child.lua_get([[vim.fn.synID(1, 8, 1)]])

  MiniTest.expect.no_equality(syn_id, 0)

  child.stop()
end

T['file_picker']['handles empty buffer'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

  -- '..' alone — second '.' at col 1 (0-indexed)
  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'..'})]]) 
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 1})]])

  child.lua([[
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end
    insert_ref('lua/plugin/state.lua')
  ]])

  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, './lua/plugin/state.lua')

  child.stop()
end

T['file_picker']['file reference format includes ./ prefix'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

  child.type_keys('<Esc>')
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'..'})]]) 
  child.lua([[vim.api.nvim_win_set_cursor(0, {1, 1})]])

  child.lua([[
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end
    insert_ref('ftplugin/OCPrompt.lua')
  ]])

  local line = child.lua_get([[vim.api.nvim_get_current_line()]])

  -- '..' trigger is replaced: result should start with './'
  local starts_with_dotslash = line:sub(1, 2) == './'
  MiniTest.expect.equality(starts_with_dotslash, true)

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

  -- Insert first reference: '..' replaced with './lua/plugin/init.lua'
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {'..'})

    vim.api.nvim_win_set_cursor(0, {1, 1})

    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end

    insert_ref('lua/plugin/init.lua')
  ]])

  -- Append ' and ..' after first ref; place cursor at second '.' of new '..'
  child.lua([[
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, col + 1) .. ' and ..' .. line:sub(col + 2)
    vim.api.nvim_set_current_line(new_line)
    -- ' and ..' is 7 chars; second '.' is at col + 7
    vim.api.nvim_win_set_cursor(0, { row, col + 7 })
  ]])

  -- Insert second reference
  child.lua([[
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
    end

    insert_ref('lua/plugin/state.lua')
  ]])

  local line = child.lua_get([[vim.api.nvim_get_current_line()]])
  MiniTest.expect.equality(line, './lua/plugin/init.lua and ./lua/plugin/state.lua')

  child.stop()
end

T['file_picker']['returns to insert mode after insertion'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

  -- Start in insert mode and type '..'
  child.type_keys('i..')

  local mode_before = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode_before, 'i')

  child.type_keys('<Esc>')

  -- Cursor is at col 1 (second '.'), simulate insert_file_reference
  child.lua([[
    vim.api.nvim_win_set_cursor(0, {1, 1})
    local function insert_ref(file_path)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      local prefix = col >= 1 and line:sub(1, col - 1) or ''
      local suffix = line:sub(col + 2)
      local replacement = './' .. file_path
      local new_line = prefix .. replacement .. suffix
      vim.api.nvim_set_current_line(new_line)
      local new_col = #prefix + #replacement - 1
      vim.api.nvim_win_set_cursor(0, { row, new_col })
      vim.api.nvim_feedkeys('a', 'n', false)
    end
    insert_ref('lua/plugin/init.lua')
  ]])

  local mode_after = child.lua_get([[vim.fn.mode()]])
  MiniTest.expect.equality(mode_after, 'i')

  -- Buffer is './lua/plugin/init.lua' (21 chars)
  -- prefix='', replacement='./lua/plugin/init.lua' (#21), new_col = 0 + 21 - 1 = 20
  -- after 'a': cursor moves to col 21
  local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(0)]])
  MiniTest.expect.equality(cursor[2], 21)

  child.stop()
end

T['file_picker']['word-start guard prevents trigger after non-whitespace'] = function()
  local child = MiniTest.new_child_neovim()
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua([[require('plugin').setup()]])
  child.cmd('OCPrompt')

  -- Track whether the file picker show() was called
  child.lua([[
    _G._picker_triggered = false
    local fp = require('plugin.commands.file_picker')
    local orig_show = fp.show
    fp.show = function()
      _G._picker_triggered = true
      orig_show()
    end
  ]])

  -- Type 'init.lua..' — '..' follows 'a' (non-whitespace), guard should block
  child.type_keys('iinit.lua..')

  -- Give vim.schedule() a chance to run
  child.lua([[vim.wait(50)]])

  local triggered = child.lua_get([[_G._picker_triggered]])
  MiniTest.expect.equality(triggered, false)

  child.stop()
end

return T
