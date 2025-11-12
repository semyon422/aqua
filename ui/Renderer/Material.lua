local class = require("class")
local ShaderBuilder = require("ui.Renderer.ShaderBuilder")

---@class ui.Material A.K.A Shader Material
---@operator call: ui.Material
---@field shader love.Shader?
local Material = class()

---@enum ui.Material.InvalidationType
Material.InvalidationType = {
	None = 0,
	Uniform = 1, -- Uniform updated
	Feature = 2 -- Feature added/removed
}

---@param features ui.ShaderFeature[]
function Material:new(features)
	self.features = {}
	self.feature_set = {}
	self.invalidated = Material.InvalidationType.None

	for _, feature in ipairs(features) do
		self:resolveDependencies(feature)
	end
end

---@generic T : ui.ShaderFeature
---@param t T
---@return T
function Material:getFeature(t)
	return assert(self.feature_set[t], "Feature doesn't exist")
end

---@param feature ui.ShaderFeature
function Material:resolveDependencies(feature)
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

---@param texture_width number
---@param texture_height number
---@param border_radius [number, number, number, number]
function Material:updateBuffer(texture_width, texture_height, border_radius)
	if #self.features == 0 then
		return
	end

	if not self.shader or self.invalidated == Material.InvalidationType.Feature then
		self.shader, self.buffer = ShaderBuilder:getShader(self.features)
	end

	local data = {
		texture_width, texture_height,
		border_radius[1], border_radius[2], border_radius[3], border_radius[4]
	}

	for _, feature in ipairs(self.features) do
		feature:addUniforms(data)
	end

	self.buffer:setArrayData(data)
	self.invalidate = Material.InvalidationType.None
end

---@param uv_scale number
function Material:setUvScale(uv_scale)
	self.shader:send("uv_scale", uv_scale)
end

---@return boolean
function Material:isInvalidated()
	return self.invalidated ~= Material.InvalidationType.None or self.shader == nil
end

function Material:invalidateUniforms()
	self.invalidated = Material.InvalidationType.Uniform
end

return Material
