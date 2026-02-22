local M = {}

local TITLE = 'opencode'

---Send a vim notification with the opencode title.
---@param msg string Notification message
---@param level integer vim.log.levels constant (INFO, WARN, ERROR, etc.)
---@return nil
function M.notify(msg, level)
  vim.notify(msg, level, { title = TITLE })
end

---Convenience wrappers
---@param msg string
function M.info(msg) M.notify(msg, vim.log.levels.INFO) end

---@param msg string
function M.warn(msg) M.notify(msg, vim.log.levels.WARN) end

---@param msg string
function M.error(msg) M.notify(msg, vim.log.levels.ERROR) end

return M
