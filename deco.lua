local class = require("class")
local decoder = require("luacheck.decoder")
local lua_parser = require("luacheck.parser")

local deco = {}

---@class deco.DecodedSource
---@field get_substring fun(self: deco.DecodedSource, start_offset: integer, end_offset: integer): string

---@class deco.AstNode
---@field tag string?
---@field offset integer
---@field end_offset integer
---@field line integer
---@field msg string?
---@field [integer] deco.AstNode|deco.AstNode[]

---@class deco.Insertion
---@field offset integer Byte offset after which text is inserted.
---@field text string

---@class deco.ParseContext
---@operator call: deco.ParseContext
---@field source string
---@field decoded deco.DecodedSource
---@field ast deco.AstNode
---@field comments deco.AstNode[]
---@field code_lines {[integer]: boolean}
---@field statements deco.AstNode[]
---@field line_comments {[integer]: deco.AstNode}
local ParseContext = class()
deco.ParseContext = ParseContext

local statement_tags = {
	Set = true,
	Local = true,
	Localrec = true,
	OpSet = true,
	Do = true,
	While = true,
	Repeat = true,
	If = true,
	Fornum = true,
	Forin = true,
	Return = true,
	Break = true,
	Goto = true,
	Label = true,
	Call = true,
	Invoke = true,
}

---@param value deco.AstNode|deco.AstNode[]
---@param statements deco.AstNode[]
local function collect_statements(value, statements)
	if type(value) ~= "table" then
		return
	end

	if statement_tags[value.tag] then
		table.insert(statements, value)
	end

	-- Luacheck AST nodes are recursive, mixed-key external tables.
	---@diagnostic disable-next-line: no-unknown
	for key, child in pairs(value) do
		if key ~= "end_range" and type(child) == "table" then
			collect_statements(child, statements)
		end
	end
end

---@param source string
---@param decoded deco.DecodedSource
---@param ast deco.AstNode
---@param comments deco.AstNode[]
---@param code_lines {[integer]: boolean}
function ParseContext:new(source, decoded, ast, comments, code_lines)
	self.source = source
	self.decoded = decoded
	self.ast = ast
	self.comments = comments
	self.code_lines = code_lines
	self.statements = {}
	collect_statements(ast, self.statements)
	table.sort(self.statements, function(a, b)
		if a.offset == b.offset then
			return a.end_offset < b.end_offset
		end
		return a.offset < b.offset
	end)

	self.line_comments = {}
	for _, comment in ipairs(comments) do
		if not code_lines[comment.line] then
			self.line_comments[comment.line] = comment
		end
	end
end

---@param range deco.AstNode
---@return string
function ParseContext:get_source(range)
	return self.decoded:get_substring(range.offset, range.end_offset)
end

---@param character_offset integer
---@return integer
function ParseContext:get_byte_offset(character_offset)
	if character_offset == 0 then
		return 0
	end
	return #self.decoded:get_substring(1, character_offset)
end

---@param line integer
---@return string[]
function ParseContext:get_leading_comments(line)
	local comments = {}
	line = line - 1
	while true do
		local comment = self.line_comments[line]
		if not comment then
			break
		end
		table.insert(comments, 1, self:get_source(comment))
		line = line - 1
	end
	return comments
end

---@param tag string
---@return deco.AstNode[]
function ParseContext:get_statements(tag)
	---@type deco.AstNode[]
	local statements = {}
	for _, statement in ipairs(self.statements) do
		if statement.tag == tag then
			table.insert(statements, statement)
		end
	end
	return statements
end

---@class deco.Decorator
---@operator call: deco.Decorator
local Decorator = class()
deco.Decorator = Decorator

---@param line string
---@return string?
function Decorator:next(line) end

---@param context deco.ParseContext
---@return deco.Insertion[]
function Decorator:process(context)
	---@type deco.Insertion[]
	local insertions = {}
	local position = 1
	while position <= #context.source do
		local newline = context.source:find("\n", position, true)
		local line_end = newline and newline - 1 or #context.source
		local line = context.source:sub(position, line_end)
		local inserted = self:next(line)
		if inserted then
			table.insert(insertions, {
				offset = line_end,
				text = " " .. inserted,
			})
		end
		if not newline then
			break
		end
		position = newline + 1
	end
	return insertions
end

---@class deco.FunctionDecorator: deco.Decorator
---@operator call: deco.FunctionDecorator
---@field func_name string?
local FunctionDecorator = class(Decorator)
deco.FunctionDecorator = FunctionDecorator

