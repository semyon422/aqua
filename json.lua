local json = {}

local object_metatable = {__name = "json.object"}
local array_metatable = {__name = "json.array"}
local null_metatable = {
	__name = "json.null",
	__tostring = function() return "null" end,
}

json.null = setmetatable({}, null_metatable)

---@generic T: table
---@param value T?
---@return T
function json.object(value)
	if value == nil then
		value = {}
	end
	assert(type(value) == "table", "json.object expects a table")
	return setmetatable(value, object_metatable)
end

---@generic T: table
---@param value T?
---@return T
function json.array(value)
	if value == nil then
		value = {}
	end
	assert(type(value) == "table", "json.array expects a table")
	return setmetatable(value, array_metatable)
end

---@param value any
---@return boolean
function json.isObject(value)
	return type(value) == "table" and getmetatable(value) == object_metatable
end

---@param value any
---@return boolean
function json.isArray(value)
	return type(value) == "table" and getmetatable(value) == array_metatable
end

local escape_bytes = {
	[8] = "\\b",
	[9] = "\\t",
	[10] = "\\n",
	[12] = "\\f",
	[13] = "\\r",
	[34] = '\\"',
	[92] = "\\\\",
}

---@param value string
---@return string
local function encode_string(value)
	local parts = {'"'}
	local start = 1
	for index = 1, #value do
		local byte = value:byte(index)
		local escaped = escape_bytes[byte]
		if not escaped and byte < 32 then
			escaped = ("\\u%04x"):format(byte)
		end
		if escaped then
			if index > start then
				table.insert(parts, value:sub(start, index - 1))
			end
			table.insert(parts, escaped)
			start = index + 1
		end
	end
	if start <= #value then
		table.insert(parts, value:sub(start))
	end
	table.insert(parts, '"')
	return table.concat(parts)
end

---@param value table
---@return "object"|"array"
local function infer_table_type(value)
	local metatable = getmetatable(value)
	if metatable == object_metatable then
		return "object"
	elseif metatable == array_metatable then
		return "array"
	end

	local key = next(value)
	if key == nil then
		return "array"
	elseif type(key) == "number" then
		return "array"
	elseif type(key) == "string" then
		return "object"
	end
	error("JSON table keys must be strings or positive array indices")
end

---@param value any
---@param stack {[table]: true}
---@param depth integer
---@return string
local function encode_value(value, stack, depth)
	if value == json.null or value == nil then
		return "null"
	end
	local value_type = type(value)
	if value_type == "boolean" then
		return value and "true" or "false"
	elseif value_type == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("JSON cannot encode NaN or infinity")
		end
		return ("%.17g"):format(value)
	elseif value_type == "string" then
		return encode_string(value)
	elseif value_type ~= "table" then
		error("JSON cannot encode type " .. value_type)
	end
	if depth > 128 then
		error("JSON nesting exceeds 128 levels")
	elseif stack[value] then
		error("JSON cannot encode circular tables")
	end
	stack[value] = true

	local parts = {}
	if infer_table_type(value) == "array" then
		local size = 0
		local count = 0
		for key in pairs(value) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				error("JSON arrays must use contiguous positive integer keys")
			end
			size = math.max(size, key)
			count = count + 1
		end
		if count ~= size then
			error("JSON arrays must use contiguous positive integer keys")
		end
		for index = 1, size do
			table.insert(parts, encode_value(value[index], stack, depth + 1))
		end
		stack[value] = nil
		return "[" .. table.concat(parts, ",") .. "]"
	end

	---@type string[]
	local keys = {}
	for key in pairs(value) do
		if type(key) ~= "string" then
			error("JSON object keys must be strings")
		end
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		table.insert(parts, encode_string(key) .. ":" .. encode_value(value[key], stack, depth + 1))
	end
	stack[value] = nil
	return "{" .. table.concat(parts, ",") .. "}"
end

---@param value any
---@return string
function json.encode(value)
	return encode_value(value, {}, 1)
end

---@class json.Parser
---@field source string
---@field index integer
---@field length integer
local Parser = {}
Parser.__index = Parser

