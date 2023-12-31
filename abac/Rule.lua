local class = require("class")

local Rule = class()

function Rule:new(effect)
	assert(effect == "permit" or effect == "deny", "invalid effect")
	self.effect = effect
end

function Rule:target() return true end  -- comparing an attribute with a constant
function Rule:condition() return true end  -- attribute comparison

-- obligation and advice not implemented

local function call(effect, f, ...)
	local d, err = pcall(f, ...)
	if not d then
		return "indeterminate", err
	end
	if not err then
		return "not_applicable"
	end
	return effect
end

function Rule:evaluate_target(...)
	return call(self.effect, self.target, self, ...)
end

function Rule:evaluate_condition(...)
	return call(self.effect, self.condition, self, ...)
end

function Rule:evaluate(...)
	local d, err = self:evaluate_target(...)
	if d ~= self.effect then
		return d, err
	end
	return self:evaluate_condition(...)
end

return Rule
