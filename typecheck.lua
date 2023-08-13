local class = require("class")

local typecheck = {}

---@class typecheck.Type
---@field type string
---@operator call: typecheck.Type
local Type = class()
typecheck.Type = Type

function Type:new(_type)
	self.type = _type
end

function Type:check(value)
	return type(value) == self.type
end

function Type.__tostring(t)
	return t.type
end

---@class typecheck.AnyType: typecheck.Type
---@operator call: typecheck.AnyType
local AnyType = class()
typecheck.AnyType = AnyType

function AnyType:check(value)
	return value ~= nil
end

function AnyType.__tostring()
	return "any"
end

---@class typecheck.ClassType: typecheck.Type
---@operator call: typecheck.ClassType
local ClassType = class()
typecheck.ClassType = ClassType

function ClassType:new(name, T)
	self.name = name
	self.type = T
end

function ClassType:check(value)
	return self.type * value
end

function ClassType.__tostring(t)
	return t.name
end

---@class typecheck.ArrayType: typecheck.Type
---@field type typecheck.Type
---@operator call: typecheck.ArrayType
local ArrayType = class(Type)
typecheck.ArrayType = ArrayType

function ArrayType:check(value)
	return not value[1] or self.type:check(value[1])
end

function ArrayType.__tostring(t)
	return "[]" .. tostring(t.type)
end

---@class typecheck.UnionType: typecheck.Type
---@field is_optional boolean
---@operator call: typecheck.UnionType
local UnionType = class(Type)
typecheck.UnionType = UnionType

function UnionType:check(value)
	if value == nil and self.is_optional then
		return true
	end
	for _, _type in ipairs(self) do
		if _type:check(value) then
			return true
		end
	end
	return false
end

function UnionType.__tostring(t)
	local out = {}
	for i, v in ipairs(t) do
		out[i] = tostring(v)
	end
	local s = table.concat(out, "|")
	if t.is_optional then
		s = s .. "?"
	end
	return s
end

--------------------------------------------------------------------------------

---@class typecheck.Token
---@field pos integer
---@field type string
---@field value string
---@operator call: typecheck.Token
local Token = class()

function Token:new(type, value, pos)
	self.type = type
	self.value = value
	self.pos = pos
end

function Token.__tostring(t)
	return ("%s %s %s"):format(t.pos, t.type, t.value)
end

--------------------------------------------------------------------------------

local parse_error = "unexpected token '%s' at position %s"
local function get_token_error(token)
	if not token then
		return "token expected"
	end
	return parse_error:format(token.value, token.pos)
end

--------------------------------------------------------------------------------

---@class typecheck.Tokens
---@field pos integer
---@field stack number[]
---@field [number] typecheck.Token
---@operator call: typecheck.Tokens
local Tokens = class()

function Tokens:new()
	self.stack = {}
	self.pos = 1
end

function Tokens:_push()
	table.insert(self.stack, self.pos)
end

function Tokens:_pop(save)
	if save then
		table.remove(self.stack)
		return
	end
	local token = self.token
	self.pos = table.remove(self.stack)
	self.token = self[self.pos]
	return token
end

function Tokens:step()
	self.pos = self.pos + 1
	self.token = self[self.pos]
end

function Tokens:parse_func_name()
	if not self.token or self.token.type ~= "id" then
		return nil, get_token_error(self.token)
	end

	self:_push()

	local name = self.token.value
	self:step()

	if self.token.type ~= "colon" and self.token.type ~= "point" then
		self:_pop(true)
		return name
	end

	local out = {name, self.token.value}

	local is_method = false
	if self.token.type == "colon" then
		is_method = true
	end

	self:step()

	if self.token.type ~= "id" then
		return nil, get_token_error(self:_pop())
	end

	out[3] = self.token.value
	self:step()

	self:_pop(true)

	return table.concat(out), is_method
end

function Tokens:parse_name_novararg()
	if not self.token or self.token.type ~= "id" then
		return nil, get_token_error(self.token)
	end

	self:_push()

	local name = ""
	local next_type = "id"
	while self.token and self.token.type == next_type do
		name = name .. self.token.value
		self:step()
		next_type = next_type ~= "point" and "point" or "id"
	end

	if next_type == "id" then
		return nil, get_token_error(self:_pop())
	end

	self:_pop(true)

	return name
end

function Tokens:parse_name()
	if not self.token then
		return nil, get_token_error()
	end

	local token = self.token
	if token.type == "vararg" then
		self:step()
		return token.value
	end

	return self:parse_name_novararg()
end

function Tokens:parse_type()
	if not self.token then
		return nil, get_token_error()
	end

	self:_push()

	local array_depth = 0
	while self.token and self.token.type == "array" do
		array_depth = array_depth + 1
		self:step()
	end

	local _type
	if self.token.type == "leftparan" then
		self:step()

		_type = self:parse_type_union()
		if not _type or not self.token or self.token.type ~= "rightparan" then
			return nil, get_token_error(self:_pop())
		end

		self:step()
	else
		local t, err = self:parse_name_novararg()
		if not t then
			self:_pop()
			return nil, err
		end
		_type = typecheck.get_type(t)
	end

	for _ = 1, array_depth do
		_type = ArrayType(_type)
	end

	self:_pop(true)

	return _type
