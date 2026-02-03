local M = {}

---@class PluginConfig
---@field enabled boolean

---Setup function: registers plugin commands
---@param opts? PluginConfig
function M.setup(opts)
  opts = opts or {}
  
  -- Register OC command
  vim.api.nvim_create_user_command('OC', function()
    require('plugin.commands').toggle_terminal()
  end, { desc = 'Open terminal in vertical split on the right' })
  
end

return M
