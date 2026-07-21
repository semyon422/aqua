local json = require("json")

local test = {}

---@param t testing.T
function test.encodes_primitives_and_strings(t)
	t:eq(json.encode(nil), "null")
	t:eq(json.encode(json.null), "null")
	t:eq(json.encode(true), "true")
	t:eq(json.encode(false), "false")
	t:eq(json.encode(12.5), "12.5")
	t:eq(json.encode("a\n\t\0\"\\"), '"a\\n\\t\\u0000\\"\\\\"')
end

---@param t testing.T
function test.distinguishes_objects_and_arrays(t)
	t:eq(json.encode({}), "[]")
	t:eq(json.encode(json.object()), "{}")
	t:eq(json.encode(json.array()), "[]")
	t:has_error(json.object, false)
	t:has_error(json.array, false)
	t:eq(json.encode({1, 2}), "[1,2]")
	t:eq(json.encode({b = 2, a = 1}), '{"a":1,"b":2}')

	local object = json.decode("{}")
	local array = json.decode("[]")
	t:eq(json.isObject(object), true)
	t:eq(json.isArray(array), true)
	t:eq(json.encode(object), "{}")
	t:eq(json.encode(array), "[]")
end

---@param t testing.T
function test.decodes_values_and_unicode(t)
	local value = json.decode([[{"array":[1,null,true,false],"text":"\u20ac \ud83d\ude00"}]])
	t:eq(value.array[1], 1)
	t:eq(value.array[2], json.null)
	t:eq(value.array[3], true)
	t:eq(value.array[4], false)
	t:eq(value.text, "€ 😀")
	t:eq(json.encode(json.decode(json.encode(value))), json.encode(value))
end

---@param t testing.T
function test.validates_input(t)
	for _, source in ipairs({
		"",
		"01",
		"1.",
		"1e",
		"+1",
		"[1,]",
		'{"a":1,}',
		'"\n"',
		'"\\ud800"',
		'"\\udc00"',
		"true false",
	}) do
		t:has_error(json.decode, source)
	end
	local value, err = json.decode_safe("{")
	t:eq(value, nil)
	t:assert(type(err) == "string")
end

---@param t testing.T
function test.validates_output(t)
	local circular = {}
	circular.self = circular
	t:has_error(json.encode, circular)
	t:has_error(json.encode, {[1] = "a", [3] = "c"})
	t:has_error(json.encode, {[1] = "a", [2] = "b", [4] = "d"})
	t:has_error(json.encode, {[1] = "a", key = "value"})
	t:has_error(json.encode, 0 / 0)
	t:has_error(json.encode, math.huge)
	t:has_error(json.encode, function() end)
end

---@param t testing.T
function test.pretty_encoding(t)
	local value = json.object({
		a = {1, 2},
		b = json.object({enabled = true}),
	})
	local expected = [[{
	"a": [
		1,
		2
	],
	"b": {
		"enabled": true
	}
}]]

	t:eq(json.encode(value, {indent = "\t"}), expected)
	t:tdeq(json.decode(json.encode(value, {indent = "\t"})), value)
	t:has_error(json.encode, value, {indent = ""})
end

return test
