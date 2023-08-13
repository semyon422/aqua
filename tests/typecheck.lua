local typecheck = require("typecheck")
local class = require("class")

local function lex(...)
	return assert(typecheck.lex(...))
end

local function typeof(t, T)
	return T * t
end

local function check_types(...)
	local res, i, _type, got = typecheck.check_types(...)
	if res then
		return res
	end
	return nil, ("bad argument #%s (%s expected, got %s)"):format(i, _type, got)
end

do
	local tokens = lex("a ( ) ... [] : . , ? |")
	assert(#tokens == 10)
end

do
	local tokens = lex("a.b")
	local name, is_method = tokens:parse_func_name()
	assert(not is_method)
	assert(name == "a.b")
end

do
	local tokens = lex("a:b")
	local name, is_method = tokens:parse_func_name()
	assert(is_method)
	assert(name == "a:b")
end

do
	local tokens = lex("a.b.c")
	local name = tokens:parse_name_novararg()
	assert(name == "a.b.c")
end

do
	local tokens = lex("a.b.")
	local name, err = tokens:parse_name_novararg()
	assert(err == "token expected")
end

do
	local tokens = lex("a.?")
	local name, err = tokens:parse_name_novararg()
	assert(err == "unexpected token '?' at position 3")
end

do
	local tokens = lex("...")
	local name, err = tokens:parse_name_novararg()
	assert(err == "unexpected token '...' at position 1")
end

do
	local tokens = lex("...")
	local name = tokens:parse_name()
	assert(name == "...")
end

do
	local tokens = lex("number")
	local t = tokens:parse_type()
	assert(typeof(t, typecheck.Type))
	assert(tostring(t) == "number")
end

do
	local tokens = lex("(number")
	local t, err = tokens:parse_type()
	assert(err == "token expected")
end

do
	local tokens = lex("(number...")
	local t, err = tokens:parse_type()
	assert(err == "unexpected token '...' at position 8")
end

do
	local tokens = lex("[][]number")
	local t = assert(tokens:parse_type())
	assert(typeof(t, typecheck.ArrayType))
	assert(typeof(t.type, typecheck.ArrayType))
	assert(typeof(t.type.type, typecheck.Type))
	assert(tostring(t) == "[][]number")
end

do
	local tokens = lex("number, string")
	local types = assert(tokens:parse_types())
	assert(#types == 2)
	assert(typeof(types[1], typecheck.Type))
	assert(typeof(types[2], typecheck.Type))
end

do
	local tokens = lex("number, string...")
	local types = assert(tokens:parse_types())
	assert(#types == 2)
	assert(types.is_vararg)
end

do
	local tokens = lex("string?")
	local t = assert(tokens:parse_type_union())
	assert(#t == 1)
	assert(t.is_optional)
	assert(typeof(t, typecheck.UnionType))
	assert(tostring(t) == "string?")
	assert(tostring(t[1]) == "string")
end

do
	local tokens = lex("()")
	local t, err = tokens:parse_type_union()
	assert(err == "unexpected token ')' at position 2")
end

do
	local tokens = lex("(number)")
	local t = assert(tokens:parse_type_union())
	assert(not tokens.token)
end

do
	local tokens = lex("(number|string?)")
	local t = assert(tokens:parse_type_union())
	assert(t.is_optional)
	assert(typeof(t, typecheck.UnionType))
end

do
	local tokens = lex("[](number|string)")
	local t = assert(tokens:parse_type_union())
	assert(typeof(t, typecheck.ArrayType))
	assert(typeof(t.type, typecheck.UnionType))
	assert(typeof(t.type[1], typecheck.Type))
	assert(typeof(t.type[2], typecheck.Type))
	assert(t.type[1].type == "number")
	assert(t.type[2].type == "string")
end

do
	local tokens = lex("(number|string)|(number|string)")
	local t = assert(tokens:parse_type_union())
end

do
	local tokens = lex("(number|(number|(number|(string))))")
	local t = assert(tokens:parse_type_union())
end

do
	local tokens = lex("[]([](string|number)|number)")
	local t = assert(tokens:parse_type_union())
end

--------------------------------------------------------------------------------

do
	local tokens = lex("a: number")
	local param_name, param_type = tokens:parse_param()
	assert(param_name == "a")
	assert(typeof(param_type, typecheck.Type))
end

do
	local tokens = lex("...: number")
	local param_name, param_type, is_vararg = tokens:parse_param()
	assert(param_name == "...")
	assert(is_vararg)
	assert(typeof(param_type, typecheck.Type))
end

do
	local tokens = lex("a:")
	local param_name, param_type, is_vararg = tokens:parse_param()
	assert(param_type == "token expected")
end

do
	local tokens = lex("a: ?")
	local param_name, param_type, is_vararg = tokens:parse_param()
	assert(param_type == "unexpected token '?' at position 4")
end

do
	local tokens = lex("(a: number, b: string)")
	local param_names, param_types = tokens:parse_params()
	assert(#param_names == 2)
end

do
	local tokens = lex("(a: number, ...: string)")
	local param_names, param_types = tokens:parse_params()
	assert(param_names and param_types)
	assert(#param_names == 2)
	assert(param_types.is_vararg)
end

do
	local tokens = lex("(...: number...)")
	local param_names, param_types = tokens:parse_params()
	assert(param_types == "unexpected token '...' at position 13")
end

do
	local tokens = lex("(...: number, ...: number)")
	local param_names, param_types = tokens:parse_params()
	assert(param_types == "unexpected token ',' at position 13")
end

local function assert_parse_types(s, ...)
	local tokens = lex(s)
	local types = tokens:parse_types()
	assert(check_types(types, ...))
end

local function assert_not_parse_types(s, ...)
	local tokens = lex(s)
	local types = tokens:parse_types()
	assert(not check_types(types, ...))
end

assert_parse_types("number, string", 1, "q")

assert_not_parse_types("number")
assert_parse_types("number", 1)
assert_parse_types("number", 1, 2, 3)

assert_not_parse_types("number|nil")
assert_parse_types("number|nil", nil)
assert_parse_types("number|nil", 1)

-- t? = t | nil | no value

assert_parse_types("number?")
assert_parse_types("number?", nil)
assert_parse_types("number?", 1)

-- t... = t | no value

assert_parse_types("number...")
assert_parse_types("number...", 1)
assert_parse_types("number...", 1, 2)
assert_not_parse_types("number...", nil)
assert_not_parse_types("number...", 1, nil)

-- t?... = t | nil | no value, t?...

assert_parse_types("number?...")
assert_parse_types("number?...", nil)
assert_parse_types("number?...", 1, nil)

assert_not_parse_types("any")
assert_parse_types("any", 1)
assert_parse_types("any", "q")

assert_not_parse_types("any", nil)
assert_parse_types("any?", nil)
assert_parse_types("any...")
assert_not_parse_types("any...", nil)
assert_parse_types("any?...", nil)

do
	local MyClass = class()
	local obj = MyClass()

	assert_not_parse_types("MyClass", obj)
	typecheck.register_class("MyClass", MyClass)
	assert_parse_types("MyClass", obj)
end

do
	local tokens = lex("number string")
	local types = tokens:parse_types()
	assert(#types == 1)
end

assert(typecheck.parse_def("test(): number"))
assert(typecheck.parse_def("mod.test(): number"))
assert(typecheck.parse_def("(): number"))
assert(typecheck.parse_def("()"))

do
	local def = "mod.test(a: number|string?, b: []MyClass, ...: function): [][]number, string|number?, MyClass, table..."

	local MyClass = class()
	typecheck.register_class("MyClass", MyClass)

	local function test(a, b, ...)
		return {{1}}, nil, MyClass()
	end
	test = typecheck.decorate(test, def)

	test(nil, {MyClass()})

	assert(def == typecheck.encode_def(typecheck.parse_def(def)))
end

do
	local def = "mod:test(a: number): number"

	local parsed = assert(typecheck.parse_def(def))
	assert(parsed.is_method)

	assert(def == typecheck.encode_def(parsed))

	local function test(self, a)
		return a
	end
	test = typecheck.decorate(test, def)

	test(nil, 1)
end
