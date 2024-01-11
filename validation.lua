local utf8validate = require("utf8validate")

local validation = {}

local validators = {}

function validators.string(v) return type(v) == "string" end
function validators.number(v) return type(v) == "number" end
function validators.boolean(v) return type(v) == "boolean" end
function validators.integer(v) return math.floor(v) == v end

validators["#"] = function(v, a, b)
	b = b or a
	return #v >= a and #v <= b
end
validators["between"] = function(v, a, b)
	b = b or a
	return v >= a and v <= b
end
validators["*"] = function(v, ...)
	for i = 1, select("#", ...) do
		if not validation.validate(v, select(i, ...)) then
			return false
		end
	end
	return true
end

function validators.utf8(v)
	return utf8validate(v) == v
end

function validators.one_of(v, ...)
	for i = 1, select("#", ...) do
		if v == select(i, ...) then
			return true
		end
	end
	return false
end

function validators.array_of(v, schema)
	for _, _v in ipairs(v) do
		if not validation.validate(_v, schema) then
			return false
		end
	end
	return true
end

function validation.validate(value, schema)
	if type(schema) == "string" then
		if not validators[schema](value) then
			return false
		end
		return true
	end
	if schema[1] then
		if not validators[schema[1]](value, unpack(schema, 2)) then
			return false
		end
		return true
	end
	for k, _schema in pairs(schema) do
		if not validation.validate(value[k], _schema) then
			return false
		end
	end
	return true
end

return validation
