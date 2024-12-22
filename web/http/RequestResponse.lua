local IRequestResponse = require("web.http.IRequestResponse")
local Headers = require("web.http.Headers")
local LengthSocket = require("web.socket.LengthSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local ChunkedEncoding = require("web.http.ChunkedEncoding")

---@class web.RequestResponse: web.IRequestResponse
---@operator call: web.RequestResponse
---@field headers web.Headers
local RequestResponse = IRequestResponse + {}

---@param soc web.IExtendedSocket
---@param mode "r"|"w"|"rw"?
function RequestResponse:new(soc, mode)
	self.soc = soc
	self.mode = mode or "rw"
	self.headers = Headers()
end

---@param mode "r"|"w"|"rw"
function RequestResponse:assert_mode(mode)
	local _mode = self.mode
	if _mode == mode or _mode == "rw" then
		return
	end
	error("can't be called in mode '" .. tostring(_mode) .. "'", 3)
end

---@param length integer
function RequestResponse:set_length(length)
	self:assert_mode("w")
	self.headers:unset("Transfer-Encoding")
	self.headers:set("Content-Length", length)
end

function RequestResponse:set_chunked_encoding()
	self:assert_mode("w")
	self.headers:unset("Content-Length")
	self.headers:set("Transfer-Encoding", "chunked")
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
	self:assert_mode("r")
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
	self:assert_mode("w")
	assert(not i and not j, "not implemented")
	local ok, err = self:send_headers()
	if not ok then
		return nil, err, 0
	end
	return self.soc:send(data, i, j)
end

return RequestResponse
