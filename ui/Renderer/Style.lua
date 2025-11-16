local class = require("class")
local table_util = require("table_util")
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
---@field color ui.Color
---@field alpha number
---@field blend_mode string
---@field blend_mode_alpha "alphamultiply" | "premultiplied"

---@class ui.Style
---@operator call: ui.Style
---@field width number
---@field height number
---@field padding number
---@field border_radius [number, number, number, number]? left top bottom right
---@field render_children_on_texture boolean?
---@field shadow ui.Style.Shadow?
---@field backdrop ui.Style.Backdrop?
---@field content ui.Style.Content?
---@field stencil_mask function?
local Style = class()

function Style:new(params)
	self.width = 0
	self.height = 0
	self.padding = 0

	self.width = math.max(0, params.width or 0)
	self.height = math.max(0, params.height or 0)
	self.padding = math.max(0, params.padding or 0)
	self.border_radius = params.border_radius

	if params.shadow then
		local src = params.shadow
		local shadow = {}
		shadow.color = src.color or { 0, 0, 0, 0.5 }
		shadow.radius = src.radius or 2
		shadow.x = src.x or 0
		shadow.y = src.y or 0
		shadow.material = Material({ DropShadow(shadow.color, shadow.radius) })
		self.shadow = shadow
	end

	if params.backdrop then
		local src = params.backdrop
		local backdrop = {}
		backdrop.blur = src.blur
		backdrop.effects = src.effects or {}
		backdrop.material = Material(backdrop.effects)
		self.backdrop = backdrop
	end

	if params.content then
		local src = params.content
		local content = {}
		content.effects = src.effects or {}
		content.color = src.color or { 1, 1, 1, 1 }
		content.alpha = src.alpha or 1
		content.blend_mode = src.blend_mode or "alpha"
		content.blend_mode_alpha = src.blend_mode_alpha or "alphamultiply"
		content.material = Material(content.effects)
		self.content = content
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
