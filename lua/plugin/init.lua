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

  -- Register OCTuiCmd command (generic TUI command executor)
  vim.api.nvim_create_user_command('OCTuiCmd', function(cmd_opts)
    require('plugin.commands.tui').execute(cmd_opts.args)
  end, { desc = 'Execute a named TUI command (e.g. session.interrupt, session.new)', nargs = 1 })

  require('plugin.keymaps').setup(opts)
  require('plugin.autocmds').setup(opts)
end

return M
