local deco = require("deco")
local typecheck = require("typecheck")
local lexer = require("typecheck.lexer")

---@class typecheck.ClassDecorator: deco.Decorator
---@field prev_is_annotation boolean
---@operator call: typecheck.ClassDecorator
local ClassDecorator = deco.Decorator + {}
typecheck.ClassDecorator = ClassDecorator

function ClassDecorator:next(line)
	local is_annotation = line:sub(1, 4) == "---@"
	if not self.prev_is_annotation and is_annotation then
		local tokens = assert(lexer.lex(line:sub(5)))

		local annotaion = tokens:parse_name()
		if annotaion == "class" then
			self.name = tokens:parse_name()
			self.prev_is_annotation = true
		end
	elseif self.prev_is_annotation and not is_annotation then
		self.prev_is_annotation = false

		local tokens = assert(lexer.lex(line))
		assert(tokens:parse_name() == "local")
		local name = assert(tokens:parse_name())

		return ([[require("typecheck").register_class(%q, ?)]]):gsub("?", name):format(self.name)
	end
end

return ClassDecorator
