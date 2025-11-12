local class = require("class")
local Material = require("ui.Renderer.Material")

---@class ui.Style.Shadow
---@field x number
---@field y number
---@field radius number
---@field color ui.Color

---@class ui.Style.Blur
---@field type "gaussian" | "kawase"
---@field radius integer

---@class ui.Style.Backdrop
---@field blur ui.Style.Blur?
---@field effects ui.ShaderFeature[]
---@field material ui.Material

---@class ui.Style.Content
---@field effects ui.ShaderFeature[]
---@field material ui.Material

---@class ui.Style
---@operator call: ui.Style
---@field width number
---@field height number
---@field padding number
---@field border_radius [number, number, number, number]? left top bottom right
---@field color ui.Color
---@field alpha number
---@field blend_mode string
---@field blend_mode_alpha "alphamultiply" | "premultiplied"
---@field shadow ui.Style.Shadow?
---@field backdrop ui.Style.Backdrop?
---@field content ui.Style.Content?
---@field stencil_mask function?
local Style = class()

function Style:new(params)
	self.width = 0
	self.height = 0
	self.padding = 0
	self.color = { 1, 1, 1, 1 }
	self.alpha = 1
	self.blend_mode = "alpha"
	self.blend_mode_alpha = "alphamultiply"

	for k, v in pairs(params) do
		self[k] = v
	end

	if self.backdrop then
		self.backdrop.material = Material(self.backdrop.effects)
	end

	if self.content then
		self.content.material = Material(self.content.effects)
	end
end

---@return number
---@return number
function Style:getDimensions()
	local w = self.width + self.padding * 2
	local h = self.height + self.padding * 2
	return w, h
end

local empty_border_radius = { 0, 0, 0, 0 }
local uv_scale = { 0, 0 }

function Style:updateMaterials()
	if self.backdrop then
		local material = self.backdrop.material
		if material:isInvalidated() then
			local w, h = self:getDimensions()
			material:updateBuffer(w, h, self.border_radius or empty_border_radius)
			uv_scale[1] = self.width / love.graphics.getWidth()
			uv_scale[2] = self.height / love.graphics.getHeight()
			material:setUvScale(uv_scale)
		end
	end

	if self.content then
		local material = self.content.material
		if material:isInvalidated() then
			local w, h = self:getDimensions()
			material:updateBuffer(w, h, self.border_radius or empty_border_radius)
			uv_scale[1] = 1
			uv_scale[2] = 1
			material:setUvScale(uv_scale)
		end
	end
end

---@param width number
---@param height number
function Style:setDimensions(width, height)
	if self.width == width and self.height == height then
		return
	end
	self.width = width
	self.height = height

	if self.backdrop then
		self.backdrop.material:invalidateUniforms()
	end

	if self.content then
		self.content.material:invalidateUniforms()
	end
end

return Style
