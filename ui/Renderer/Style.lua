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
---@field color ui.Color
---@field alpha number
---@field blend_mode string
---@field blend_mode_alpha "alphamultiply" | "premultiplied"

---@class ui.Style.ContentCache
---@field canvas love.Canvas?
---@field needs_redraw boolean
---@field effects ui.ShaderFeature[]
---@field material ui.Material
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
---@field shadow ui.Style.Shadow?
---@field backdrop ui.Style.Backdrop?
---@field content ui.Style.Content?
---@field stencil_mask function?
local Style = class()

function Style:new(params)
	self.width = math.max(0, params.width or 0)
	self.height = math.max(0, params.height or 0)
	self.padding = math.max(0, params.padding or 0)
	self.border_radius = params.border_radius
	self:createShadow(params.shadow)
	self:createBackdrop(params.backdrop)
	self:createContent(params.content)
	self:createContentCache(params.content_cache)
end

---@param params table
---@param defaults table
---@return table?
local function applyDefaults(params, defaults)
	if not params then
		return
	end
	local result = {}
	for k, default in pairs(defaults) do
		if params[k] then
			result[k] = params[k]
		else
			result[k] = type(default) == "table" and table_util.copy(default) or default
		end
	end
	for k, v in pairs(params) do
		result[k] = v
	end
	return result
end

local DEFAULT_SHADOW = {
	color = { 0, 0, 0, 0.5 },
	radius = 2,
	x = 0,
	y = 0,
}

---@param params ui.Style.Shadow
function Style:createShadow(params)
	if not params then
		return
	end

	self.shadow = applyDefaults(params, DEFAULT_SHADOW)
	self.shadow.material = Material({
		DropShadow(self.shadow.color, self.shadow.radius)
	})
end

---@param params ui.Style.Backdrop
function Style:createBackdrop(params)
	if not params then
		return
	end

	local t = {}
	t.blur = params.blur
	t.effects = params.effects or {}
	t.material = Material(self.backdrop.effects)
	self.backdrop = t
end

local DEFAULT_CONTENT = {
	color = { 1, 1, 1, 1 },
	alpha = 1,
	blend_mode = "alpha",
	blend_mode_alpha = "alphamultiply",
	effects = {}
}

---@param params ui.Style.Content
function Style:createContent(params)
	if not params then
		return
	end

	self.content = applyDefaults(params, DEFAULT_CONTENT)
	self.content.material = Material(self.content.effects)
end

local DEFAULT_CONTENT_CACHE = {
	needs_redraw = true,
	color = { 1, 1, 1, 1 },
	alpha = 1,
	blend_mode = "alpha",
	blend_mode_alpha = "alphamultiply",
	effects = {}
}

---@param params ui.Style.ContentCache
function Style:createContentCache(params)
	if not params then
		return
	end

	self.content_cache = applyDefaults(params, DEFAULT_CONTENT_CACHE)
	self.content_cache.material = Material(self.content_cache.effects)
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
	self:updateMaterialInside(self.content_cache)
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
