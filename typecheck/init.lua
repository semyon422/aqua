local AnyType = require("typecheck.AnyType")
local ArrayType = require("typecheck.ArrayType")
local ClassType = require("typecheck.ClassType")
local CType = require("typecheck.CType")
local Type = require("typecheck.Type")
local UnionType = require("typecheck.UnionType")

local lexer = require("typecheck.lexer")

local typecheck = {}

typecheck.strict = false

typecheck.AnyType = AnyType
typecheck.ArrayType = ArrayType
typecheck.ClassType = ClassType
typecheck.CType = CType
typecheck.Type = Type
typecheck.UnionType = UnionType

function typecheck.register_class(_type, T)
	ClassType.register_class(_type, T)
end

function typecheck.parse_def(signature)
	local def = {
		name = "?",
		is_method = false,
		param_names = {},
		param_types = {},
		return_types = {},
	}

	local tokens, err = lexer.lex(signature)
	if not tokens then
		return nil, err
	end

	tokens:_push()
	local name, is_method = tokens:parse_func_name()
	if not name or tokens.token and tokens.token.type ~= "leftparan" then
		tokens:_pop()
		tokens:_push()
		name, is_method = tokens:parse_name_novararg(), nil
	end
	tokens:_pop(true)
	if name then
		def.name = name
		def.is_method = is_method
	end

	local param_names, param_types = tokens:parse_params()
	if not param_names then
		return nil, param_types
	end

	def.param_names = param_names
	def.param_types = param_types

	if not tokens.token then
		return def
	end
	if tokens.token.type ~= "colon" then
		return nil, tokens:get_token_error()
	end

	tokens:step()

	if not tokens.token then
		return nil, tokens:get_token_error()
	end

	local return_types, err = tokens:parse_types()
	if not return_types then
		return nil, err
	end
	def.return_types = return_types

	return def
end

function typecheck.encode_def(def)
	local out = {}

	if def.name ~= "?" then
		table.insert(out, def.name)
	end

	table.insert(out, "(")
	local params = {}
	for i = 1, #def.param_names do
		table.insert(params, ("%s: %s"):format(def.param_names[i], def.param_types[i]))
	end
	table.insert(out, table.concat(params, ", "))
	table.insert(out, ")")

	if #def.return_types == 0 then
		return table.concat(out)
	end

	table.insert(out, ": ")

	local return_types = {}
	for i = 1, #def.return_types do
		table.insert(return_types, tostring(def.return_types[i]))
	end

	table.insert(out, table.concat(return_types, ", "))

	if def.return_types.is_vararg then
		table.insert(out, "...")
	end

	return table.concat(out)
end

local function check(types, ...)
	local n = select("#", ...)

	local iter_to = #types
	if types.is_vararg then
		iter_to = math.max(iter_to - 1, n)
	elseif n > #types then
		local i = #types + 1
		return false, i, "no value", type(select(i, ...))
	end

	for i = 1, iter_to do
		local v = select(i, ...)
		local got = i <= n and type(v) or "no value"
		local _type = types[math.min(i, #types)]

		local res = false
		if i <= n then
			res = _type:check(v)
		else  -- no value
			res = _type.is_optional
		end

		if not res then
			return false, i, _type, got
		end
	end

	return true, ...
end
typecheck.check_types = check


local exp_got = "bad %s #%s to '%s' (%s expected, got %s)"
local function wrap_return(bad, name, res, ...)
	if res then
		return ...
	end
	local i, _type, got = ...
	local err = exp_got:format(bad, i, name, _type, got)
	error(err, 3)
end

local function get_args(...)
	return ...
end

local function get_method_args(_, ...)
	return ...
end

---@generic T
---@param f T
---@param signature string
---@return T f
function typecheck.decorate(f, signature)
	local s = assert(typecheck.parse_def(signature))

	local _get_args = get_args
	if s.is_method then
		_get_args = get_method_args
	end

	local name = s.name
	local ptypes = s.param_types
	local rtypes = s.return_types

	return function(...)
		wrap_return("argument", name, check(ptypes, _get_args(...)))
		return wrap_return("returning value", name, check(rtypes, f(...)))
	end
end

function typecheck.fix_traceback(s)
	s = s:gsub("(\t[^\t]+): in function 'f'\n\t[^\t]+/typecheck%.lua:%w+: in function '([^']+)'\n", function(p, f)
		return ("%s: in function '%s'\n"):format(p, f)
	end)
	s = s:gsub("\n[^\n]+\n[^\n]+in function 'wrap_return'\n[^\n]+\n", "\n")
	return s
end

return typecheck
