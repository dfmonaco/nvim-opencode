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

  -- Register OCSessionPick command
  vim.api.nvim_create_user_command('OCSessionPick', function()
    require('plugin.commands.session_picker').pick()
  end, { desc = 'Pick a session from the list and navigate the TUI to it' })

  -- Register OCSkillPick command
  vim.api.nvim_create_user_command('OCSkillPick', function()
    require('plugin.commands.skill_picker').pick()
  end, { desc = 'Pick a skill and open its definition file' })

  -- Register OCHalfPageDown command
  vim.api.nvim_create_user_command('OCHalfPageDown', function()
    require('plugin.commands.tui').execute('session.half.page.down', { silent = true })
  end, { desc = 'Scroll TUI half page down' })

  -- Register OCHalfPageUp command
  vim.api.nvim_create_user_command('OCHalfPageUp', function()
    require('plugin.commands.tui').execute('session.half.page.up', { silent = true })
  end, { desc = 'Scroll TUI half page up' })

  -- Register OCCompact command
  vim.api.nvim_create_user_command('OCCompact', function()
    require('plugin.commands.tui').execute('session.compact')
  end, { desc = 'Compact the current OpenCode session' })

  -- Register OCUndo command
  vim.api.nvim_create_user_command('OCUndo', function()
    require('plugin.commands.tui').execute('session.undo', { silent = true })
  end, { desc = 'Undo last session action' })

  -- Register OCRedo command
  vim.api.nvim_create_user_command('OCRedo', function()
    require('plugin.commands.tui').execute('session.redo', { silent = true })
  end, { desc = 'Redo last session action' })

  -- Register OCFirst command
  vim.api.nvim_create_user_command('OCFirst', function()
    require('plugin.commands.tui').execute('session.first', { silent = true })
  end, { desc = 'Jump to first message in session' })

  -- Register OCLast command
  vim.api.nvim_create_user_command('OCLast', function()
    require('plugin.commands.tui').execute('session.last', { silent = true })
  end, { desc = 'Jump to last message in session' })

  -- Register OCLastUser command
  vim.api.nvim_create_user_command('OCLastUser', function()
    require('plugin.commands.tui').execute('session.messages_last_user', { silent = true })
  end, { desc = 'Jump to last user message in session' })

  -- Register OCChildNext command
  vim.api.nvim_create_user_command('OCChildNext', function()
    require('plugin.commands.tui').execute('session.child.next', { silent = true })
  end, { desc = 'Go to next child session' })

  -- Register OCChildPrev command
  vim.api.nvim_create_user_command('OCChildPrev', function()
    require('plugin.commands.tui').execute('session.child.previous', { silent = true })
  end, { desc = 'Go to previous child session' })

  -- Register OCPromptSubmit command
  vim.api.nvim_create_user_command('OCPromptSubmit', function()
    require('plugin.commands.tui').execute('prompt.submit', { silent = true })
  end, { desc = 'Submit the TUI prompt' })

  -- Register OCPromptClear command
  vim.api.nvim_create_user_command('OCPromptClear', function()
    require('plugin.commands.tui').execute('prompt.clear', { silent = true })
  end, { desc = 'Clear the TUI prompt' })

  -- Register OCPromptPaste command
  vim.api.nvim_create_user_command('OCPromptPaste', function()
    require('plugin.commands.tui').execute('prompt.paste', { silent = true })
  end, { desc = 'Paste into the TUI prompt' })

  -- Register OCModelCycleFavorite command
  vim.api.nvim_create_user_command('OCModelCycleFavorite', function()
    require('plugin.commands.tui').execute('model.cycle_favorite', { silent = true })
  end, { desc = 'Cycle to next favorite model' })

  -- Register OCAgentCycle command
  vim.api.nvim_create_user_command('OCAgentCycle', function()
    require('plugin.commands.tui').execute('agent.cycle')
  end, { desc = 'Cycle to the next OpenCode agent' })

  -- Register OCContextFile command
  vim.api.nvim_create_user_command('OCContextFile', function()
    require('plugin.commands.context').add_file()
  end, { desc = 'Append current buffer reference to OCPrompt' })

  -- Register OCContextVisual command
  vim.api.nvim_create_user_command('OCContextVisual', function()
    require('plugin.commands.context').add_visual()
  end, { desc = 'Append current buffer + visual selection line range to OCPrompt', range = true })

  -- Register OCContextDiagnostics command
  vim.api.nvim_create_user_command('OCContextDiagnostics', function()
    require('plugin.commands.context').add_diagnostics()
  end, { desc = 'Append current buffer diagnostics to OCPrompt' })

  -- Register OCContextBuffers command
  vim.api.nvim_create_user_command('OCContextBuffers', function()
    require('plugin.commands.context').add_buffers()
  end, { desc = 'Append all open buffer references to OCPrompt' })

  -- Register OCSlashCommand command
  vim.api.nvim_create_user_command('OCSlashCommand', function()
    require('plugin.commands.slash_command').pick()
  end, { desc = 'Pick and execute a slash command in the current session' })

  -- Register OCQuickResponse command
  vim.api.nvim_create_user_command('OCQuickResponse', function()
    require('plugin.commands.quick_response').send()
  end, { desc = 'Send a quick response to OpenCode' })

  -- Register OCDebugState command
  vim.api.nvim_create_user_command('OCDebugState', function()
    require('plugin.commands.debug').paste_state()
  end, { desc = 'Paste plugin + SSE state snapshot into current buffer for debugging' })

  require('plugin.keymaps').setup(opts)
  require('plugin.autocmds').setup(opts)
end

return M
