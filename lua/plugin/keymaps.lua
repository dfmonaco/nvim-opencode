local M = {}

---Register all plugin keymaps
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- Toggle terminal
  vim.keymap.set('n', '<leader>oo', '<cmd>OC<cr>', {
    desc = 'Toggle terminal (vertical right split)',
    noremap = true,
    silent = true,
  })

  -- Open/focus prompt buffer
  vim.keymap.set('n', '<C-Space>', '<cmd>OCPrompt<cr>', {
    desc = 'Open/focus OCPrompt buffer in this window',
    noremap = true,
    silent = true,
  })

  -- Scroll TUI half page down
  vim.keymap.set('n', '<Down>', '<cmd>OCHalfPageDown<cr>', {
    desc = 'Scroll OpenCode TUI half page down',
    noremap = true,
    silent = true,
  })

  -- Scroll TUI half page up
  vim.keymap.set('n', '<Up>', '<cmd>OCHalfPageUp<cr>', {
    desc = 'Scroll OpenCode TUI half page up',
    noremap = true,
    silent = true,
  })

  -- Cycle to the next agent
  vim.keymap.set('n', '<C-\\>', '<cmd>OCAgentCycle<cr>', {
    desc = 'Cycle to the next OpenCode agent',
    noremap = true,
    silent = true,
  })

  -- Send buffer or selection to session
  vim.keymap.set({ 'n', 'v' }, '<leader>om', '<cmd>OCSend<cr>', {
    desc = 'Send current buffer (or visual selection) to OpenCode session',
    noremap = true,
    silent = true,
  })

  -- Append buffer or selection to TUI prompt
  vim.keymap.set({ 'n', 'v' }, '<leader>opa', '<cmd>OCTuiAppend<cr>', {
    desc = 'Append current buffer or visual selection to the TUI prompt',
    noremap = true,
    silent = true,
  })

  -- Append buffer or selection to TUI prompt and submit
  vim.keymap.set({ 'n', 'v' }, '<leader>opm', '<cmd>OCTuiSend<cr>', {
    desc = 'Append current buffer or visual selection to TUI prompt and submit',
    noremap = true,
    silent = true,
  })

  -- Interrupt the current AI run
  vim.keymap.set('n', '<leader>osi', '<cmd>OCInterrupt<cr>', {
    desc = 'Interrupt the current OpenCode AI run',
    noremap = true,
    silent = true,
  })

  -- Start a new session
  vim.keymap.set('n', '<leader>osn', '<cmd>OCNewSession<cr>', {
    desc = 'Start a new OpenCode session',
    noremap = true,
    silent = true,
  })

  -- Compact the current session
  vim.keymap.set('n', '<leader>osc', '<cmd>OCCompact<cr>', {
    desc = 'Compact the current OpenCode session',
    noremap = true,
    silent = true,
  })

end

return M
