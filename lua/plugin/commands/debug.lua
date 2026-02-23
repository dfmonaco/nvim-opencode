local M = {}

---Collect a snapshot of all plugin state and SSE connection state, then paste
---it as lines into the current buffer at the cursor position.
---Useful for live troubleshooting without leaving Neovim.
function M.paste_state()
  local State = require('plugin.state')
  local Sse = require('plugin.sse')

  local sse = Sse.get_state()

  local lines = {
    '-- OCDebugState ' .. os.date('%Y-%m-%d %H:%M:%S'),
    '',
    '-- plugin.state',
    '  port         = ' .. tostring(State.get_port()),
    '  session_id   = ' .. tostring(State.get_session_id()),
    '  project_root = ' .. tostring(State.get_project_root()),
    '  terminal_buf = ' .. tostring(State.get_terminal_buffer()),
    '  terminal_win = ' .. tostring(State.get_terminal_win()),
    '',
    '-- plugin.sse (connection)',
    '  connected    = ' .. tostring(sse.connected),
    '  port         = ' .. tostring(sse.port),
    '  directory    = ' .. tostring(sse.directory),
    '  job_id       = ' .. tostring(sse.job_id),
    '  line_buffer  = ' .. string.format('%q', sse.line_buffer or ''),
    '  subscribers  = ' .. tostring(#sse.subscribers),
  }

  -- Append subscriber details
  for i, sub in ipairs(sse.subscribers) do
    table.insert(lines, string.format('    [%d] id=%s pattern=%s', i, tostring(sub.id), tostring(sub.pattern)))
  end

  -- Insert into current buffer at cursor
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)

  vim.notify('OCDebugState pasted at line ' .. row, vim.log.levels.INFO, { title = 'OpenCode debug' })
end

return M
