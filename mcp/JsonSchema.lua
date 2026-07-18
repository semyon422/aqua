local table_util = require("table_util")

local JsonSchema = {}

---@param a any
---@param b any
---@return boolean
local function values_equal(a, b)
	if type(a) == "table" and type(b) == "table" then
		return table_util.deepequal(a, b)
	end
	return a == b
end

---@param value any
---@param expected string
---@return boolean
local function matches_type(value, expected)
	if expected == "integer" then
		return type(value) == "number" and value % 1 == 0
	elseif expected == "number" then
		return type(value) == "number"
	elseif expected == "object" or expected == "array" then
		return type(value) == "table"
	end
	return type(value) == expected
end

---@param schema_type string|string[]
---@param value any
---@return boolean
local function matches_schema_type(schema_type, value)
	if type(schema_type) == "string" then
		return matches_type(value, schema_type)
	end
	for _, expected in ipairs(schema_type) do
		if matches_type(value, expected) then
			return true
		end
	end
	return false
end

---@param path string
---@param message string
---@return nil
---@return string
local function validation_error(path, message)
	return nil, path .. " " .. message
end

---@param schema table|boolean
---@param value any
---@param path string?
---@return true?
---@return string?
function JsonSchema.validate(schema, value, path)
	path = path or "$"
	if schema == true then
		return true
	elseif schema == false then
		return validation_error(path, "is not allowed")
	elseif type(schema) ~= "table" then
		return validation_error(path, "has an invalid schema")
	end

	local schema_type = schema.type
	if schema_type ~= nil then
		if type(schema_type) ~= "string" and type(schema_type) ~= "table" then
			return validation_error(path, "has an invalid type constraint")
		end
		if not matches_schema_type(schema_type, value) then
			return validation_error(path, "must match type " .. (type(schema_type) == "string" and schema_type or "union"))
		end
	end

	if schema.enum then
		local found = false
		for _, enum_value in ipairs(schema.enum) do
			if values_equal(value, enum_value) then
				found = true
				break
			end
		end
		if not found then
			return validation_error(path, "must match an enum value")
		end
	end

	if type(value) == "number" then
		if schema.minimum ~= nil and value < schema.minimum then
			return validation_error(path, "must be at least " .. schema.minimum)
		end
		if schema.maximum ~= nil and value > schema.maximum then
			return validation_error(path, "must be at most " .. schema.maximum)
		end
	end

	if type(value) ~= "table" then
		return true
	end

	if schema_type == "array" then
		local size = #value
		if schema.minItems ~= nil and size < schema.minItems then
			return validation_error(path, "must contain at least " .. schema.minItems .. " items")
		end
		if schema.maxItems ~= nil and size > schema.maxItems then
			return validation_error(path, "must contain at most " .. schema.maxItems .. " items")
		end
		if schema.items then
			for index, item in ipairs(value) do
				local ok, err = JsonSchema.validate(schema.items, item, ("%s[%d]"):format(path, index))
				if not ok then
					return nil, err
				end
			end
		end
		return true
	end

	local properties = schema.properties or {}
	for _, key in ipairs(schema.required or {}) do
		if value[key] == nil then
			return validation_error(path .. "." .. key, "is required")
		end
	end
	for key, property_value in pairs(value) do
		local property_schema = properties[key]
		if property_schema then
			local ok, err = JsonSchema.validate(property_schema, property_value, path .. "." .. key)
			if not ok then
				return nil, err
			end
		elseif schema.additionalProperties == false then
			return validation_error(path .. "." .. tostring(key), "is not allowed")
		elseif type(schema.additionalProperties) == "table" or type(schema.additionalProperties) == "boolean" then
			local ok, err = JsonSchema.validate(schema.additionalProperties, property_value, path .. "." .. tostring(key))
			if not ok then
				return nil, err
			end
		end
	end
	return true
end

return JsonSchema
