local M = {}

---@class PluginConfig
---@field enabled boolean

---Setup function: registers plugin commands, keymaps, and autocommands
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- Register OC command
  vim.api.nvim_create_user_command('OC', function()
    require('plugin.commands.terminal').toggle()
  end, { desc = 'Toggle terminal (vertical right split)' })

  -- Register OCPrompt command
  vim.api.nvim_create_user_command('OCPrompt', function()
    require('plugin.commands.prompt').open()
  end, { desc = 'Open/focus OCPrompt buffer in this window' })

  -- Register OCSend command
  vim.api.nvim_create_user_command('OCSend', function(_)
    require('plugin.commands.send_buffer').send()
  end, { desc = 'Send current buffer (or visual selection) to OpenCode session', range = true })

  -- Register OCTuiAppend command
  vim.api.nvim_create_user_command('OCTuiAppend', function()
    require('plugin.commands.tui').append()
  end, { desc = 'Append current buffer or visual selection to the TUI prompt', range = true })

  -- Register OCTuiSend command (append + auto-submit)
  vim.api.nvim_create_user_command('OCTuiSend', function()
    require('plugin.commands.tui').append_and_submit()
  end, { desc = 'Append current buffer or visual selection to TUI prompt and submit', range = true })

  -- Register OCInterrupt command
  vim.api.nvim_create_user_command('OCInterrupt', function()
    require('plugin.commands.tui').interrupt()
  end, { desc = 'Interrupt the current OpenCode AI run' })

  -- Register OCNewSession command
  vim.api.nvim_create_user_command('OCNewSession', function()
    require('plugin.commands.tui').new_session()
  end, { desc = 'Start a new OpenCode session' })

  -- Register OCHalfPageDown command
  vim.api.nvim_create_user_command('OCHalfPageDown', function()
    require('plugin.commands.tui').execute('session.half.page.down')
  end, { desc = 'Scroll TUI half page down' })

  -- Register OCHalfPageUp command
  vim.api.nvim_create_user_command('OCHalfPageUp', function()
    require('plugin.commands.tui').execute('session.half.page.up')
  end, { desc = 'Scroll TUI half page up' })

  -- Register OCCompact command
  vim.api.nvim_create_user_command('OCCompact', function()
    require('plugin.commands.tui').execute('session.compact')
  end, { desc = 'Compact the current OpenCode session' })

  -- Register OCAgentCycle command
  vim.api.nvim_create_user_command('OCAgentCycle', function()
    require('plugin.commands.tui').execute('agent.cycle')
  end, { desc = 'Cycle to the next OpenCode agent' })

  require('plugin.keymaps').setup(opts)
  require('plugin.autocmds').setup(opts)
end

return M
