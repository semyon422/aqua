local class = require("class")
local ShaderCode = require("ui.material.shader.Code")

---@class ui.Material
---@operator call: ui.Material
---@field features {[ui.IFeature]: ui.FeatureConfig[]}
---@field shader love.Shader?
---@field shader_hash string?
---@field ssbo table?
local Material = class()

function Material:new()
	self.features = {}
	self.sorted_features = {}
	self.is_dirty = false
	self.requires_sorting = false
end

---@param feature ui.IFeature
---@param config ui.FeatureConfig
function Material:set(feature, config)
	feature.validateConfig(config)
	self.features[feature] = { config }
	self.is_dirty = true
	self.requires_sorting = true
end

---@param feature ui.IFeature
---@param config ui.FeatureConfig
function Material:push(feature, config)
	feature.validateConfig(config)
	local configs = self.features[feature] or {}
	table.insert(configs, config)
	self.features[feature] = configs
	self.is_dirty = true
	self.requires_sorting = true
end

---@param feature ui.IFeature
---@return ui.FeatureConfig[]
--- Used to update values inside material. Marks material dirty
function Material:mutate(feature)
	self.is_dirty = true
	return assert(self.features[feature], "This material doesn't have this feature")
end

---@param a ui.IFeature
---@param b ui.IFeature
---@return boolean
local sort_func = function(a, b)
	return a.layer > b.layer
end

---@return string hash
function Material:getShaderHash()
	local names = {}
	for _, feature in ipairs(self.sorted_features) do
		local configs = self.features[feature]
		table.insert(names, feature.getHash(configs))
	end
	return table.concat(names, "+")
end

---@param shader love.Shader
---@return table
local function createBuffer(shader)
	local fmt = shader:getBufferFormat("material_buffer")
	return love.graphics.newBuffer(fmt, #fmt, { shaderstorage = true })
end

function Material:updateShader()
	self.is_dirty = false

	if not next(self.features) then
		return
	end

	if self.requires_sorting then
		self.requires_sorting = false
		self.sorted_features = {}
		for feature, _ in pairs(self.features) do
			table.insert(self.sorted_features, feature)
		end
		table.sort(self.sorted_features, sort_func)
	end

	local hash = self:getShaderHash(sorted)

	if hash ~= self.shader_hash then
		if self.ssbo then
			self.ssbo:release()
		end

		local shader_code = ShaderCode()

		for _, feature in ipairs(self.sorted_features) do
			shader_code:addFeature(feature, self.features[feature])
		end

		local valid, code = shader_code:build()

		if not valid then
			-- TODO: Use fallback shader	
		else
			local shader = love.graphics.newShader(code)
			print(code)
			self.shader, self.ssbo = shader, createBuffer(shader)
		end
	end

	local ssbo_data = {}

	for _, feature in ipairs(self.sorted_features) do
		local config = self.features[feature]
		for _, v in ipairs(config) do
			feature.packArrayData(v, ssbo_data)
		end
	end

	self.ssbo:setArrayData(ssbo_data)
end

return Material
