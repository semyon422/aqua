local class = require("class")

local concat = table.concat

local etlua = {}

local html_escape_entities = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&#039;",
}

---@param value string
---@return string
local function html_escape(value)
	return (value:gsub([=[["<>&']]=], html_escape_entities))
end

---@param source string
---@return integer[]
local function get_line_starts(source)
	local starts = {1}
	local pos = 1
	while true do
		local next_pos = source:find("\n", pos, true)
		if not next_pos then
			break
		end
		starts[#starts + 1] = next_pos + 1
		pos = next_pos + 1
	end
	return starts
end

---@param source string
---@param pos integer
---@return integer
---@return integer
local function pos_to_line_col(source, pos)
	local starts = get_line_starts(source)
	local line_no = 1
	for i = 2, #starts do
		if starts[i] > pos then
			break
		end
		line_no = i
	end
	return line_no, pos - starts[line_no] + 1
end

---@param source string
---@param line_no integer
---@return string
local function get_line(source, line_no)
	local starts = get_line_starts(source)
	local start_pos = starts[line_no]
	if not start_pos then
		return ""
	end
	local stop_pos = source:find("\n", start_pos, true)
	if stop_pos then
		return source:sub(start_pos, stop_pos - 1)
	end
	return source:sub(start_pos)
end

---@param value string
---@param pos integer
---@return string?
---@return integer?
local function match_long_bracket(value, pos)
	local equals = value:match("^%[(=*)%[", pos)
	if not equals then
		return nil
	end
	return "]" .. equals .. "]", #equals + 2
end

---@class web.etlua.Compiler
---@operator call: web.etlua.Compiler
---@field buffer string[]
---@field line_map {[integer]: integer}
---@field line_count integer
local Compiler = class()

function Compiler:new()
	self.buffer = {}
	self.line_map = {}
	self.line_count = 0
end

---@param source_line integer
---@param code string
function Compiler:push(source_line, code)
	self.buffer[#self.buffer + 1] = code
	local _, newlines = code:gsub("\n", "")
	if newlines == 0 and code ~= "" then
		self.line_count = self.line_count + 1
		self.line_map[self.line_count] = source_line
		return
	end
	for _ = 1, newlines do
		self.line_count = self.line_count + 1
		self.line_map[self.line_count] = source_line
	end
end

function Compiler:header()
	self:push(1, "local _tostring, _escape, _b, _b_i = ...\n")
end

function Compiler:footer()
	self:push(1, "return _b\n")
end

---@param source_line integer
---@param value string
function Compiler:raw(source_line, value)
	self:push(source_line, ("_b_i = _b_i + 1\n_b[_b_i] = %q\n"):format(value))
end

---@param source_line integer
---@param code string
function Compiler:code(source_line, code)
	self:push(source_line, code .. "\n")
end

---@param source_line integer
---@param code string
---@param escape boolean
function Compiler:expression(source_line, code, escape)
	if escape then
		self:push(source_line, "_b_i = _b_i + 1\n_b[_b_i] = _escape(_tostring(" .. code .. "))\n")
	else
		self:push(source_line, "_b_i = _b_i + 1\n_b[_b_i] = _tostring(" .. code .. ")\n")
	end
end

---@return string
function Compiler:render()
	return concat(self.buffer)
end

---@class web.etlua.Chunk
---@field kind "raw"|"code"|"="|"-"
---@field text string
---@field pos integer

---@class web.etlua.Parser
---@operator call: web.etlua.Parser
---@field open_tag string
---@field close_tag string
---@field html_escape boolean
---@field str string
---@field pos integer
---@field chunks web.etlua.Chunk[]
---@field line_map {[integer]: integer}
local Parser = class()

Parser.open_tag = "<%"
Parser.close_tag = "%>"
Parser.html_escape = true

---@param pos integer
---@param message string
---@return string
function Parser:error_for_pos(pos, message)
	local line_no, col = pos_to_line_col(self.str, pos)
	local line = get_line(self.str, line_no)
	return ("%s at line %d, column %d\n%s"):format(message, line_no, col, line)
end

---@param start_pos integer
---@return integer? close_start
---@return integer? close_stop
---@return string? err
function Parser:find_close_tag(start_pos)
	local pos = start_pos
	local source = self.str
	while pos <= #source do
		local pair = source:sub(pos, pos + 1)
		if pair == self.close_tag then
			return pos, pos + 1
		end
		local char = source:sub(pos, pos)
		if char == "'" or char == '"' then
			local quote = char
			pos = pos + 1
			while pos <= #source do
				char = source:sub(pos, pos)
				if char == "\\" then
					pos = pos + 2
				elseif char == quote then
					pos = pos + 1
					break
				else
					pos = pos + 1
				end
			end
		elseif char == "[" then
			local close_long, length = match_long_bracket(source, pos)
			if close_long then
				local long_stop = source:find(close_long, pos + length, true)
				if not long_stop then
					return nil, nil, self:error_for_pos(pos, "failed to find long string close")
				end
				pos = long_stop + #close_long
			else
				pos = pos + 1
			end
		else
			pos = pos + 1
		end
	end
	return nil, nil, self:error_for_pos(start_pos, "failed to find closing tag")
end

---@param start_pos integer
---@param stop_pos integer
function Parser:push_raw(start_pos, stop_pos)
	if stop_pos < start_pos then
		return
	end
	self.chunks[#self.chunks + 1] = {kind = "raw", text = self.str:sub(start_pos, stop_pos), pos = start_pos}
end

---@param kind "code"|"="|"-"
---@param start_pos integer
---@param stop_pos integer
function Parser:push_code(kind, start_pos, stop_pos)
	self.chunks[#self.chunks + 1] = {kind = kind, text = self.str:sub(start_pos, stop_pos), pos = start_pos}
end

---@return boolean? found
---@return string? err
function Parser:next_tag()
	local start_pos, tag_stop = self.str:find(self.open_tag, self.pos, true)
	if not start_pos then
		self:push_raw(self.pos, #self.str)
		return false
	end
	self:push_raw(self.pos, start_pos - 1)

	local code_start = tag_stop + 1
	local modifier = self.str:sub(code_start, code_start)
	local kind = "code"
	if modifier == "=" or modifier == "-" then
		kind = modifier
		code_start = code_start + 1
	end

	local close_start, close_stop, err = self:find_close_tag(code_start)
	if err then
		return nil, err
	end
	---@cast close_start integer
	---@cast close_stop integer

	local trim_newline = false
	local code_stop = close_start - 1
	if self.str:sub(code_stop, code_stop) == "-" then
		trim_newline = true
		code_stop = code_stop - 1
	end
	self:push_code(kind, code_start, code_stop)
	self.pos = close_stop + 1
	if trim_newline and self.str:sub(self.pos, self.pos) == "\n" then
		self.pos = self.pos + 1
	end
	return true
end

---@param source string
---@return boolean? success
---@return string? err
function Parser:parse(source)
	assert(type(source) == "string", "expecting string for parse")
	self.str = source
	self.pos = 1
	self.chunks = {}
	while true do
		local found, err = self:next_tag()
		if err then
			return nil, err
		end
		if not found then
			break
		end
	end
	return true
end

---@param err string
---@param code string
---@return string?
function Parser:parse_error(err, code)
	local line_no, message = err:match(":(%d+):%s*(.*)$")
	local source_line = self.line_map[tonumber(line_no) or 0]
	if not source_line then
		local nested_line_no = err:match("line (%d+)")
		source_line = self.line_map[tonumber(nested_line_no) or 0]
	end
	if not source_line then
		return nil
	end
	local line = get_line(self.str, source_line)
	return ("%s at line %d\n%s"):format(message, source_line, line)
end

---@param source string
---@param compiler_cls web.etlua.Compiler?
---@return string? code
---@return string? err
function Parser:compile_to_lua(source, compiler_cls)
	local ok, err = self:parse(source)
	if not ok then
		return nil, err
	end
	local compiler = (compiler_cls or Compiler)()
	compiler:header()
	for _, chunk in ipairs(self.chunks) do
		local line_no = pos_to_line_col(self.str, chunk.pos)
		if chunk.kind == "raw" then
			compiler:raw(line_no, chunk.text)
		elseif chunk.kind == "code" then
			compiler:code(line_no, chunk.text)
		elseif chunk.kind == "=" then
			compiler:expression(line_no, chunk.text, self.html_escape)
		elseif chunk.kind == "-" then
			compiler:expression(line_no, chunk.text, false)
		end
	end
	compiler:footer()
	self.line_map = compiler.line_map
	return compiler:render()
end

---@param code string
---@param chunkname string?
---@return function? fn
---@return string? err
function Parser:load(code, chunkname)
	local fn, err = loadstring(code, chunkname or "etlua")
	if not fn then
		local parsed = self:parse_error(err, code)
		return nil, parsed or err
	end
	return fn
end

---@param fn function
---@param env table?
---@param buffer string[]?
---@param i integer?
---@return string[]? buffer
---@return string? err
function Parser:run(fn, env, buffer, i, ...)
	env = env or {}
	local combined_env = setmetatable({}, {
		__index = function(_, name)
			local value = env[name]
			if value == nil then
				return _G[name]
			end
			return value
		end,
	})
	setfenv(fn, combined_env)
	buffer = buffer or {}
	i = i or 0
	local ok, result = pcall(fn, tostring, html_escape, buffer, i, ...)
	if ok then
		return result
	end
	local parsed = self:parse_error(result, "")
	return nil, parsed or result
end

---@param source string
---@param chunkname string?
---@return function? fn
---@return string? err
function Parser:compile(source, chunkname)
	local code, err = self:compile_to_lua(source)
	if not code then
		return nil, err
	end
	local fn
	fn, err = self:load(code, chunkname)
	if not fn then
		return nil, err
	end
	return function(env, ...)
		local buffer
		buffer, err = self:run(fn, env, nil, nil, ...)
		if not buffer then
			return nil, err
		end
		return concat(buffer)
	end
end

---@param path string
---@return string
local function read_file(path)
	local file = io.open(path, "rb")
	if not file then
		return ("no file '%s'"):format(path)
	end
	local content = file:read("*a")
	file:close()
	return content
end

---@param source string
---@param chunkname string?
---@return fun(env: table?): string
function etlua.compile(source, chunkname)
	local parser = Parser()
	local fn = assert(parser:compile(source, chunkname))

	return function(env, ...)
		local result, err = fn(env, ...)
		if result then
			return result
		end
		error(err)
	end
end

---@param source string
---@param env table?
---@return string html
function etlua.render(source, env)
	return etlua.compile(source)(env)
end

---@return {[string]: fun(env: table?): string}
function etlua.autoload()
	return setmetatable({}, {
		__index = function(_, path)
			local content = read_file(path)
			return etlua.compile(content, "@" .. path)
		end,
	})
end

etlua.Parser = Parser
etlua.Compiler = Compiler
etlua.html_escape = html_escape

return etlua
