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

---@param context deco.ParseContext
---@return deco.Insertion[]
function ClassDecorator:process(context)
	---@type deco.Insertion[]
	local insertions = {}
	for _, statement in ipairs(context.statements) do
		if statement.tag == "Local" or statement.tag == "Localrec" then
			local class_name
			for _, annotation in ipairs(context:get_leading_comments(statement.line)) do
				annotation = annotation:match("^%s*(%-%-%-@.*)$")
				if annotation and annotation:match("^%-%-%-@class%s") then
					local tokens = assert(lexer.lex(annotation:sub(5)))
					local annotation_name = tokens:parse_name()
					assert(annotation_name == "class")
					class_name = tokens:parse_name()
				end
			end

			local local_name = statement[1] and statement[1][1]
			if class_name and local_name and local_name.tag == "Id" then
				local inserted = ([[require("typecheck").register_class(%q, ?)]]):gsub(
					"?", context:get_source(local_name)
				):format(class_name)
				table.insert(insertions, {
					offset = context:get_byte_offset(statement.end_offset),
					text = " " .. inserted,
				})
			end
		end
	end
	return insertions
end

return ClassDecorator
