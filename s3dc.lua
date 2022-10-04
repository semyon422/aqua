local s3dc = {}

local shader_code = [[
	extern mat4 projection, inv_translate, inv_rotate_y, inv_rotate_x;
	extern bool is_canvas;
	vec4 position(mat4 transform_projection, vec4 vertex_position)
	{
		vec4 pos = TransformMatrix * vertex_position * inv_translate * inv_rotate_y * inv_rotate_x * projection;
		if (is_canvas)
		{
			pos.y *= -1;
		}
		return pos;
	}
]]

local function identity()
	return {
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}
end

local function cross(out, a, b)
	local x = a[2] * b[3] - a[3] * b[2]
	local y = a[3] * b[1] - a[1] * b[3]
	local z = a[1] * b[2] - a[2] * b[1]
	out[1] = x
	out[2] = y
	out[3] = z
end

local function mul(out, a, b)
	out[1] = a[1] * b
	out[2] = a[2] * b
	out[3] = a[3] * b
end

local function add(out, a, b)
	out[1] = a[1] + b[1]
	out[2] = a[2] + b[2]
	out[3] = a[3] + b[3]
end

local function norm(out, a)
	local k = math.sqrt(a[1] ^ 2 + a[2] ^ 2 + a[3] ^ 2)
	return mul(out, a, k == 0 and 0 or 1 / k)
end

local shader
local projection, inv_translate, inv_rotate_y, inv_rotate_x
function s3dc.load()
	s3dc.pos = {0, 0, 0}
	s3dc.angle = {pitch = 0, yaw = 0}
	s3dc.top = {0, -1, 0}
	s3dc.front = {0, 0, 1}
	s3dc.fov = math.rad(70)
	s3dc.near = 10
	s3dc.far = 10000

	shader = shader or love.graphics.newShader(shader_code)

	projection = identity()
	inv_translate = identity()
	inv_rotate_y = identity()
	inv_rotate_x = identity()

	s3dc.rotate(0, 0)
end

function s3dc.show(x, y, w, h)
	local pos = s3dc.pos
	pos[1] = x + w / 2
	pos[2] = y + h / 2
	pos[3] = -h / 2 / math.tan(s3dc.fov / 2)

	local angle = s3dc.angle
	angle.pitch = 0
	angle.yaw = 0
end

local function inv_translate_mat4()
	inv_translate[13] = -s3dc.pos[1]
	inv_translate[14] = -s3dc.pos[2]
	inv_translate[15] = -s3dc.pos[3]
end

local function inv_rotate_y_mat4()
	local c = math.cos(-s3dc.angle.yaw)
	local s = math.sin(-s3dc.angle.yaw)

	inv_rotate_y[1] = c
	inv_rotate_y[3] = -s
	inv_rotate_y[9] = s
	inv_rotate_y[11] = c
end

local function inv_rotate_x_mat4()
	local c = math.cos(-s3dc.angle.pitch)
	local s = math.sin(-s3dc.angle.pitch)

	inv_rotate_x[6] = c
	inv_rotate_x[7] = s
	inv_rotate_x[10] = -s
	inv_rotate_x[11] = c
end

local function from_perspective(fovy, aspect, near, far)
	assert(aspect ~= 0)
	assert(near ~= far)

	local t = math.tan(fovy / 2)
	projection[1] = 1 / (t * aspect)
	projection[6] = -1 / t
	projection[11] = -(far + near) / (far - near)
	projection[12] = 1
	projection[15] = (2 * far * near) / (far - near)
	projection[16] = 0
end

local drawing = false
local width, height
function s3dc.draw_start()
	assert(not drawing, "Calling s3dc.draw_start() twice")
	drawing = true

	width, height = love.graphics.getDimensions()
	s3dc.draw_update()

	love.graphics.setShader(shader)
	shader:send("is_canvas", love.graphics.getCanvas() ~= nil)
end

function s3dc.draw_end()
	assert(drawing, "Calling s3dc.draw_end() twice")
	drawing = false
	love.graphics.setShader()
end

function s3dc.draw_update()
	from_perspective(s3dc.fov, width / height, s3dc.near, s3dc.far)
	inv_translate_mat4()
	inv_rotate_y_mat4()
	inv_rotate_x_mat4()

	shader:send("projection", projection)
	shader:send("inv_translate", inv_translate)
	shader:send("inv_rotate_y", inv_rotate_y)
	shader:send("inv_rotate_x", inv_rotate_x)
end

function s3dc.translate(dx, dy, dz)
	local pos = s3dc.pos
	pos[1] = pos[1] + dx
	pos[2] = pos[2] + dy
	pos[3] = pos[3] + dz
end

function s3dc.rotate(dx, dy)
	local angle = s3dc.angle
	angle.pitch = angle.pitch + dx  -- rotation about the X axis
	angle.yaw = angle.yaw + dy  -- rotation about the Y axis

	local front = s3dc.front
	front[1] = math.sin(angle.yaw) * math.cos(angle.pitch)
	front[2] = -math.sin(angle.pitch)
	front[3] = math.cos(angle.yaw) * math.cos(angle.pitch)
	norm(front, front)
end

local tmp_vec3 = {}

function s3dc.forward(delta)
	mul(tmp_vec3, s3dc.front, delta)
	add(s3dc.pos, s3dc.pos, tmp_vec3)
end

function s3dc.right(delta)
	cross(tmp_vec3, s3dc.front, s3dc.top)
	norm(tmp_vec3, tmp_vec3)
	mul(tmp_vec3, tmp_vec3, delta)
	add(s3dc.pos, s3dc.pos, tmp_vec3)
end

function s3dc.up(delta)
	cross(tmp_vec3, s3dc.front, s3dc.top)
	cross(tmp_vec3, tmp_vec3, s3dc.front)
	norm(tmp_vec3, tmp_vec3)
	mul(tmp_vec3, tmp_vec3, delta)
	add(s3dc.pos, s3dc.pos, tmp_vec3)
end

function s3dc.backward(delta)
	return s3dc.forward(-delta)
end

function s3dc.left(delta)
	return s3dc.right(-delta)
end

function s3dc.down(delta)
	return s3dc.up(-delta)
end

return s3dc
