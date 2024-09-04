local class = require("class")

---@class web.AsyncSocket
---@operator call: web.AsyncSocket
local AsyncSocket = class()

---@param soc web.ISocket
function AsyncSocket:new(soc)
	self.soc = soc
end

---@param pattern "*a"|"*l"|integer
---@return string?
---@return "closed"?
---@return string?
function AsyncSocket:read(pattern)
	local buffer = {}

	while true do
		local line, err, partial = self.soc:receive(pattern)
		if err == "closed" then
			return nil, "closed", partial
		end

		local data = line or partial
		---@cast data string

		if type(pattern) == "number" then
			pattern = pattern - #data
		end

		table.insert(buffer, data)
		if line then
			return table.concat(buffer)
		elseif err == "timeout" then
			coroutine.yield()
		end
	end
end

---@param data string
---@return integer?
---@return "closed"?
---@return integer?
function AsyncSocket:write(data)
	local i, j = 1, #data

	while true do
		local last_byte, err, _last_byte = self.soc:send(data, i, j)
		if err == "closed" then
			return nil, "closed", _last_byte
		end

		local byte = last_byte or _last_byte
		---@cast byte integer

		i = byte + 1
		if last_byte then
			return last_byte
		elseif err == "timeout" then
			coroutine.yield()
		end
	end
end

return AsyncSocket
