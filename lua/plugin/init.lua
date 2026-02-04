local M = {}

---@class PluginConfig
---@field enabled boolean

---Setup function: registers plugin commands
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- Register OC command
  vim.api.nvim_create_user_command('OC', function()
    require('plugin.commands.toggle_terminal')()
  end, { desc = 'Toggle terminal (vertical right split)' })

  -- Map <leader>O to execute :OC command (normal mode)
  vim.keymap.set('n', '<leader>O', '<cmd>OC<cr>', {
    desc = 'Toggle terminal (vertical right split)',
    noremap = true,
    silent = true,
  })

  -- Register OCPrompt command
  vim.api.nvim_create_user_command('OCPrompt', function()
    require('plugin.commands.prompt').toggle_prompt()
  end, { desc = 'Open/focus OCPrompt buffer in this window' })

  -- Map <leader>Op to execute :OCPrompt command (normal mode)
  vim.keymap.set('n', '<leader>Op', '<cmd>OCPrompt<cr>', {
    desc = 'Open/focus OCPrompt buffer in this window',
    noremap = true,
    silent = true,
  })
end

return M
