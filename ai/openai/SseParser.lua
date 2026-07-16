local class = require("class")

---@class aqua.openai.SseParser
---@operator call: aqua.openai.SseParser
---@field buffer string
---@field data_lines string[]
---@field on_data fun(data: string)
local SseParser = class()

---@param on_data fun(data: string)
function SseParser:new(on_data)
	self.buffer = ""
	self.data_lines = {}
	self.on_data = on_data
end

function SseParser:dispatch()
	if #self.data_lines == 0 then
		return
	end
	self.on_data(table.concat(self.data_lines, "\n"))
	self.data_lines = {}
end

---@param line string
function SseParser:processLine(line)
	line = line:gsub("\r$", "")
	if line == "" then
		self:dispatch()
		return
	end
	local data = line:match("^data:%s?(.*)$")
	if data then
		table.insert(self.data_lines, data)
	end
end

---@param chunk string
function SseParser:feed(chunk)
	self.buffer = self.buffer .. chunk
	while true do
		local newline = self.buffer:find("\n", 1, true)
		if not newline then
			return
		end
		self:processLine(self.buffer:sub(1, newline - 1))
		self.buffer = self.buffer:sub(newline + 1)
	end
end

function SseParser:finish()
	if self.buffer ~= "" then
		self:processLine(self.buffer)
		self.buffer = ""
	end
	self:dispatch()
end

return SseParser
