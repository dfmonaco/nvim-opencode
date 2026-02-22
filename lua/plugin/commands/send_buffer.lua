local state = require('plugin.state')
local Client = require('plugin.client')
local Notify = require('plugin.notify')

---Sends current buffer content (or visual selection) to OpenCode session
---@return nil
local function send()
  -- Get port and session ID from state
  local port = state.get_port()
  local session_id = state.get_session_id()

  -- Validate we have required state
  if not port then
    Notify.error('No OpenCode server port found. Please open OC terminal first.')
    return
  end

  if not session_id then
    Notify.error('No OpenCode session ID found. Please ensure OC terminal is running.')
    return
  end

  -- Get buffer content based on mode
  local lines = {}
  local mode = vim.fn.mode()
  
  -- Check if we're in visual mode (v, V, or CTRL-V)
  if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is CTRL-V
    -- Get visual selection
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2]
    local end_line = end_pos[2]
    local start_col = start_pos[3]
    local end_col = end_pos[3]
    
    lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    
    -- Handle character-wise visual selection
    if mode == 'v' and #lines > 0 then
      if #lines == 1 then
        -- Single line selection
        lines[1] = string.sub(lines[1], start_col, end_col)
      else
        -- Multi-line selection
        lines[1] = string.sub(lines[1], start_col)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
    end
  else
    -- Get entire buffer content
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  -- Check if content is empty
  local content = table.concat(lines, '\n')
  if content == '' or content:match('^%s*$') then
    Notify.warn('Buffer is empty, nothing to send.')
    return
  end

  -- Create client with port from state
  local client = Client.get_or_create_client()

  -- Build message parts
  local message_parts = {
    {
      type = 'text',
      text = content,
    },
  }

  -- Send message asynchronously
  client:send_message_async(session_id, message_parts, nil, function(err, success)
    if err then
      Notify.error('Failed to send buffer: ' .. err)
    elseif success then
      Notify.info('Buffer sent to OpenCode session')
    end
  end)
end

return {
  send = send,
}
