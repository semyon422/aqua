local class = require("class")

local AnyType = require("typecheck.AnyType")
local ArrayType = require("typecheck.ArrayType")
local ClassType = require("typecheck.ClassType")
local CType = require("typecheck.CType")
local Type = require("typecheck.Type")
local UnionType = require("typecheck.UnionType")

local parse_error = "unexpected token '%s' at position %s"
local function get_token_error(token)
	if not token then
		return "token expected"
	end
	return parse_error:format(token.value, token.pos)
end

local function get_type(name)
	if name == "any" then
		return AnyType()
	end
	if name:find("^ffi%.") or name:find("^love%.") then
		return CType(name)
	end
	if name:find("%.") then
		return ClassType(name)
	end
	return Type(name)
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

function Tokens:get_token_error()
	return get_token_error(self.token)
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

	if not self.token or (self.token.type ~= "colon" and self.token.type ~= "point") then
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
		while self.token and self.token.type == "asterisk" do
			t = t .. self.token.value
			self:step()
		end
		_type = get_type(t)
	end

	while self.token and self.token.type == "array" do
		array_depth = array_depth + 1
		self:step()
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
			break
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

return Tokens
