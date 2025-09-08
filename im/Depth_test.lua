local Depth = require("im.Depth")

local test = {}

---@param t testing.T
function test.overlap(t)
	local depth = Depth()

	t:eq(depth.exited_id, nil)
	t:eq(depth.entered_id, nil)
	t:eq(depth:over(1, true), false)
	t:eq(depth:over(2, true), false)
	depth:step()

	t:eq(depth.exited_id, nil)
	t:eq(depth.entered_id, 2)
	t:eq(depth:over(1, true), false)
	t:eq(depth:over(2, true), true)
	depth:step()

	t:eq(depth.exited_id, nil)
	t:eq(depth.entered_id, nil)
	t:eq(depth:over(1, true), false)
	t:eq(depth:over(2, true), true)
	depth:step()

	t:eq(depth.exited_id, nil)
	t:eq(depth.entered_id, nil)
	t:eq(depth:over(1, true), false)
	t:eq(depth:over(2, false), true)
	depth:step()

	t:eq(depth.exited_id, 2)
	t:eq(depth.entered_id, 1)
	t:eq(depth:over(1, true), true)
	t:eq(depth:over(2, false), false)
	depth:step()

	t:eq(depth.exited_id, nil)
	t:eq(depth.entered_id, nil)
	t:eq(depth:over(1, true), true)
	t:eq(depth:over(2, false), false)
	depth:step()
end

return test
