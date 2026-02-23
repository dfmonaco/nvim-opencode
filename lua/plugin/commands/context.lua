---@module 'plugin.commands.context'
---Commands for appending context references to the OCPrompt buffer.
---All functions append to the end of the OCPrompt buffer, separated from
---existing content by a blank line.

local Notify = require('plugin.notify')
local State = require('plugin.state')

local M = {}

-- ============================================================================
-- Helpers
-- ============================================================================

---Returns true if the buffer is a valid normal file buffer.
---@param bufnr integer
---@return boolean
local function is_buf_valid(bufnr)
  return vim.api.nvim_buf_is_loaded(bufnr)
    and vim.api.nvim_get_option_value('buftype', { buf = bufnr }) == ''
    and vim.api.nvim_buf_get_name(bufnr) ~= ''
end

---Validates the given buffer for use as a context source.
---Returns the cwd-relative path on success, or nil + error message on failure.
---@param bufnr integer
---@return string|nil relative_path, string|nil err
local function validate_buf(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return nil, 'Cannot add context from unnamed buffer. Save the file first.'
  end

  local buftype = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
  if buftype ~= '' then
    return nil, string.format('Cannot add context from %s buffer', buftype)
  end

  if name:match('OCPrompt$') then
    return nil, 'Cannot add context from the OCPrompt buffer itself.'
  end

  local rel = vim.fn.fnamemodify(name, ':.')
  -- fnamemodify returns an absolute path when the file is outside cwd
  if rel:sub(1, 1) == '/' then
    rel = name
  end

  return rel, nil
end

---Appends lines to the OCPrompt buffer, preceded by a blank separator line
---when the buffer already has content.  Opens OCPrompt if it is not yet open.
---@param lines string[]
local function append_to_prompt(lines)
  -- Ensure OCPrompt buffer exists
  local buf = State.get_ocprompt_buffer()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = require('plugin.commands.prompt').open()
  end

  -- Current content
  local existing = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local has_content = #existing > 0 and not (#existing == 1 and existing[1] == '')

  local to_insert = {}
  if has_content then
    table.insert(to_insert, '') -- blank separator
  end
  for _, line in ipairs(lines) do
    table.insert(to_insert, line)
  end

  -- Append at end
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, to_insert)
end

-- ============================================================================
-- Public commands
-- ============================================================================

---Append a reference to the current buffer to the OCPrompt buffer.
---Format: @relative/path/to/file
---@return nil
function M.add_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local rel, err = validate_buf(bufnr)
  if not rel then
    Notify.warn(err or 'Cannot add context from this buffer.')
    return
  end

  append_to_prompt({ '@' .. rel })
  Notify.info('Added file reference: @' .. rel)
end

---Append a reference to the current buffer with the last visual selection's
---line range to the OCPrompt buffer.
---Format: @relative/path/to/file#Lstart-Lend
---@return nil
function M.add_visual()
  local bufnr = vim.api.nvim_get_current_buf()
  local rel, err = validate_buf(bufnr)
  if not rel then
    Notify.warn(err or 'Cannot add context from this buffer.')
    return
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 then
    Notify.warn('No visual selection found. Make a selection first.')
    return
  end

  -- Normalise backward selections
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local ref
  if start_line == end_line then
    ref = '@' .. rel .. '#L' .. start_line
  else
    ref = '@' .. rel .. '#L' .. start_line .. '-L' .. end_line
  end

  append_to_prompt({ ref })
  Notify.info('Added visual reference: ' .. ref)
end

---Append LSP diagnostics for the current buffer to the OCPrompt buffer.
---Produces one line per diagnostic in the format:
---  @path#Lrow:Ccol [severity] message
---@return nil
function M.add_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local rel, err = validate_buf(bufnr)
  if not rel then
    Notify.warn(err or 'Cannot add context from this buffer.')
    return
  end

  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    Notify.info('No diagnostics found in current buffer.')
    return
  end

  ---@type string[]
  local lines = {}
  local severity_labels = { 'ERROR', 'WARN', 'INFO', 'HINT' }

  table.insert(lines, #diagnostics .. ' diagnostic(s) in @' .. rel .. ':')

  for _, d in ipairs(diagnostics) do
    local location = string.format('#L%d:C%d', d.lnum + 1, d.col + 1)
    local severity = severity_labels[d.severity] or 'UNKNOWN'
    local msg = d.message:gsub('%s+', ' '):gsub('^%s', ''):gsub('%s$', '')
    local source = d.source and (' (' .. d.source .. ')') or ''
    table.insert(lines, string.format('  @%s%s [%s]%s: %s', rel, location, severity, source, msg))
  end

  append_to_prompt(lines)
  Notify.info(string.format('Added %d diagnostic(s) from @%s', #diagnostics, rel))
end

---Append references for all open normal file buffers to the OCPrompt buffer.
---One line per buffer: @relative/path/to/file
---@return nil
function M.add_buffers()
  local refs = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if is_buf_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if not name:match('OCPrompt$') then
        local rel = vim.fn.fnamemodify(name, ':.')
        if rel:sub(1, 1) == '/' then
          rel = name
        end
        table.insert(refs, '@' .. rel)
      end
    end
  end

  if #refs == 0 then
    Notify.warn('No open file buffers found.')
    return
  end

  append_to_prompt(refs)
  Notify.info(string.format('Added %d buffer reference(s) to OCPrompt', #refs))
end

return M
