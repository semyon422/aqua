local Rule = require("abac.Rule")

local test = {}

function test.permit(t)
	local rule = Rule("permit")

	local target_called, condition_called
	function rule:target()
		target_called = true
		return true
	end
	function rule:condition()
		condition_called = true
		return true
	end

	local dec = rule:evaluate()

	t:eq(dec, "permit")
	t:eq(target_called, true)
	t:eq(condition_called, true)
end

function test.not_applicable(t)
	local rule = Rule("permit")

	local target_called, condition_called
	function rule:target()
		target_called = true
		return false
	end
	function rule:condition()
		condition_called = true
		return true
	end

	local dec = rule:evaluate()

	t:eq(dec, "not_applicable")
	t:eq(target_called, true)
	t:eq(condition_called, nil)
end

function test.indeterminate(t)
	local rule = Rule("permit")

	local target_called, condition_called
	function rule:target()
		target_called = true
		error("msg")
	end
	function rule:condition()
		condition_called = true
		return true
	end

	local dec = rule:evaluate()

	t:eq(dec, "indeterminate")
	t:eq(target_called, true)
	t:eq(condition_called, nil)
end

return test
