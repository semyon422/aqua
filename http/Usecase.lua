local class = require("class")
local PolicySet = require("abac.PolicySet")

---@class http.Usecase
---@operator call: http.Usecase
local Usecase = class()

function Usecase:authorize(params)
	if not self.policy_set then
		return "permit"
	end
	local policy_set = PolicySet(self.policy_set)
	return policy_set:evaluate(self._rules_repo, params)
end

function Usecase:run(params)
	local found = self._models:select(params, self.models)
	if not found then
		return "not_found", params
	end

	if self.validate then
		local ok, err = self.validate(params)
		if not ok then
			params.errors = {err}
			return "validation", params
		end
	end

	local decision, err = self:authorize(params)
	if decision ~= "permit" then
		params.errors = {err}
		return "forbidden", params
	end

	return self.handle(params, self._models)
end

return Usecase
