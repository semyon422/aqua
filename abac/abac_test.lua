local Policy = require("abac.Policy")
local PolicySet = require("abac.PolicySet")
local Access = require("abac.Access")

local test = {}

function test.all(t)
	local rules_repo = {
		myrule = {},
	}

	local policy_config = {"myrule"}
	local policy = Policy(policy_config)
	local dec = policy:evaluate(rules_repo, {})
	t:eq(dec, "permit")

	local policy_set_config = {
		{"myrule"},
	}
	local policy_set = PolicySet(policy_set_config)
	local dec = policy_set:evaluate(rules_repo, {})
	t:eq(dec, "permit")

	local access = Access(rules_repo)
	local dec = access:authorize({}, policy_set_config)
	t:eq(dec, true)
end

return test