---Legacy line-oriented entry point. `deco.process` uses the structural method.
---@param line string
---@return string?
function FunctionDecorator:next(line)
	local matched =
		line:match("^function ([%w%.:_]+)%(") or
		line:match("^local function ([%w_]+)%(") or
		line:match("^([%w%._]+) = function%(") or
		line:match("^local ([%w_]+) = function%(")

	if matched then
		self:func_begin(matched)
	end

	self.func_name = self.func_name or matched
	if self.func_name and line:match("^end") or matched and line:match("end$") then
		local inserted = self:func_end(self.func_name)
		self.func_name = nil
		return inserted
	end
end

---@param node deco.AstNode
---@param context deco.ParseContext
---@return boolean
local function is_named_target(node, context)
	if node.tag == "Id" then
		return true
	elseif node.tag ~= "Index" or node[2].tag ~= "String" then
		return false
	end

	local source = context:get_source(node)
	return not source:find("[", 1, true) and is_named_target(node[1], context)
end

---@param func_name string
function FunctionDecorator:func_begin(func_name) end

---@param func_name string
---@return string?
function FunctionDecorator:func_end(func_name) end

---@param context deco.ParseContext
---@return deco.Insertion[]
function FunctionDecorator:process(context)
	---@type deco.Insertion[]
	local insertions = {}
	for _, statement in ipairs(context.statements) do
		if statement.tag == "Set" or statement.tag == "Local" or statement.tag == "Localrec" then
			local targets, values = statement[1], statement[2]
			for index, value in ipairs(values or {}) do
				local target = targets and targets[index]
				if value.tag == "Function" and target and is_named_target(target, context) then
					for _, annotation in ipairs(context:get_leading_comments(statement.line)) do
						local normalized_annotation = annotation:match("^%s*(%-%-%-@.*)$")
						if self.process_annotation and normalized_annotation then
							self:process_annotation(normalized_annotation)
						end
					end

					local func_name = context:get_source(target)
					self:func_begin(func_name)
					local inserted = self:func_end(func_name)
					if inserted then
						table.insert(insertions, {
							offset = context:get_byte_offset(statement.end_offset),
							text = " " .. inserted,
						})
					end
				end
			end
		end
	end
	return insertions
end

---@param path string
---@return string?
function deco.read_file(path)
	error("not implemented")
end

---@type string[]
deco.blacklist = {}

---@type deco.Decorator[]
deco.decorators = {}

function deco.add(f)
	table.insert(deco.decorators, f)
end

---@param s string
---@return string
function deco.process(s)
	if #deco.decorators == 0 then
		return s
	end

	---@type deco.DecodedSource
	local decoded = decoder.decode(s)
	---@type boolean, deco.AstNode, deco.AstNode[], {[integer]: boolean}
	local ok, ast, comments, code_lines = pcall(lua_parser.parse, decoded)
	if not ok then
		if type(ast) == "table" and ast.msg and ast.line then
			error(("Lua parse error on line %d: %s"):format(ast.line, ast.msg), 0)
		end
		error(ast, 0)
	end

	local context = ParseContext(s, decoded, ast, comments, code_lines)
	---@type {[integer]: string[]}
	local insertions = {}
	for _, decorator in ipairs(deco.decorators) do
		for _, insertion in ipairs(decorator:process(context)) do
			local at_offset = insertions[insertion.offset]
			if not at_offset then
				at_offset = {}
				insertions[insertion.offset] = at_offset
			end
			table.insert(at_offset, insertion.text)
		end
	end

	---@type integer[]
	local offsets = {}
	for offset in pairs(insertions) do
		table.insert(offsets, offset)
	end
	table.sort(offsets, function(a, b)
		return a > b
	end)

	for index = 1, #offsets do
		local offset = offsets[index]
		local inserted = assert(insertions[offset])
		-- LuaLS 3.19 loses the string type on loop reassignment.
		---@diagnostic disable-next-line: no-unknown
		s = s:sub(1, offset) .. table.concat(inserted) .. s:sub(offset + 1)
	end
	return s
end

---@param name string
---@return function|string
local function lua_loader(name)
	name = name:gsub("%.", "/")

	local errors = {}

	for path in package.path:gsub("%?", name):gmatch("[^;]+") do
		local blacklisted = false
		for _, item in ipairs(deco.blacklist) do
			if path:find(item, 1, true) then
				blacklisted = true
			end
		end
		local content = deco.read_file(path)
		if content then
			if not blacklisted then
				content = deco.process(content, name:match("([^/]+)$"))
			end
			local loader, err = loadstring(content, "@" .. path) -- [string "mod.lua"] -> mod.lua
			if loader then
				return loader
			end
			error(err .. "\n" .. content)
		else
			table.insert(errors, ("no file '%s'"):format(path))
		end
	end

	return "\n\t" .. table.concat(errors, "\n\t")
end

function deco.replace_loader()
	package.loaders[2] = lua_loader
end

return deco
