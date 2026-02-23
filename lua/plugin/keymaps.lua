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

  -- Submit the TUI prompt
  vim.keymap.set('n', '<leader>ops', '<cmd>OCPromptSubmit<cr>', {
    desc = 'Submit the TUI prompt',
    noremap = true,
    silent = true,
  })

  -- Clear the TUI prompt
  vim.keymap.set('n', '<leader>opc', '<cmd>OCPromptClear<cr>', {
    desc = 'Clear the TUI prompt',
    noremap = true,
    silent = true,
  })

  -- Paste into the TUI prompt
  vim.keymap.set('n', '<leader>opp', '<cmd>OCPromptPaste<cr>', {
    desc = 'Paste into the TUI prompt',
    noremap = true,
    silent = true,
  })

  -- Cycle to next favorite model
  vim.keymap.set('n', '<leader>oam', '<cmd>OCModelCycleFavorite<cr>', {
    desc = 'Cycle to next favorite model',
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

  -- Undo last session action
  vim.keymap.set('n', '<leader>osu', '<cmd>OCUndo<cr>', {
    desc = 'Undo last session action',
    noremap = true,
    silent = true,
  })

  -- Redo last session action
  vim.keymap.set('n', '<leader>osr', '<cmd>OCRedo<cr>', {
    desc = 'Redo last session action',
    noremap = true,
    silent = true,
  })

  -- Jump to first message in session
  vim.keymap.set('n', '<leader>osf', '<cmd>OCFirst<cr>', {
    desc = 'Jump to first message in session',
    noremap = true,
    silent = true,
  })

  -- Jump to last message in session
  vim.keymap.set('n', '<leader>osl', '<cmd>OCLast<cr>', {
    desc = 'Jump to last message in session',
    noremap = true,
    silent = true,
  })

  -- Jump to last user message in session
  vim.keymap.set('n', '<leader>osU', '<cmd>OCLastUser<cr>', {
    desc = 'Jump to last user message in session',
    noremap = true,
    silent = true,
  })

  -- Go to next child session
  vim.keymap.set('n', '<leader>osj', '<cmd>OCChildNext<cr>', {
    desc = 'Go to next child session',
    noremap = true,
    silent = true,
  })

  -- Go to previous child session
  vim.keymap.set('n', '<leader>osk', '<cmd>OCChildPrev<cr>', {
    desc = 'Go to previous child session',
    noremap = true,
    silent = true,
  })

  -- Add current file reference to OCPrompt (normal mode)
  vim.keymap.set('n', '<leader>oca', '<cmd>OCContextFile<cr>', {
    desc = 'Append current file reference to OCPrompt',
    noremap = true,
    silent = true,
  })

  -- Add visual selection reference to OCPrompt (visual mode)
  vim.keymap.set('v', '<leader>oca', '<Esc><cmd>OCContextVisual<cr>', {
    desc = 'Append current file + visual selection range to OCPrompt',
    noremap = true,
    silent = true,
  })

  -- Add current buffer diagnostics to OCPrompt
  vim.keymap.set('n', '<leader>ocd', '<cmd>OCContextDiagnostics<cr>', {
    desc = 'Append current buffer diagnostics to OCPrompt',
    noremap = true,
    silent = true,
  })

  -- Add all open buffer references to OCPrompt
  vim.keymap.set('n', '<leader>ocb', '<cmd>OCContextBuffers<cr>', {
    desc = 'Append all open buffer references to OCPrompt',
    noremap = true,
    silent = true,
  })

  -- Register which-key group labels if which-key v3 is available
  local ok, wk = pcall(require, 'which-key')
  if ok then
    local i = function(n) return vim.fn.nr2char(n, true) end
    wk.add({
      { '<leader>o',  group = 'opencode', icon = { icon = i(0xf489),  color = 'cyan'   } }, -- nf-dev-terminal
      { '<leader>op', group = 'prompt',   icon = { icon = i(0xf27a),  color = 'green'  } }, -- nf-fa-comment_o
      { '<leader>os', group = 'session',  icon = { icon = i(0xf4d9),  color = 'blue'   } }, -- nf-oct-history
      { '<leader>oa', group = 'agent',    icon = { icon = i(0xf082a), color = 'yellow' } }, -- nf-md-robot
      { '<leader>oc', group = 'context',  icon = { icon = i(0xf0c5),  color = 'purple' } }, -- nf-fa-files_o
    })
  end
end

return M
