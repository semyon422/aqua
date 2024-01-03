local class = require("class")
local PolicySet = require("abac.PolicySet")

local Access = class()

---@param rules_repo table
function Access:new(rules_repo)
	self.rules_repo = rules_repo
end

function Access:authorize(params, policy_set_config)
	local policy_set = PolicySet(policy_set_config)
	local dec, err = policy_set:evaluate(self.rules_repo, params)
	return dec == "permit", err
end

return Access
