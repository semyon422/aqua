local class = require("class")
local ShaderBuilder = require("ui.Renderer.ShaderBuilder")

---@class ui.Style
---@operator call: ui.Style
---@field width number
---@field height number
---@field color ui.Color
---@field alpha number
---@field blend_mode string
---@field blend_mode_alpha "alphamultiply" | "premultiplied"
---@field features ui.ShaderFeature[]
---@field feature_set {[ui.ShaderFeature]: ui.ShaderFeature}
---@field shader love.Shader?
---@field buffer table?
---@field invalidated ui.Style.InvalidationType
local Style = class()

---@enum ui.Style.InvalidationType
Style.InvalidationType = {
	None = 0,
	Uniform = 1, -- Uniform updated
	Feature = 2 -- Feature added/removed
}

---@param features ui.ShaderFeature[]
function Style:new(features)
	self.width = 0
	self.height = 0
	self.color = { 1, 1, 1, 1 }
	self.alpha = 1
	self.blend_mode = "alpha"
	self.blend_mode_alpha = "alphamultiply"
	self.features = {}
	self.feature_set = {}
	self.invalidated = Style.InvalidationType.None

	for _, feature in ipairs(features) do
		self:resolveDependencies(feature)
	end
end

---@generic T
---@param t T
---@return T
function Style:getFeature(t)
	return assert(self.feature_set[t], "Feature doesn't exist")
end

---@param feature ui.ShaderFeature
function Style:resolveDependencies(feature)
	if self.feature_set[getmetatable(feature)] then
		return
	end

	self.feature_set[getmetatable(feature)] = feature

	if feature.requires then
		for _, c in ipairs(feature.requires) do
			self:resolveDependencies(c())
		end
	end

	table.insert(self.features, feature)
end

function Style:updateBuffer()
	if not self.shader or self.invalidated == Style.InvalidationType.Feature then
		self.shader, self.buffer = ShaderBuilder:getShader(self.features)

		if not self.shader then
			-- Meaning this style has no features
			return
		end
	end

	local data = { self.width, self.height }

	for _, feature in ipairs(self.features) do
		feature:addUniforms(data)
	end

	self.buffer:setArrayData(data)
	self.invalidate = Style.InvalidationType.None
end

function Style:apply()
	if self.invalidated ~= Style.InvalidationType.None then
		self:updateBuffer()
	end

	local c = self.color
	love.graphics.setColor(c[1], c[2], c[3], c[4] * self.alpha)
	love.graphics.setBlendMode(self.blend_mode, self.blend_mode_alpha)
	love.graphics.setShader(self.shader)
	self.shader:send(ShaderBuilder.buffer_name, self.buffer)
end

function Style:invalidateUniforms()
	self.invalidated = Style.InvalidationType.Uniform
end

---@param width number
---@param height number
function Style:setDimensions(width, height)
	if self.width == width and self.height == height then
		return
	end
	self.width = width
	self.height = height
	self.invalidated = Style.InvalidationType.Uniform
end

return Style
