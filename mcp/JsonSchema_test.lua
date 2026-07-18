local JsonSchema = require("mcp.JsonSchema")

local test = {}

---@param t testing.T
function test.validates_object_properties(t)
	local schema = {
		type = "object",
		properties = {
			name = {type = "string"},
			count = {type = "integer", minimum = 1, maximum = 10},
		},
		required = {"name"},
		additionalProperties = false,
	}

	t:assert(JsonSchema.validate(schema, {name = "test", count = 2}))
	local _, missing_err = JsonSchema.validate(schema, {count = 2})
	t:eq(missing_err, "$.name is required")
	local _, type_err = JsonSchema.validate(schema, {name = "test", count = 2.5})
	t:eq(type_err, "$.count must match type integer")
	local _, additional_err = JsonSchema.validate(schema, {name = "test", extra = true})
	t:eq(additional_err, "$.extra is not allowed")
end

---@param t testing.T
function test.validates_arrays_and_enums(t)
	local schema = {
		type = "array",
		minItems = 1,
		maxItems = 2,
		items = {type = "string", enum = {"a", "b"}},
	}

	t:assert(JsonSchema.validate(schema, {"a", "b"}))
	local _, enum_err = JsonSchema.validate(schema, {"c"})
	t:eq(enum_err, "$[1] must match an enum value")
	local _, size_err = JsonSchema.validate(schema, {})
	t:eq(size_err, "$ must contain at least 1 items")
end

---@param t testing.T
function test.validates_additional_property_schema(t)
	local schema = {
		type = "object",
		additionalProperties = {type = "boolean"},
	}

	t:assert(JsonSchema.validate(schema, {first = true, second = false}))
	local _, err = JsonSchema.validate(schema, {first = "yes"})
	t:eq(err, "$.first must match type boolean")
end

return test
