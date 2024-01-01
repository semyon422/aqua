local Rule = require("abac.Rule")

local test = {}

function test.permit(t)
	local MyRule = Rule + {}
	MyRule.effect = "permit"
	local condition_called
	function MyRule:condition()
		condition_called = true
		return true
	end

	local rule = MyRule()
	local dec = rule:evaluate()

	t:eq(dec, "permit")
	t:eq(condition_called, true)
end

function test.not_applicable(t)
	local MyRule = Rule + {}
	MyRule.effect = "permit"
	local condition_called
	function MyRule:condition()
		condition_called = true
		return false
	end

	local rule = MyRule()
	local dec = rule:evaluate()

	t:eq(dec, "not_applicable")
	t:eq(condition_called, true)
end

function test.indeterminate(t)
	local MyRule = Rule + {}
	MyRule.effect = "permit"
	local condition_called
	function MyRule:condition()
		error("msg")
		condition_called = true
		return true
	end

	local rule = MyRule()
	local dec, err = rule:evaluate()

	t:eq(dec, "indeterminate")
	t:eq(err:sub(-3), "msg")
	t:eq(condition_called, nil)
end

return test
