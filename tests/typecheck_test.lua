local typecheck = require("typecheck")
local lexer = require("typecheck.lexer")
local class = require("class")
local TypeDecorator = require("typecheck.TypeDecorator")
local ClassDecorator = require("typecheck.ClassDecorator")

local test = {}

local function lex(...)
	return assert(lexer.lex(...))
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

function test.lex_unknown()
	assert(not lexer.lex("&"))
end

function test.lex_tokens_count()
	local tokens = lex("a ( ) ... [] : . , ? |")
	assert(#tokens == 10)
end

function test.lex_token_tostring(t)
	local tokens = lex("a b c")
	assert(tostring(tokens[2]) == "3 id b")
end

function test.parse_no_tokens()
	local tokens = lex("")
	assert(not tokens:parse_func_name())
	assert(not tokens:parse_name())
	assert(not tokens:parse_name_novararg())
	assert(not tokens:parse_param())
	assert(not tokens:parse_params())
	assert(not tokens:parse_type())
	assert(not tokens:parse_type_union())
	assert(not tokens:parse_types())
end

function test.parse_func_name_point()
	local tokens = lex("a.b")
	local name, is_method = tokens:parse_func_name()
	assert(not is_method)
	assert(name == "a.b")
end

function test.parse_func_name_colon()
	local tokens = lex("a:b")
	local name, is_method = tokens:parse_func_name()
	assert(is_method)
	assert(name == "a:b")
end

function test.parse_func_name_unexpected()
	local tokens = lex("a:?")
	local name, err = tokens:parse_func_name()
	assert(not name)
	assert(err == "unexpected token '?' at position 3")
end

function test.parse_name_novararg()
	local tokens = lex("a.b.c")
	local name = tokens:parse_name_novararg()
	assert(name == "a.b.c")
end

function test.parse_name_novararg_invalid()
	local tokens = lex("a.b.")
	local name, err = tokens:parse_name_novararg()
	assert(err == "token expected")
end

function test.parse_name_novararg_unexpected_question()
	local tokens = lex("a.?")
	local name, err = tokens:parse_name_novararg()
	assert(err == "unexpected token '?' at position 3")
end

function test.parse_name_novararg_unexpected_vararg()
	local tokens = lex("...")
	local name, err = tokens:parse_name_novararg()
	assert(err == "unexpected token '...' at position 1")
end

function test.parse_name_vararg()
	local tokens = lex("...")
	local name = tokens:parse_name()
	assert(name == "...")
end

function test.parse_type_number()
	local tokens = lex("number")
	local t = tokens:parse_type()
	assert(typeof(t, typecheck.Type))
	assert(tostring(t) == "number")
end

function test.parse_type_missing_paran()
	local tokens = lex("(number")
	local t, err = tokens:parse_type()
	assert(err == "token expected")
end

function test.parse_type_unexpected_vararg()
	local tokens = lex("(number...")
	local t, err = tokens:parse_type()
	assert(err == "unexpected token '...' at position 8")
end

function test.parse_type_array_of_arrays()
	local tokens = lex("[][]number")
	local t = assert(tokens:parse_type())
	assert(typeof(t, typecheck.ArrayType))
	assert(typeof(t.type, typecheck.ArrayType))
	assert(typeof(t.type.type, typecheck.Type))
	assert(tostring(t) == "[][]number")
end

function test.parse_type_array_of_arrays_alternative()
	local tokens = lex("number[][]") -- support both variants
	local t = assert(tokens:parse_type())
	assert(typeof(t, typecheck.ArrayType))
	assert(typeof(t.type, typecheck.ArrayType))
	assert(typeof(t.type.type, typecheck.Type))
	assert(tostring(t) == "[][]number")
end

function test.parse_types()
	local tokens = lex("number, string")
	local types = assert(tokens:parse_types())
	assert(#types == 2)
	assert(typeof(types[1], typecheck.Type))
	assert(typeof(types[2], typecheck.Type))
end

function test.parse_types_vararg()
	local tokens = lex("number, string...")
	local types = assert(tokens:parse_types())
	assert(#types == 2)
	assert(types.is_vararg)
end

function test.parse_types_invalid()
	local tokens = lex("()")
	assert(not tokens:parse_types())
end

function test.parse_type_union_optional()
	local tokens = lex("string?")
	local t = assert(tokens:parse_type_union())
	assert(#t == 1)
	assert(t.is_optional)
	assert(typeof(t, typecheck.UnionType))
	assert(tostring(t) == "string?")
	assert(tostring(t[1]) == "string")
end

function test.parse_type_union_empty_unexpected()
	local tokens = lex("()")
	local t, err = tokens:parse_type_union()
	assert(err == "unexpected token ')' at position 2")
end

function test.parse_type_union_in_paran()
	local tokens = lex("(number)")
	local t = assert(tokens:parse_type_union())
	assert(not tokens.token)
end

function test.parse_type_union_paran_opt()
	local tokens = lex("(number|string?)")
	local t = assert(tokens:parse_type_union())
	assert(t.is_optional)
	assert(typeof(t, typecheck.UnionType))
end

function test.parse_type_union_array()
	local tokens = lex("[](number|string)")
	local t = assert(tokens:parse_type_union())
	assert(typeof(t, typecheck.ArrayType))
	assert(typeof(t.type, typecheck.UnionType))
	assert(typeof(t.type[1], typecheck.Type))
	assert(typeof(t.type[2], typecheck.Type))
	assert(t.type[1].type == "number")
	assert(t.type[2].type == "string")
end

function test.parse_type_union_complex_1()
	local tokens = lex("(number|string)|(number|string)")
	local t = assert(tokens:parse_type_union())
end

function test.parse_type_union_complex_2()
	local tokens = lex("(number|(number|(number|(string))))")
	local t = assert(tokens:parse_type_union())
end

function test.parse_type_union_complex_3()
	local tokens = lex("[]([](string|number)|number)")
	local t = assert(tokens:parse_type_union())
end

--------------------------------------------------------------------------------

function test.parse_param()
	local tokens = lex("a: number")
	local param_name, param_type = tokens:parse_param()
	assert(param_name == "a")
	assert(typeof(param_type, typecheck.Type))
end

function test.parse_param_vararg()
	local tokens = lex("...: number")
	local param_name, param_type, is_vararg = tokens:parse_param()
	assert(param_name == "...")
	assert(is_vararg)
	assert(typeof(param_type, typecheck.Type))
end

function test.parse_param_missing_type()
	local tokens = lex("a:")
	local param_name, param_type, is_vararg = tokens:parse_param()
	assert(param_type == "token expected")
end

function test.parse_param_unexpected()
	local tokens = lex("a: ?")
	local param_name, param_type, is_vararg = tokens:parse_param()
	assert(param_type == "unexpected token '?' at position 4")
end

function test.parse_param_invalid_name()
	local tokens = lex("?")
	assert(not tokens:parse_param())
end

function test.parse_param_invalid_colon()
	local tokens = lex("a ?")
	assert(not tokens:parse_param())
end

function test.parse_params()
	local tokens = lex("(a: number, b: string)")
	local param_names, param_types = tokens:parse_params()
	assert(#param_names == 2)
end

function test.parse_params_vararg()
	local tokens = lex("(a: number, ...: string)")
	local param_names, param_types = tokens:parse_params()
	assert(param_names and param_types)
	assert(#param_names == 2)
	assert(param_types.is_vararg)
end

function test.parse_params_unexpected_vararg()
	local tokens = lex("(...: number...)")
	local param_names, param_types = tokens:parse_params()
	assert(param_types == "unexpected token '...' at position 13")
end

function test.parse_params_many_vararg()
	local tokens = lex("(...: number, ...: number)")
	local param_names, param_types = tokens:parse_params()
	assert(param_types == "unexpected token ',' at position 13")
end

function test.parse_params_no_paran()
	local tokens = lex("a")
	assert(not tokens:parse_params())
end

function test.parse_params_invalid_param()
	local tokens = lex("(?)")
	assert(not tokens:parse_params())
end

function test.parse_params_missing_comma()
	local tokens = lex("(a: a b)")
	assert(not tokens:parse_params())
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

function test.parse_types_multiple()
	assert_parse_types("number, string", 1, "q")

	assert_not_parse_types("number")
	assert_parse_types("number", 1)
	assert_not_parse_types("number", 1, 2, 3)

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

	assert(typecheck.parse_def("test(): number"))
	assert(typecheck.parse_def("mod.test(): number"))
	assert(typecheck.parse_def("(): number"))
	assert(typecheck.parse_def("()"))

	assert(not typecheck.parse_def("&"))
	assert(not typecheck.parse_def("a"))
	assert(not typecheck.parse_def("a()?"))
	assert(not typecheck.parse_def("a():"))
	assert(not typecheck.parse_def("a():?"))
end

function test.parse_types_class()
	local MyClass = class()
	local obj = MyClass()

	local ok, err = pcall(assert_parse_types, "mod.A", obj)
	assert(not ok and err and err:find("not registered"))

	typecheck.register_class("mod.A", MyClass)
	assert_parse_types("mod.A", obj)
end

function test.parse_types_no_comma()
	local tokens = lex("number string")
	local types = tokens:parse_types()
	assert(#types == 1)
end

function test.decorated_with_class()
	local def = "mod.test(a: number|string?, b: []mod.B, ...: function): [][]number, string|number?, mod.B, table..."

	local MyClass = class()
	typecheck.register_class("mod.B", MyClass)

	local function f(a, b, ...)
		return {{1}}, nil, MyClass()
	end
	f = typecheck.decorate(f, def)

	f(nil, {MyClass()})

	local ok = pcall(f, false)
	assert(not ok)

	assert(def == typecheck.encode_def(typecheck.parse_def(def)))
end

function test.decorated_with_ctype()
	local def = "mod.test(a: ffi.cdata*): ffi.cdata*"

	local parsed = assert(typecheck.parse_def(def))
	assert(def == typecheck.encode_def(parsed))

	local function f(a)
		return a
	end
	f = typecheck.decorate(f, def)

	f(1ull)
end

function test.decorated_simple()
	local def = "mod:test(a: number): number"

	local parsed = assert(typecheck.parse_def(def))
	assert(parsed.is_method)

	assert(def == typecheck.encode_def(parsed))

	local function f(self, a)
		return a
	end
	f = typecheck.decorate(f, def)

	f(nil, 1)
end

function test.fix_traceback_wrap_return()
	local traceback = [[

aaa
bbb in function 'wrap_return'
ccc
]]
	local expected = [[

]]

	assert(typecheck.fix_traceback(traceback) == expected)
end

function test.fix_traceback_typecheck()
	local traceback = [[
	aaa: in function 'f'
	bbb /typecheck.lua:000: in function 'ccc'
]]
	local expected = [[
	aaa: in function 'ccc'
]]

	assert(typecheck.fix_traceback(traceback) == expected)
end

function test.type_decorator_empty()
	local td = TypeDecorator()

	local strict = typecheck.strict
	typecheck.strict = false

	td:func_begin()
	assert(not td:func_end("test"))

	typecheck.strict = strict
end

function test.type_decorator_number_number()
	local td = TypeDecorator()

	td:func_begin()
	td:process_annotation("---@param a number")
	td:process_annotation("---@return number")

	local expected = [[test = require("typecheck").decorate(test, "test(a: number): number")]]
	assert(td:func_end("test") == expected)
end

function test.type_decorator_vararg()
	local td = TypeDecorator()

	td:func_begin()
	td:process_annotation("---@return any?...")

	local expected = [[test = require("typecheck").decorate(test, "test(): any?...")]]
	assert(td:func_end("test") == expected)
end

function test.class_decorator()
	local cd = ClassDecorator()

	cd:next("---@class mod.MyClass")
	local got = cd:next("local MyClass = class()")
	local expected = [[require("typecheck").register_class("mod.MyClass", MyClass)]]

	assert(got == expected)
end

return test
