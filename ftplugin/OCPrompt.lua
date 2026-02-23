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

-- File reference picker trigger: @ in insert mode
vim.api.nvim_create_autocmd('InsertCharPre', {
  buffer = 0,
  callback = function()
    if vim.v.char == '@' then
      -- Schedule to avoid interfering with character insertion
      vim.schedule(function()
        require('plugin.commands.file_picker').show()
      end)
    end
  end,
  desc = 'Trigger file picker when @ is typed in insert mode'
})

-- Highlight group for file references
vim.api.nvim_set_hl(0, 'OCFileReference', {
  link = 'Special',  -- Links to built-in Special highlight
  default = true,     -- Allows users to override
})
