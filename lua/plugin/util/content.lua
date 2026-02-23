---Utilities for extracting content from Neovim buffers.
---Handles visual selection (char-wise, line-wise, block) and full-buffer extraction.

local M = {}

---Extract content from the current buffer.
---When called from a visual-mode mapping (mode is 'v', 'V', or CTRL-V),
---returns only the selected text. Otherwise returns the entire buffer.
---@return string|nil content Extracted text, or nil if empty/whitespace-only
---@return string|nil err Error message when content is empty or whitespace-only
function M.get_content()
	local lines = {}
	local mode = vim.fn.mode()

	-- Check if we are in visual mode (v = char-wise, V = line-wise, \22 = block)
	if mode == "v" or mode == "V" or mode == "\22" then
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		local start_line = start_pos[2]
		local end_line = end_pos[2]
		local start_col = start_pos[3]
		local end_col = end_pos[3]

		lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

		-- For char-wise visual selection, trim columns on first and last lines
		if mode == "v" and #lines > 0 then
			if #lines == 1 then
				lines[1] = string.sub(lines[1], start_col, end_col)
			else
				lines[1] = string.sub(lines[1], start_col)
				lines[#lines] = string.sub(lines[#lines], 1, end_col)
			end
		end
	else
		lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	end

	local content = table.concat(lines, "\n")
	if content == "" or content:match("^%s*$") then
		return nil, "Buffer is empty, nothing to send."
	end

	return content, nil
end

return M
