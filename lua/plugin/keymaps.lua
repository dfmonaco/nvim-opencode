local M = {}

local function keymap(mode, lhs, rhs, opts)
  local defaults = { noremap = true, silent = true }
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', defaults, opts or {}))
end

---Register all plugin keymaps
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}

  -- =============================================================================
  -- Core
  -- =============================================================================

  keymap('n', '<leader>oo', '<cmd>OC<cr>', {
    desc = 'Toggle terminal (vertical right split)',
  })

  keymap('n', '<C-Space>', '<cmd>OCPrompt<cr>', {
    desc = 'Open/focus OCPrompt buffer in this window',
  })

  keymap('n', '<leader>oi', '<cmd>OCInterrupt<cr>', {
    desc = 'Interrupt the current OpenCode AI run',
  })

  keymap('n', '<leader>o/', '<cmd>OCSlashCommand<cr>', {
    desc = 'Pick and execute a slash command in the current session',
  })

  -- =============================================================================
  -- Agent
  -- =============================================================================

  keymap('n', '<C-\\>', '<cmd>OCAgentCycle<cr>', {
    desc = 'Cycle to the next OpenCode agent',
  })

  keymap('n', '<C-m>', '<cmd>OCModelCycleFavorite<cr>', {
    desc = 'Cycle to next favorite model',
  })

  keymap('n', '<leader>oas', '<cmd>OCSkillPick<cr>', {
    desc = 'Pick a skill and open its definition file',
  })

  -- =============================================================================
  -- TUI / Prompt
  -- =============================================================================

  keymap('n', '<Down>', '<cmd>OCHalfPageDown<cr>', {
    desc = 'Scroll OpenCode TUI half page down',
  })

  keymap('n', '<Up>', '<cmd>OCHalfPageUp<cr>', {
    desc = 'Scroll OpenCode TUI half page up',
  })

  -- Send to prompt

  keymap({ 'n', 'v' }, '<leader>om', '<cmd>OCSend<cr>', {
    desc = 'Send current buffer (or visual selection) to OpenCode session',
  })

  keymap({ 'n', 'v' }, '<leader>opa', '<cmd>OCTuiAppend<cr>', {
    desc = 'Append current buffer or visual selection to the TUI prompt',
  })

  keymap({ 'n', 'v' }, '<leader>opm', '<cmd>OCTuiSend<cr>', {
    desc = 'Append current buffer or visual selection to TUI prompt and submit',
  })

  -- Prompt actions

  keymap('n', '<leader>ops', '<cmd>OCPromptSubmit<cr>', {
    desc = 'Submit the TUI prompt',
  })

  keymap('n', '<leader>opc', '<cmd>OCPromptClear<cr>', {
    desc = 'Clear the TUI prompt',
  })

  keymap('n', '<leader>opp', '<cmd>OCPromptPaste<cr>', {
    desc = 'Paste into the TUI prompt',
  })

  -- =============================================================================
  -- Session
  -- =============================================================================

  keymap('n', '<leader>osn', '<cmd>OCNewSession<cr>', {
    desc = 'Start a new OpenCode session',
  })

  keymap('n', '<leader>oss', '<cmd>OCSessionPick<cr>', {
    desc = 'Pick a session and navigate the TUI to it',
  })

  keymap('n', '<leader>osc', '<cmd>OCCompact<cr>', {
    desc = 'Compact the current OpenCode session',
  })

  -- History navigation

  keymap('n', '<leader>osu', '<cmd>OCUndo<cr>', {
    desc = 'Undo last session action',
  })

  keymap('n', '<leader>osr', '<cmd>OCRedo<cr>', {
    desc = 'Redo last session action',
  })

  keymap('n', '<leader>osf', '<cmd>OCFirst<cr>', {
    desc = 'Jump to first message in session',
  })

  keymap('n', '<leader>osl', '<cmd>OCLast<cr>', {
    desc = 'Jump to last message in session',
  })

  keymap('n', '<leader>osm', '<cmd>OCLastUser<cr>', {
    desc = 'Jump to last user message in session',
  })

  -- Child session navigation

  keymap('n', '<leader>osj', '<cmd>OCChildNext<cr>', {
    desc = 'Go to next child session',
  })

  keymap('n', '<leader>osk', '<cmd>OCChildPrev<cr>', {
    desc = 'Go to previous child session',
  })

  -- =============================================================================
  -- Context
  -- =============================================================================

  keymap('n', '<leader>oca', '<cmd>OCContextFile<cr>', {
    desc = 'Append current file reference to OCPrompt',
  })

  keymap('v', '<leader>oca', '<Esc><cmd>OCContextVisual<cr>', {
    desc = 'Append current file + visual selection range to OCPrompt',
  })

  keymap('n', '<leader>ocd', '<cmd>OCContextDiagnostics<cr>', {
    desc = 'Append current buffer diagnostics to OCPrompt',
  })

  keymap('n', '<leader>ocb', '<cmd>OCContextBuffers<cr>', {
    desc = 'Append all open buffer references to OCPrompt',
  })

  -- =============================================================================
  -- Which-key groups
  -- =============================================================================

  local ok, wk = pcall(require, 'which-key')
  if ok then
    local i = function(n) return vim.fn.nr2char(n, true) end
    wk.add({
      { '<leader>o',  group = 'opencode', icon = { icon = i(0xf489),  color = 'cyan'   } }, -- nf-dev-terminal
      { '<leader>op', group = 'prompt',   icon = { icon = i(0xf27a),  color = 'green'  } }, -- nf-fa-comment_o
      { '<leader>os', group = 'session',  icon = { icon = i(0xf4d9),  color = 'blue'   } }, -- nf-oct-history
      { '<leader>oa', group = 'agent',    icon = { icon = i(0xf082a), color = 'yellow' } }, -- nf-md-robot
      { '<leader>oc', group = 'context',  icon = { icon = i(0xf5c1),  color = 'purple' } }, -- nf-fa-files_o
    })
  end
end

return M
