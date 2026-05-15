local traceback = require("traceback")

local test = {}

---@param t testing.T
function test.capture_with_message(t)
	local function nested()
		return traceback.capture("boom")
	end

	local trace = nested()

	t:eq(trace.message, "boom")
	t:assert(type(trace.frames) == "table")
	t:assert(#trace.frames > 0)

	local top = trace.frames[1]
	t:assert(type(top.short_src) == "string")
	t:assert(type(top.currentline) == "number")
end

---@param t testing.T
function test.capture_with_non_string_message(t)
	local message = {code = 500}
	local trace = traceback.capture(message)
	t:eq(trace.message, message)
	t:assert(#trace.frames > 0)
end

---@param t testing.T
function test.capture_with_level(t)
	local function nested()
		return traceback.capture("boom", 2)
	end
	local function nested_default()
		return traceback.capture("boom")
	end
	local function root()
		return nested()
	end
	local function root_default()
		return nested_default()
	end

	local trace = root()
	local trace_default = root_default()
	t:assert(#trace_default.frames > #trace.frames)
end

return test
