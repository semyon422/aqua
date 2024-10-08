local ISocket = require("web.socket.ISocket")

---@class web.LineAllDecorator: web.ISocket
---@operator call: web.LineAllDecorator
---@field remainder string?
local LineAllDecorator = ISocket + {}

LineAllDecorator.chunk_size = 4096

---@param soc web.ISocket
function LineAllDecorator:new(soc)
	self.soc = soc
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receive(pattern, prefix)
	if type(pattern) == "number" then
		return self.soc:receive(pattern, prefix)
	elseif pattern == "*a" then
		return self:receiveAll(prefix)
	elseif pattern == "*l" then
		return self:receiveLine(prefix)
	end
	error("invalid pattern")
end

---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receiveLine(prefix)
	---@type string[]
	local buffer = {}
	table.insert(buffer, prefix)
	table.insert(buffer, self.remainder)

	self.remainder = nil

	if self.closed then
		return nil, "closed", (table.concat(buffer):gsub("\r", ""))
	end

	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		local data = line or partial
		---@cast data string

		---@type string?, string?
		local _line, remainder = data:match("^(.-)\n(.*)$")
		if _line then
			self.remainder = remainder
			table.insert(buffer, _line)
			if err == "closed" then
				self.closed = true
			end
			return (table.concat(buffer):gsub("\r", ""))
		end

		table.insert(buffer, data)

		if not line then
			return nil, err, (table.concat(buffer):gsub("\r", ""))
		end
	end
end

---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receiveAll(prefix)
	---@type string[]
	local buffer = {}
	table.insert(buffer, prefix)
	table.insert(buffer, self.remainder)

	self.remainder = nil

	if self.closed then
		return nil, "closed", table.concat(buffer)
	end

	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)

		if err == "closed" then
			self.closed = true
		end

		if not line then
			if err == "closed" then
				return table.concat(buffer)
			end
			return nil, err, table.concat(buffer)
		end
	end
end

return LineAllDecorator