end

function Tokens:parse_type_union()
	if not self.token then
		return nil, get_token_error()
	end

	self:_push()

	if self.token.type == "leftparan" then
		self:step()

		local union = self:parse_type_union()
		if not union or self.token.type ~= "rightparan" then
			return nil, get_token_error(self:_pop())
		end

		self:step()
		self:_pop(true)

		return union
	end

	local union = UnionType()

	local final_err
	local step = "token"
	while self.pos <= #self do
		if step == "pipe" and self.token.type == "pipe" then
			self:step()
			step = "token"
		elseif step == "token" then
			local _type, err = self:parse_type()
			if not _type then
				final_err = err
				break
			end
			table.insert(union, _type)
			step = "pipe"
		else
			break
		end
	end

	if #union == 0 then
		local t = self:_pop()
		return nil, final_err or get_token_error(t)
	end

	if self.token and self.token.type == "question" then
		union.is_optional = true
		self:step()
	end

	self:_pop(true)

	if #union == 1 and not union.is_optional then
		return union[1]
	end

	return union
end

function Tokens:parse_types()
	if not self.token then
		return nil, get_token_error()
	end

	self:_push()

	local types = {}

	local step = "type"
	while self.pos <= #self do
		local token = self.token
		if step == "comma" and token.type == "comma" then
			self:step()
			step = "type"
		elseif step == "comma" and token.type == "vararg" then
			types.is_vararg = true
			self:step()
			break
		elseif step == "type" then
			local _type, err = self:parse_type_union()
			if not _type then
				self:_pop()
				return nil, err
			end
			table.insert(types, _type)
			step = "comma"
		else
			break
		end
	end

	self:_pop(true)

	return types
end

function Tokens:parse_param()
	if not self.token then
		return nil, get_token_error()
	end

	self:_push()

	local param_name, err = self:parse_name()
	if not param_name then
		self:_pop()
		return nil, err
	end
	if self.token.type ~= "colon" then
		return nil, get_token_error(self:_pop())
	end

	self:step()

	local param_type, err = self:parse_type_union()
	if not param_type then
		self:_pop()
		return nil, err
	end

	self:_pop(true)

	return param_name, param_type, param_name == "..."
end

function Tokens:parse_params()
	if not self.token then
		return nil, get_token_error()
	end

	self:_push()

	if self.token.type ~= "leftparan" then
		return nil, get_token_error(self:_pop())
	end
	self:step()

	local param_names = {}
	local param_types = {}

	local expect_rightparan = false

	local step = "param"
	while self.pos <= #self do
		local token = self.token
		if expect_rightparan and token.type ~= "rightparan" then
			return nil, get_token_error(self:_pop())
		end
		if token.type == "rightparan" then
			self:step()
			self:_pop(true)
			return param_names, param_types
		end
		if step == "comma" and token.type == "comma" then
			self:step()
			step = "param"
		elseif step == "param" then
			local param_name, param_type, is_vararg = self:parse_param()
			if not param_name then
				self:_pop()
				return nil, param_type
			end
			table.insert(param_names, param_name)
			table.insert(param_types, param_type)
			if is_vararg then
				param_types.is_vararg = is_vararg
				expect_rightparan = true
			end
			step = "comma"
		else
			return nil, get_token_error(self:_pop())
		end
	end

	self:_pop(true)

	return param_names, param_types
end

--------------------------------------------------------------------------------

local token_patterns = {
	{"id", "[%w_]+"},
	{"leftparan", "%("},
	{"rightparan", "%)"},
	{"vararg", "%.%.%."},
	{"array", "%[%]"},
	{"colon", ":"},
	{"point", "%."},
	{"comma", "%,"},
	{"question", "%?"},
	{"pipe", "|"},
	{"minus", "%-"},
	{"at", "@"},
}

---@param s string
---@return typecheck.Tokens? tokens
---@return string? error_message
function typecheck.lex(s)
	local pos = 1
	local tokens = Tokens()

	s = s:match("^%s*(.-)%s*$")
	while pos <= #s do
		local a, b, token
		for _, p in ipairs(token_patterns) do
			a, b, token = s:find("^(" .. p[2] .. ")%s*", pos)
			if token then
				table.insert(tokens, Token(p[1], token, pos))
				break
			end
		end
		if not token then
			return nil, "unknown symbol '" .. s:sub(pos, pos) .. "' at position " .. pos
		end
		pos = b + 1
	end

	tokens.token = tokens[1]

	return tokens
end

local class_by_name = {}

function typecheck.register_class(_type, T)
	class_by_name[_type] = T
end

function typecheck.get_type(name)
	if name == "any" then
		return AnyType()
	end
	if class_by_name[name] then
		return ClassType(name, class_by_name[name])
	end
	return Type(name)
end

function typecheck.parse_def(signature)
	local def = {
		name = "?",
		is_method = false,
		param_names = {},
		param_types = {},
		return_types = {},
	}

	local tokens, err = typecheck.lex(signature)
	if not tokens then
		return nil, err
	end

	local name, is_method = tokens:parse_func_name()
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
		return nil, get_token_error(tokens.token)
	end

	tokens:step()

	if not tokens.token then
		return nil, get_token_error()
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
	error(err, 2)
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

return typecheck
