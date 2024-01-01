local class = require("class")
local Policy = require("abac.Policy")

local PolicySet = class()

PolicySet.combine = require("abac.combines.first_applicable")

function PolicySet:evaluate(rules_repo, ...)
	local errors = {}

	local d = nil
	for _, policy in ipairs(self) do
		setmetatable(policy, Policy)
		local _d, err = policy:evaluate(rules_repo, ...)
		table.insert(errors, err)
		d = d and self.combine(d, _d) or _d
	end

	if #errors > 0 then
		return d, table.concat(errors, "\n")
	end

	return d
end

return PolicySet
