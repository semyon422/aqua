local Drawable = require("ui.Drawable")

---@class ui.BlurLayer.Params
---@field canvas_scale number

---@class ui.BlurLayer : ui.Drawable, ui.BlurLayer.Params
---@overload fun(params: ui.BlurLayer.Params): ui.BlurLayer
local BlurLayer = Drawable + {}

BlurLayer.ClassName = "BlurLayer"

local shader_code = [[
extern number radius;
extern vec2 tex_size;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 step = radius / tex_size;
    vec4 sum = vec4(0.0);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            sum += Texel(tex, texture_coords + vec2(x, y) * step);
        }
    }

    return (sum / 9.0) * color;
}
]]

function BlurLayer:beforeLoad()
	Drawable.beforeLoad(self)
	self.viewport = self:getViewport()
	self.shader = love.graphics.newShader(shader_code)
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
	self:createCanvas()
	self:ensureExist("canvas_scale")
end

function BlurLayer:createCanvas()
	self:setDimensions(self.viewport:getScreenDimensions())
	local w, h = self:getWidth() * self.canvas_scale, self:getHeight() * self.canvas_scale
	self.canvas = love.graphics.newCanvas(w, h)
	self.shader:send("tex_size", { w, h })
	self.shader:send("radius", 2)
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
	local sw, sh = self.viewport:getScreenDimensions()

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
	love.graphics.setShader(self.shader)
	love.graphics.setCanvas(self.canvas)
	love.graphics.scale(self.canvas_scale)
	love.graphics.draw(image)
	love.graphics.setShader()
	love.graphics.setCanvas({ prev_canvas, stencil = true })
	love.graphics.pop()

	love.graphics.stencil(self.stencil_function, "replace", 1)
	love.graphics.setStencilTest("greater", 0)
	love.graphics.origin()
	love.graphics.draw(self.canvas, 0, 0, 0, 1 / self.canvas_scale, 1 / self.canvas_scale)
	love.graphics.setStencilTest()
end

return BlurLayer
