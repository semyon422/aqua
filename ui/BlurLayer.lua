local Drawable = require("ui.Drawable")

---@class ui.BlurLayer.Params
---@field canvas_scale number
---@field blur_radius number?

---@class ui.BlurLayer : ui.Drawable, ui.BlurLayer.Params
---@overload fun(params: ui.BlurLayer.Params): ui.BlurLayer
local BlurLayer = Drawable + {}

BlurLayer.ClassName = "BlurLayer"

local horizontal = [[
extern number radius;
extern vec2 tex_size;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 step = vec2(1.0 / tex_size.x, 0.0);
    vec4 sum = vec4(0.0);
    float weight_sum = 0.0;

    for (int i = -20; i <= 20; i++) {
        float x = float(i);
        float w = exp(-(x * x) / (2.0 * radius * radius));
        vec2 offset = texture_coords + step * x;
        sum += Texel(tex, offset) * w;
        weight_sum += w;
    }

    return (sum / weight_sum) * color;
}
]]

local vertical = [[
extern number radius;
extern vec2 tex_size;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 step = vec2(0.0, 1.0 / tex_size.y);
    vec4 sum = vec4(0.0);
    float weight_sum = 0.0;

    for (int i = -20; i <= 20; i++) {
        float y = float(i);
        float w = exp(-(y * y) / (2.0 * radius * radius));
        vec2 offset = texture_coords + step * y;
        sum += Texel(tex, offset) * w;
        weight_sum += w;
    }

    return (sum / weight_sum) * color;
}
]]

function BlurLayer:beforeLoad()
	Drawable.beforeLoad(self)
	self.viewport = self:getViewport()
	self.horizontal_shader = love.graphics.newShader(horizontal)
	self.vertical_shader = love.graphics.newShader(vertical)
	self.use_mask = self.use_mask == nil and false or self.use_mask

	if self.use_mask then
		self.mask_providers = {} ---@type ui.EffectMaskProvider[]

		self.stencil_function = function()
			love.graphics.push()
			love.graphics.origin()
			love.graphics.applyTransform(self.viewport.negative)
			love.graphics.setColor(1, 1, 1)
			for i, v in ipairs(self.mask_providers) do
				love.graphics.push()
				love.graphics.applyTransform(v.world_transform)
				v:drawEffectMask()
				love.graphics.pop()
			end
			love.graphics.pop()
		end
	end

	self:createCanvas()
	self:ensureExist("canvas_scale")
end

function BlurLayer:createCanvas()
	self:setDimensions(self.viewport:getVirtualScreenDimensions())
	local w, h = self:getWidth() * self.canvas_scale, self:getHeight() * self.canvas_scale
	self.canvas = love.graphics.newCanvas(w, h)
	self.horizontal_shader:send("tex_size", { w, h })
	self.horizontal_shader:send("radius", self.blur_radius or 2)
	self.vertical_shader:send("tex_size", { w, h })
	self.vertical_shader:send("radius", self.blur_radius or 2)
end

---@return number
function BlurLayer:getScale()
	return self.canvas_scale
end

---@param drawable ui.EffectMaskProvider
function BlurLayer:addArea(drawable)
	table.insert(self.mask_providers, drawable)
end

function BlurLayer:update()
	local sw, sh = self.viewport:getVirtualScreenDimensions()

	if self:getWidth() ~= sw or self:getHeight() ~= sh then
		self:createCanvas()
	end
end

function BlurLayer:draw()
	local image = self.viewport:getCanvas()

	local prev_canvas = love.graphics.getCanvas()
	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.setShader(self.horizontal_shader)
	love.graphics.setCanvas(self.canvas)
	love.graphics.scale(self.canvas_scale)
	love.graphics.draw(image)
	love.graphics.setShader()
	love.graphics.setCanvas({ prev_canvas, stencil = true })
	love.graphics.pop()

	if self.use_mask then
		love.graphics.stencil(self.stencil_function, "replace", 1)
		love.graphics.setStencilTest("greater", 0)
		love.graphics.origin()
		love.graphics.setShader(self.vertical_shader)
		love.graphics.setColor(1, 1, 1, self.alpha)
		love.graphics.draw(self.canvas, 0, 0, 0, 1 / self.canvas_scale, 1 / self.canvas_scale)
		love.graphics.setShader()
		love.graphics.setStencilTest()
	else
		love.graphics.origin()
		love.graphics.setShader(self.vertical_shader)
		love.graphics.setColor(1, 1, 1, self.alpha)
		love.graphics.draw(self.canvas, 0, 0, 0, 1 / self.canvas_scale, 1 / self.canvas_scale)
		love.graphics.setShader()
	end
end

return BlurLayer