---@param source string
---@return json.Parser
function Parser:new(source)
	return setmetatable({source = source, index = 1, length = #source}, self)
end

function Parser:skipWhitespace()
	local source = self.source
	local index = self.index
	while index <= self.length do
		local byte = source:byte(index)
		if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
			break
		end
		index = index + 1
	end
	self.index = index
end

---@param message string
function Parser:error(message)
	local line = 1
	local column = 1
	for index = 1, self.index - 1 do
		if self.source:byte(index) == 10 then
			line = line + 1
			column = 1
		else
			column = column + 1
		end
	end
	error(("%s at line %d column %d"):format(message, line, column), 0)
end

---@param codepoint integer
---@return string
local function encode_utf8(codepoint)
	if codepoint <= 0x7F then
		return string.char(codepoint)
	elseif codepoint <= 0x7FF then
		return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
	elseif codepoint <= 0xFFFF then
		return string.char(
			0xE0 + math.floor(codepoint / 0x1000),
			0x80 + math.floor(codepoint / 0x40) % 0x40,
			0x80 + codepoint % 0x40
		)
	elseif codepoint <= 0x10FFFF then
		return string.char(
			0xF0 + math.floor(codepoint / 0x40000),
			0x80 + math.floor(codepoint / 0x1000) % 0x40,
			0x80 + math.floor(codepoint / 0x40) % 0x40,
			0x80 + codepoint % 0x40
		)
	end
	error("invalid Unicode codepoint")
end

---@return integer
function Parser:parseHexEscape()
	local text = self.source:sub(self.index, self.index + 3)
	if #text ~= 4 or not text:match("^%x%x%x%x$") then
		self:error("invalid Unicode escape")
	end
	self.index = self.index + 4
	return assert(tonumber(text, 16))
end

---@return string
function Parser:parseString()
	self.index = self.index + 1
	local parts = {}
	local start = self.index
	while self.index <= self.length do
		local byte = self.source:byte(self.index)
		if byte == 34 then
			if self.index > start then
				table.insert(parts, self.source:sub(start, self.index - 1))
			end
			self.index = self.index + 1
			return table.concat(parts)
		elseif byte == 92 then
			if self.index > start then
				table.insert(parts, self.source:sub(start, self.index - 1))
			end
			self.index = self.index + 1
			local escape = self.source:sub(self.index, self.index)
			local escaped = ({['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"})[escape]
			if escaped then
				table.insert(parts, escaped)
				self.index = self.index + 1
			elseif escape == "u" then
				self.index = self.index + 1
				local codepoint = self:parseHexEscape()
				if codepoint >= 0xD800 and codepoint <= 0xDBFF then
					if self.source:sub(self.index, self.index + 1) ~= "\\u" then
						self:error("high surrogate without low surrogate")
					end
					self.index = self.index + 2
					local low = self:parseHexEscape()
					if low < 0xDC00 or low > 0xDFFF then
						self:error("invalid low surrogate")
					end
					codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + low - 0xDC00
				elseif codepoint >= 0xDC00 and codepoint <= 0xDFFF then
					self:error("low surrogate without high surrogate")
				end
				table.insert(parts, encode_utf8(codepoint))
			else
				self:error("invalid string escape")
			end
			start = self.index
		elseif byte < 32 then
			self:error("unescaped control character in string")
		else
			self.index = self.index + 1
		end
	end
	self:error("unterminated string")
end

---@return number
function Parser:parseNumber()
	local start = self.index
	local source = self.source
	if source:sub(self.index, self.index) == "-" then
		self.index = self.index + 1
	end
	local first = source:sub(self.index, self.index)
	if first == "0" then
		self.index = self.index + 1
		if source:sub(self.index, self.index):match("%d") then
			self:error("leading zero in number")
		end
	elseif first:match("[1-9]") then
		repeat
			self.index = self.index + 1
		until not source:sub(self.index, self.index):match("%d")
	else
		self:error("invalid number")
	end
	if source:sub(self.index, self.index) == "." then
		self.index = self.index + 1
		if not source:sub(self.index, self.index):match("%d") then
			self:error("fraction requires a digit")
		end
		repeat
			self.index = self.index + 1
		until not source:sub(self.index, self.index):match("%d")
	end
	local exponent = source:sub(self.index, self.index)
	if exponent == "e" or exponent == "E" then
		self.index = self.index + 1
		local sign = source:sub(self.index, self.index)
		if sign == "+" or sign == "-" then
			self.index = self.index + 1
		end
		if not source:sub(self.index, self.index):match("%d") then
			self:error("exponent requires a digit")
		end
		repeat
			self.index = self.index + 1
		until not source:sub(self.index, self.index):match("%d")
	end
	local number = tonumber(source:sub(start, self.index - 1))
	if not number or number == math.huge or number == -math.huge then
		self:error("number is out of range")
	end
	return number
end

---@param literal string
---@param value any
---@return any
function Parser:parseLiteral(literal, value)
	if self.source:sub(self.index, self.index + #literal - 1) ~= literal then
		self:error("invalid literal")
	end
	self.index = self.index + #literal
	return value
end

---@param depth integer
---@return any
function Parser:parseArray(depth)
	self.index = self.index + 1
	local result = json.array()
	self:skipWhitespace()
	if self.source:sub(self.index, self.index) == "]" then
		self.index = self.index + 1
		return result
	end
	local index = 1
	while true do
		result[index] = self:parseValue(depth + 1)
		index = index + 1
		self:skipWhitespace()
		local delimiter = self.source:sub(self.index, self.index)
		self.index = self.index + 1
		if delimiter == "]" then
			return result
		elseif delimiter ~= "," then
			self:error("expected ',' or ']'")
		end
		self:skipWhitespace()
	end
end

---@param depth integer
---@return table
function Parser:parseObject(depth)
	self.index = self.index + 1
	local result = json.object()
	self:skipWhitespace()
	if self.source:sub(self.index, self.index) == "}" then
		self.index = self.index + 1
		return result
	end
	while true do
		if self.source:sub(self.index, self.index) ~= '"' then
			self:error("object key must be a string")
		end
		local key = self:parseString()
		self:skipWhitespace()
		if self.source:sub(self.index, self.index) ~= ":" then
			self:error("expected ':' after object key")
		end
		self.index = self.index + 1
		self:skipWhitespace()
		result[key] = self:parseValue(depth + 1)
		self:skipWhitespace()
		local delimiter = self.source:sub(self.index, self.index)
		self.index = self.index + 1
		if delimiter == "}" then
			return result
		elseif delimiter ~= "," then
			self:error("expected ',' or '}'")
		end
		self:skipWhitespace()
	end
end

---@param depth integer
---@return any
function Parser:parseValue(depth)
	if depth > 128 then
		self:error("JSON nesting exceeds 128 levels")
	end
	self:skipWhitespace()
	local character = self.source:sub(self.index, self.index)
	if character == '"' then
		return self:parseString()
	elseif character == "{" then
		return self:parseObject(depth)
	elseif character == "[" then
		return self:parseArray(depth)
	elseif character == "t" then
		return self:parseLiteral("true", true)
	elseif character == "f" then
		return self:parseLiteral("false", false)
	elseif character == "n" then
		return self:parseLiteral("null", json.null)
	elseif character == "-" or character:match("%d") then
		return self:parseNumber()
	end
	self:error("unexpected character " .. (character ~= "" and ("'" .. character .. "'") or "at end of input"))
end

---@param source string
---@return any
function json.decode(source)
	assert(type(source) == "string", "json.decode expects a string")
	local parser = Parser:new(source)
	local value = parser:parseValue(1)
	parser:skipWhitespace()
	if parser.index <= parser.length then
		parser:error("trailing data")
	end
	return value
end

---@param source string
---@return any?
---@return string?
function json.decode_safe(source)
	local ok, value = pcall(json.decode, source)
	if not ok then
		return nil, tostring(value)
	end
	return value
end

return json
