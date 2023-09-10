local deco = require("deco")
local typecheck = require("typecheck")
local lexer = require("typecheck.lexer")

---@class typecheck.TypeDecorator: deco.FunctionDecorator
---@operator call: typecheck.TypeDecorator
local TypeDecorator = deco.FunctionDecorator + {}

function TypeDecorator:new()
	self.def = {
		param_names = {},
		param_types = {},
		return_types = {},
	}
end

function TypeDecorator:func_begin(func_name)
	assert(not self.def.func_name)
end

function TypeDecorator:func_end(func_name)
	if self.nocheck then
		self.nocheck = false
		return
	end

	local def = self.def
	if not typecheck.strict and #def.param_names == 0 and #def.return_types == 0 then
		return
	end

	def.name = func_name
	func_name = func_name:gsub(":", ".")
	local signature = typecheck.encode_def(def)

	self:new()

	return ([[? = require("typecheck").decorate(?, %q)]]):gsub("?", func_name):format(signature)
end

function TypeDecorator:process_annotation(line)
	local tokens = assert(lexer.lex(line:sub(5)))

	local def = self.def
	local annotaion = tokens:parse_name()
	if annotaion == "param" then
		local name = tokens:parse_name()
		local union = tokens:parse_type_union()
		table.insert(def.param_names, name)
		table.insert(def.param_types, union)
	elseif annotaion == "return" then
		local union = tokens:parse_type_union()
		table.insert(def.return_types, union)
		if tokens.token and tokens.token.type == "vararg" then
			def.return_types.is_vararg = true
		end
	elseif annotaion == "nocheck" then
		self.nocheck = true
	end
end

function TypeDecorator:next(line)
	if line:sub(1, 4) == "---@" then
		self:process_annotation(line)
	end
	return deco.FunctionDecorator.next(self, line)
end

return TypeDecorator
