local state = require('plugin.state')

---Creates or focuses the OCPrompt buffer in the current window.
---If it already exists and is valid, focuses it; else, creates it anew.
---@return number bufnr The OCPrompt buffer number
local function toggle_prompt()
  local buf = state.get_ocprompt_buffer()

  -- If OCPrompt buffer exists and is valid, just focus it
  if buf and vim.api.nvim_buf_is_valid(buf) then
    if vim.api.nvim_get_current_buf() ~= buf then
      vim.api.nvim_win_set_buf(0, buf)
    end
    vim.cmd('startinsert')
    return buf
  end

  -- Create OCPrompt buffer as a listed scratch buffer
  local oc_prompt_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(oc_prompt_buf, 'OCPrompt')

  -- Set only canonical buffer type and filetype. All other buffer and window options set in ftplugin.
  vim.bo[oc_prompt_buf].buftype = 'nofile'
  vim.bo[oc_prompt_buf].filetype = 'OCPrompt'

  -- Show buffer in current window
  vim.api.nvim_win_set_buf(0, oc_prompt_buf)

  -- Store in state
  state.set_ocprompt_buffer(oc_prompt_buf)

  -- Register to clear state if buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = oc_prompt_buf,
    once = true,
    callback = function()
      state.clear_ocprompt_buffer()
    end,
  })

  vim.cmd('startinsert')
  return oc_prompt_buf
end

---Clears the contents of the OCPrompt buffer
---@return nil
local function clear_prompt_buffer()
  local buf = state.get_ocprompt_buffer()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  end
end

return {
  toggle_prompt = toggle_prompt,
  clear_prompt_buffer = clear_prompt_buffer,
}
