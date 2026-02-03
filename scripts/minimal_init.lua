-- Add current directory to 'runtimepath' to allow using local 'lua/' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Setup 'mini.test' only in headless
if #vim.api.nvim_list_uis() == 0 then
  vim.cmd('set rtp+=deps/mini.nvim')
  require('mini.test').setup()
end
