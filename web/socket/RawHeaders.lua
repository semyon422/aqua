local class = require("class")

---@class web.RawHeaders
---@operator call: web.RawHeaders
---@field headers {[1]: string, [2]: string}[]
local RawHeaders = class()

---@param soc web.IAsyncSocket
function RawHeaders:new(soc)
	self.soc = soc
	self.headers = {}
end

function RawHeaders:reset()
	self.headers = {}
end

---@return true?
---@return "closed"|"malformed headers"?
---@return string?
function RawHeaders:decode()
	local line, err, partial = self.soc:receive("*l")
	if not line then
		return nil, err, partial
	end

	while line ~= "" do
		local name, value = line:match("^(.-):%s*(.*)")
		if not name then
			return nil, "malformed headers"
		end
		---@cast name string
		---@cast value string

		-- folded values
		line, err, partial = self.soc:receive("*l")
		if not line then
			return nil, err, partial
		end

		while line:find("^%s") do
			value = value .. line
			line, err, partial = self.soc:receive("*l")
			if not line then
				return nil, err, partial
			end
		end

		table.insert(self.headers, {name, value})
	end

	return true
end

function RawHeaders:encode()
	for _, header in ipairs(self.headers) do
		self.soc:send(("%s: %s\r\n"):format(header[1], header[2]))
	end
	self.soc:send("\r\n")
end

return RawHeaders
