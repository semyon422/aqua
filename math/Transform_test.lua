local Transform = require("math.Transform")

local test = {}

---@param t testing.T
function test.new_and_reset_identity(t)
	local tf = Transform()
	t:eq(tf.a, 1)
	t:eq(tf.b, 0)
	t:eq(tf.c, 0)
	t:eq(tf.d, 1)
	t:eq(tf.tx, 0)
	t:eq(tf.ty, 0)

	tf:setTransformation(10, 20, 0, 2, 3, 1, 1)
	tf:reset()
	t:eq(tf.a, 1)
	t:eq(tf.b, 0)
	t:eq(tf.c, 0)
	t:eq(tf.d, 1)
	t:eq(tf.tx, 0)
	t:eq(tf.ty, 0)
end

---@param t testing.T
function test.set_transformation_translation_scale_rotation_origin(t)
	local tf = Transform()

	tf:setTransformation(10, 20)
	local x, y = tf:transformPoint(1, 2)
	t:eq(x, 11)
	t:eq(y, 22)

	tf:setTransformation(100, 200, 0, 2, 3, 4, 5)
	x, y = tf:transformPoint(4, 5)
	t:aeq(x, 100, 1e-9)
	t:aeq(y, 200, 1e-9)

	tf:setTransformation(0, 0, math.pi / 2)
	x, y = tf:transformPoint(1, 0)
	t:aeq(x, 0, 1e-8)
	t:aeq(y, 1, 1e-8)
end

---@param t testing.T
function test.apply_composition(t)
	local a = Transform()
	a:setTransformation(10, 0)

	local b = Transform()
	b:setTransformation(0, 0, 0, 2, 2)

	a:apply(b)

	local x, y = a:transformPoint(3, 4)
	t:eq(x, 16)
	t:eq(y, 8)
end

---@param t testing.T
function test.round_trip(t)
	local tf = Transform()
	tf:setTransformation(10, 20, 0.3, 2, 1.5, 4, 5)

	local x, y = tf:transformPoint(7, -3)
	local rx, ry = tf:inverseTransformPoint(x, y)
	t:aeq(rx, 7, 1e-8)
	t:aeq(ry, -3, 1e-8)
end

return test
