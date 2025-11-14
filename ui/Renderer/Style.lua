local class = require("class")
local Material = require("ui.Renderer.Material")
local DropShadow = require("ui.Renderer.Shader.DropShadow")

---@class ui.Style.Shadow
---@field x number
---@field y number
---@field radius number
---@field color ui.Color
---@field material ui.Material

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
---@field texture love.Image?

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

	self.width = math.max(0, self.width)
	self.height = math.max(0, self.height)
	self.padding = math.max(0, self.padding)

	if self.shadow then
		local c = self.shadow.color or { 0, 0, 0, 0.5 }
		local r = self.shadow.radius or 2
		self.shadow.x = self.shadow.x or 0
		self.shadow.y = self.shadow.y or 0
		self.shadow.material = Material({ DropShadow(c, r) })
	end

	if self.backdrop and self.backdrop.effects then
		self.backdrop.material = Material(self.backdrop.effects)
	end

	if self.content and self.content.effects then
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

---@param container { material: ui.Material }
---@private
function Style:updateMaterialInside(container)
	if container and container.material then
		local material = container.material
		if material:isInvalidated() then
			local w, h = self:getDimensions()
			material:updateBuffer(w, h, self.border_radius or empty_border_radius)
		end
		material:sendBuffer()
	end
end

function Style:updateMaterials()
	self:updateMaterialInside(self.shadow)
	self:updateMaterialInside(self.backdrop)
	self:updateMaterialInside(self.content)
end

---@param width number
---@param height number
function Style:setDimensions(width, height)
	width = math.max(0, width)
	height = math.max(0, height)

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

---@param scale_x number
---@param scale_y number
function Style:setBackdropUvScale(scale_x, scale_y)
	if self.backdrop then
		self.backdrop.material:setUvScale(scale_x, scale_y)
	end
end

return Style
