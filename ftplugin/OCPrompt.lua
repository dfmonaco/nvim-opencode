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

-- Buffer-local <C-CR> to send OCPrompt buffer contents (works in both Normal and Insert modes)
vim.keymap.set({'n', 'i'}, '<C-CR>', function()
  require('plugin.commands.send_buffer').send()
end, { buffer = true, desc = 'Send OCPrompt buffer to OpenCode session' })
