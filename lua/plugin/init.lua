local M = {}

--- Setup function: registers HelloWorld command
function M.setup()
  vim.api.nvim_create_user_command('HelloWorld', function()
    print('Hello, world!')
  end, {})
end

return M
