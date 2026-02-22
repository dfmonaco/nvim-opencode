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

---Inserts file reference at cursor position
---The @ character is already in the buffer (user just typed it),
---so we insert the file path right after it
---@param file_path string Relative path to insert
local function insert_file_reference(file_path)
  -- In insert mode, after @ is typed, cursor is positioned after the @
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  
  -- Insert file_path at cursor position (right after the @)
  -- col is 0-indexed, and points to the character position
  -- We want to insert after the cursor, so we use col+1 for the split point
  local new_line = line:sub(1, col + 1) .. file_path .. line:sub(col + 2)
  
  vim.api.nvim_set_current_line(new_line)
  
  -- Move cursor to the last character of the inserted path
  -- col is 0-indexed, so the last char is at col + #file_path
  vim.api.nvim_win_set_cursor(0, { row, col + #file_path })
  
  -- Use 'a' (append) to enter insert mode after the cursor position
  -- This will position us correctly after the last inserted character
  vim.api.nvim_feedkeys('a', 'n', false)
end

---Shows file picker and inserts selected file reference at cursor
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
