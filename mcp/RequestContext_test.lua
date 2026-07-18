local RequestContext = require("mcp.RequestContext")

local test = {}

---@param t testing.T
function test.cancels_once_and_notifies_handlers(t)
	local context = RequestContext("request-1")
	local reasons = {}
	context:onCancel(function(reason)
		table.insert(reasons, reason)
	end)

	local canceled, err = context:cancel("stopped")
	t:eq(canceled, true)
	t:eq(err, nil)
	t:tdeq(reasons, {"stopped"})
	t:tdeq({context:checkCanceled()}, {nil, "stopped"})
	t:eq(context:cancel("again"), false)

	context:onCancel(function(reason)
		table.insert(reasons, reason)
	end)
	t:tdeq(reasons, {"stopped", "stopped"})
end

return test
