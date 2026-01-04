local class = require("class")

---@class ui.IFeature
--- Static base class for all features. DO NOT STORE ANY STATE.
local IFeature = class()

---@class ui.FeatureConfig : {[string]: any}

IFeature.id = "feature_id"
IFeature.layer = 1

---@param configs ui.FeatureConfig
function IFeature.validateConfig(config)
	error("Not implemented")
end

---@param configs ui.FeatureConfig[]
---@return string
function IFeature.getHash(configs)
	error("Not implemented")
end

---@param configs ui.FeatureConfig[]
---@param shader_code ui.Shader.Code
function IFeature.build(configs, shader_code)
	error("Not implemented")
end

---@param dest table
---@param src table
function IFeature.tableInsertArray(dest, src)
	for _, v in ipairs(src) do
		table.insert(dest, v)
	end
end

---@param config table
---@param data number[]
function IFeature.packArrayData(config, data) end

return IFeature
