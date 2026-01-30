local coext = require("coext")

local test = {}

---@param t testing.T
function test.all(t)
	local out = {}

	local co1
	co1 = coext.create(function(...)
		table.insert(out, {...})

		local yield1 = coext.newyield()

		local co2 = coext.create(function(...)
			table.insert(out, {...})
			table.insert(out, {yield1("yield 1")})
			table.insert(out, {coext.yieldto(co1, "yield 2")})
			return "end 2"
		end)
		table.insert(out, {coext.resume(co2, "start 2")})

		return "end 1"
	end)

	t:tdeq({coext.resume(co1, "start 1")}, {true, "yield 1"})
	t:tdeq(out, {{"start 1"}, {"start 2"}})
	t:tdeq({coext.resume(co1, "resume 1")}, {true, "yield 2"})
	t:tdeq(out, {{"start 1"}, {"start 2"}, {"resume 1"}})
	t:tdeq({coext.resume(co1, "resume 2")}, {true, "end 1"})
	t:tdeq(out, {{"start 1"}, {"start 2"}, {"resume 1"}, {"resume 2"}, {true, "end 2"}})
end

return test
