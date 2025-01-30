local TestModel = require("rdb.TestModel")

local test = {}

---@param t testing.T
function test.basic(t)
	local model = TestModel()

	local obj_a = model:create({name = "a"})
	local obj_b = model:create({name = "b"})
	local obj_c = model:create({name = "c"})

	t:eq(model:count(), 3)
	t:eq(obj_c.id, 3)

	model:remove({id = 2})

	t:eq(model:count(), 2)

	model:update({name = "x"}, {id = 1})
	t:eq(obj_a.name, "x")

	local obj_x = model:find({name = "x"})
	t:eq(obj_x and obj_x.id, 1)

	local obj_d = model:create({name = "d"})
	t:eq(obj_x and obj_x.id, 1)

	t:eq(model:count(), 3)
	t:eq(obj_d.id, 4)
end

return test
