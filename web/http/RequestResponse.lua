local IRequestResponse = require("web.http.IRequestResponse")
local LengthSocket = require("web.socket.LengthSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local ChunkedEncoding = require("web.http.ChunkedEncoding")

---@class web.RequestResponse: web.IRequestResponse
---@operator call: web.RequestResponse
---@field headers web.Headers
local RequestResponse = IRequestResponse + {}

---@private
---@return true?
---@return "closed"|"timeout"|"malformed headers"?
function RequestResponse:receive_headers()
	error("not implemented")
end

---@private
---@return true?
---@return "closed"|"timeout"?
function RequestResponse:send_headers()
	error("not implemented")
end

function RequestResponse:process_headers()
	local length = self.headers:get("Content-Length")
	local encoding = self.headers:get("Transfer-Encoding")
	if length and tonumber(length) then
		self.soc = ExtendedSocket(LengthSocket(self.soc, tonumber(length)))
	elseif encoding == "chunked" then
		self.soc = ExtendedSocket(ChunkedEncoding(self.soc))
	else
		self.soc = ExtendedSocket(LengthSocket(self.soc, 0))
	end
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"|"malformed headers"?
---@return string?
function RequestResponse:receive(pattern, prefix)
	local ok, err = self:receive_headers()
	if not ok then
		return nil, err, ""
	end
	return self.soc:receive(pattern, prefix)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function RequestResponse:send(data, i, j)
	i, j = self:normalize_bounds(data, i, j)
	local ok, err = self:send_headers()
	if not ok then
		return nil, err, i - 1
	end
	return self.soc:send(data, i, j)
end

---@param data string
---@return 1?
---@return "closed"|"timeout"?
function RequestResponse:print(data)
	local bytes, err = self:send(data)
	if not bytes then
		return nil, err
	end
	return 1
end

---@param wait boolean?
---@return 1?
---@return "closed"|"timeout"?
function RequestResponse:flush(wait)
	-- buffering is not implemented yet
end

---@return 1?
---@return "closed"|"timeout"?
function RequestResponse:eof()
	return self:print("")
end

return RequestResponse
