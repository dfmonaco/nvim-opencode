-- ftplugin for OCPrompt: buffer-local options and keymaps

--
-- OCPrompt buffer-local options (scoped only to this buffer)
-- (do not put buftype and filetype here, they are set at creation)
--
vim.opt_local.buflisted = true
vim.opt_local.bufhidden  = 'hide'
vim.opt_local.swapfile   = false
vim.opt_local.spellcapcheck = ''

-- Window-local options for OCPrompt buffers
-- Use vim.schedule to ensure buffer is properly loaded before setting window options
vim.schedule(function()
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_option_value('number', false, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('relativenumber', false, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('wrap', true, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('linebreak', true, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('breakindent', true, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('spell', true, { scope = 'local', win = win })
end)

-- Buffer-local <C-x> to clear OCPrompt contents (works in both Normal and Insert modes)
vim.keymap.set({'n', 'i'}, '<C-x>', function()
  require('plugin.commands.prompt').clear()
  -- Only re-enter insert mode if we were in insert mode
  if vim.fn.mode() == 'i' then
    vim.cmd('startinsert')
  end
end, { buffer = true, desc = 'Clear OCPrompt buffer' })

-- Buffer-local <C-CR> to append OCPrompt buffer contents to TUI prompt and submit
vim.keymap.set({'n', 'i'}, '<C-CR>', function()
  local prompt = require('plugin.commands.prompt')
  require('plugin.commands.tui').append_and_submit(function()
    prompt.clear()
  end)
end, { buffer = true, desc = 'Send OCPrompt buffer to TUI prompt and submit' })

-- File reference picker trigger: .. in insert mode
-- Fires when the second '.' is typed, forming '..', but only when preceded
-- by whitespace or start-of-line. This prevents accidental triggers in prose
-- like "init.lua.." or "...".
-- On selection the '..' is replaced with './path/to/file' so the buffer always
-- contains the canonical relative-path format understood by the agent.
vim.api.nvim_create_autocmd('InsertCharPre', {
  buffer = 0,
  callback = function()
    if vim.v.char == '.' then
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local line = vim.api.nvim_get_current_line()
      -- col is 0-indexed; the char already at the cursor position is line:sub(col, col)
      local char_before = col > 0 and line:sub(col, col) or ''
      if char_before == '.' then
        -- guard: the character before the first '.' must be whitespace or non-existent
        local char_before_dot = col > 1 and line:sub(col - 1, col - 1) or ''
        local at_word_start = col <= 1 or char_before_dot:match('%s') ~= nil
        if at_word_start then
          -- Schedule to avoid interfering with character insertion
          vim.schedule(function()
            require('plugin.commands.file_picker').show()
          end)
        end
      end
    end
  end,
  desc = 'Trigger file picker when .. is typed at start of word in insert mode'
})

-- Highlight group for file references
vim.api.nvim_set_hl(0, 'OCFileReference', {
  link = 'Special',  -- Links to built-in Special highlight
  default = true,     -- Allows users to override
})
