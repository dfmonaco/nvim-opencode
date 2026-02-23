---@module 'plugin.commands.file_picker'
local Notify = require('plugin.notify')
local M = {}

---Gets git root directory for current buffer
---@param callback fun(git_root: string|nil)
local function get_git_root(callback)
  vim.system(
    { 'git', 'rev-parse', '--show-toplevel' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 and result.stdout then
        local git_root = vim.trim(result.stdout)
        callback(git_root)
      else
        callback(nil)
      end
    end)
  )
end

---Gets list of git tracked files
---@param git_root string
---@param callback fun(files: string[]|nil)
local function get_git_files(git_root, callback)
  vim.system(
    { 'git', 'ls-files', '--full-name' },
    { cwd = git_root, text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 and result.stdout then
        local files = {}
        for line in vim.gsplit(result.stdout, '\n', { plain = true, trimempty = true }) do
          table.insert(files, line)
        end
        callback(files)
      else
        callback(nil)
      end
    end)
  )
end

---Inserts file reference at cursor position, replacing the '..' trigger.
---The '..' characters are already in the buffer (user just typed them).
---They are replaced with './path/to/file' so the buffer always contains
---the canonical relative path format understood by the agent.
---@param file_path string Relative path to insert
local function insert_file_reference(file_path)
  -- In insert mode, after '..' is typed, cursor is positioned after the second '.'
  -- col is 0-indexed; second '.' is at col, first '.' is at col-1
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  -- Replace the two '..' chars with './' .. file_path
  -- Everything before the first '.': line:sub(1, col-1)  (col-1 chars, Lua 1-indexed)
  local prefix = col >= 1 and line:sub(1, col - 1) or ''
  local suffix = line:sub(col + 2) -- everything after the second '.'
  local replacement = './' .. file_path
  local new_line = prefix .. replacement .. suffix

  vim.api.nvim_set_current_line(new_line)

  -- Place cursor at the last character of the replacement
  local new_col = #prefix + #replacement - 1
  vim.api.nvim_win_set_cursor(0, { row, new_col })

  -- Use 'a' (append) to re-enter insert mode after the last inserted character
  vim.api.nvim_feedkeys('a', 'n', false)
end

---Shows file picker and inserts selected file reference at cursor,
---replacing the '..' trigger with './path/to/file'.
---@return nil
function M.show()
  -- Get git root first
  get_git_root(function(git_root)
    if not git_root then
      -- Not in a git repository - silently no-op
      return
    end
    
    -- Get git tracked files
    get_git_files(git_root, function(files)
      if not files or #files == 0 then
        Notify.warn('No git tracked files found')
        return
      end
      
      -- Present picker to user
      vim.ui.select(files, {
        prompt = 'Select file to reference:',
        format_item = function(item)
          return item
        end,
      }, function(selected)
        if selected then
          -- Insert file reference at cursor
          insert_file_reference(selected)
        end
        -- If cancelled (selected == nil), do nothing
      end)
    end)
  end)
end

return M
