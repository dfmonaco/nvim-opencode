local M = {}

---@class PluginConfig
---@field enabled boolean

---Setup function: registers plugin commands
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- Register OC command
  vim.api.nvim_create_user_command('OC', function()
    require('plugin.commands.terminal').toggle()
  end, { desc = 'Toggle terminal (vertical right split)' })

  -- Map <leader>O to execute :OC command (normal mode)
  vim.keymap.set('n', '<leader>O', '<cmd>OC<cr>', {
    desc = 'Toggle terminal (vertical right split)',
    noremap = true,
    silent = true,
  })

  -- Register OCPrompt command
  vim.api.nvim_create_user_command('OCPrompt', function()
    require('plugin.commands.prompt').open()
  end, { desc = 'Open/focus OCPrompt buffer in this window' })

  -- Map <leader>Op to execute :OCPrompt command (normal mode)
  vim.keymap.set('n', '<leader>Op', '<cmd>OCPrompt<cr>', {
    desc = 'Open/focus OCPrompt buffer in this window',
    noremap = true,
    silent = true,
  })

  -- Register OCSend command
  vim.api.nvim_create_user_command('OCSend', function(cmd_opts)
    require('plugin.commands.send_buffer').send()
  end, { desc = 'Send current buffer (or visual selection) to OpenCode session', range = true })

  -- Map <leader>Os to execute :OCSend command (normal and visual modes)
  vim.keymap.set({ 'n', 'v' }, '<leader>Os', '<cmd>OCSend<cr>', {
    desc = 'Send current buffer (or visual selection) to OpenCode session',
    noremap = true,
    silent = true,
  })

  -- React to OpenCode server-sent events via the User OpenCodeEvent autocmd.
  -- This is the central place for all event-driven notifications and side effects.
  -- Other modules and user config can register additional handlers on the same autocmd.
  vim.api.nvim_create_autocmd('User', {
    pattern = 'OpenCodeEvent',
    desc = 'Handle OpenCode SSE events',
    callback = function(ev)
      local event = ev.data
      if type(event) ~= 'table' then
        return
      end

      if event.type == 'session.idle' then
        vim.notify('Agent Finished', vim.log.levels.INFO, { title = 'opencode' })
      end
    end,
  })
end

return M
