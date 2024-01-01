local class = require("class")

local Rule = class()

Rule.effect = "permit"  -- or "deny"

function Rule:condition()
	return true
end

function Rule:evaluate(...)
	local d, err = pcall(self.condition, self, ...)
	if not d then
		return "indeterminate", err
	end
	if not err then
		return "not_applicable"
	end
	return self.effect
end

return Rule
