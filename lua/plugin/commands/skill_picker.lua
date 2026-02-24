---@module 'plugin.commands.skill_picker'
local Client = require('plugin.client')
local Notify = require('plugin.notify')

local M = {}

---Format a skill for display in the picker.
---@param skill Skill
---@return string
local function format_skill(skill)
	if skill.description and skill.description ~= '' then
		return skill.name .. '  —  ' .. skill.description
	end
	return skill.name
end

---Open a picker showing all available skills and open the selected skill's location file.
---@return nil
function M.pick()
	local client = Client.get_or_create_client()

	client:list_skills(function(err, skills)
		if err then
			Notify.error('Failed to fetch skills: ' .. err)
			return
		end

		if not skills or #skills == 0 then
			Notify.warn('No skills available.')
			return
		end

		vim.ui.select(skills, {
			prompt = 'Select skill:',
			format_item = format_skill,
		}, function(selected)
			if not selected then return end

			if selected.location then
				vim.cmd('edit ' .. selected.location)
			end
		end)
	end)
end

return M
