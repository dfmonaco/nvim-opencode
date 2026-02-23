local M = {}

---Register all plugin keymaps
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- Toggle terminal
  vim.keymap.set('n', '<leader>O', '<cmd>OC<cr>', {
    desc = 'Toggle terminal (vertical right split)',
    noremap = true,
    silent = true,
  })

  -- Open/focus prompt buffer
  vim.keymap.set('n', '<leader>Op', '<cmd>OCPrompt<cr>', {
    desc = 'Open/focus OCPrompt buffer in this window',
    noremap = true,
    silent = true,
  })

  -- Send buffer or selection to session
  vim.keymap.set({ 'n', 'v' }, '<leader>Os', '<cmd>OCSend<cr>', {
    desc = 'Send current buffer (or visual selection) to OpenCode session',
    noremap = true,
    silent = true,
  })

  -- Append buffer or selection to TUI prompt
  vim.keymap.set({ 'n', 'v' }, '<leader>Oa', '<cmd>OCTuiAppend<cr>', {
    desc = 'Append current buffer or visual selection to the TUI prompt',
    noremap = true,
    silent = true,
  })

  -- Append buffer or selection to TUI prompt and submit
  vim.keymap.set({ 'n', 'v' }, '<leader>OS', '<cmd>OCTuiSend<cr>', {
    desc = 'Append current buffer or visual selection to TUI prompt and submit',
    noremap = true,
    silent = true,
  })

  -- Interrupt the current AI run
  vim.keymap.set('n', '<leader>Oi', '<cmd>OCTuiCmd session.interrupt<cr>', {
    desc = 'Interrupt the current OpenCode AI run',
    noremap = true,
    silent = true,
  })

  -- Start a new session
  vim.keymap.set('n', '<leader>On', '<cmd>OCTuiCmd session.new<cr>', {
    desc = 'Start a new OpenCode session',
    noremap = true,
    silent = true,
  })
end

return M
