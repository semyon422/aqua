local Policy = require("abac.Policy")

local PolicySet = Policy + {}

PolicySet.combine = require("abac.combines.first_applicable")

return PolicySet
