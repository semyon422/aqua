local IBodyReader = require("web.body.IBodyReader")

---@class web.BodyReader: web.IBodyReader
---@operator call: web.BodyReader
local BodyReader = IBodyReader + {}

---@param req web.IRequest
---@param chunk_size integer?
function BodyReader:new(req, chunk_size)
	self.req = req
	self.size = tonumber(req.headers["Content-Length"]) or 0
	self.chunk_size = chunk_size or self.size
end

---@return string?
function BodyReader:read()
	local req = self.req
	local chunk_size = self.chunk_size
	local size = self.size

	if size == 0 then
		return
	end

	local chunk = req:read(math.min(chunk_size, size))
	self.size = self.size - #chunk

	return chunk
end

---@return string
function BodyReader:readAll()
	---@type string[]
	local out = {}
	local i = 0

	---@type string?
	local chunk
	repeat
		chunk = self:read()
		i = i + 1
		out[i] = chunk
	until not chunk

	return table.concat(out)
end

---@return fun(): string?
function BodyReader:iter()
	return function()
		return self:read()
	end
end

return BodyReader
