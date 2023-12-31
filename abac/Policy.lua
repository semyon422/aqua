local class = require("class")
local Rule = require("abac.Rule")

local Policy = class()

function Policy:target() return true end

Policy.evaluate_target = Rule.evaluate_target

Policy.combine = require("abac.combines.all_applicable")
Policy.require_prefix = ""

function Policy:append(items, ...)
	local new = select(1, ...)
	local mt = new and getmetatable(new())
	for i, v in ipairs(items) do
		if type(v) == "string" then
			v = require(self.require_prefix .. v)
		elseif mt and getmetatable(v) ~= mt then
			v = setmetatable(v, mt)
			v:append(v, select(2, ...))
		end
		if items ~= self then
			self[#self + 1] = v
		else
			self[i] = v
		end
	end
	return self
end

function Policy:evaluate_rules(...)
	local errors = {}

	local d = nil
	for i = 1, #self do
		local _d, err = self[i]:evaluate(...)
		table.insert(errors, err)
		d = d and self.combine(d, _d) or _d
	end

	if #errors > 0 then
		return d, table.concat(errors, "\n")
	end

	return d
end

function Policy:evaluate(...)
	local d, err = self:evaluate_target(...)
	if d then
		return d, err
	end
	return self:evaluate_rules(...)
end

return Policy
