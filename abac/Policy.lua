local class = require("class")
local Rule = require("abac.Rule")

local Policy = class()

Policy.combine = require("abac.combines.all_applicable")

function Policy:evaluate(rules_repo, ...)
	local errors = {}

	local d = nil
	for _, rule_name in ipairs(self) do
		local rule = setmetatable(rules_repo[rule_name], Rule)
		local _d, err = rule:evaluate(...)
		table.insert(errors, err)
		d = d and self.combine(d, _d) or _d
	end

	if #errors > 0 then
		return d, table.concat(errors, "\n")
	end

	return d
end

return Policy
