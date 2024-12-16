local IResponse = require("web.http.IResponse")
local StatusLine = require("web.http.StatusLine")
local RequestResponse = require("web.http.RequestResponse")

---@class web.Response: web.IResponse, web.RequestResponse
---@operator call: web.Response
local Response = IResponse + RequestResponse

Response.status = 200

---@return 1?
---@return "closed"|"timeout"|"unknown status"|"malformed headers"?
function Response:receive_headers()
	self:assert_mode("r")

	if self.headers_received then
		return 1
	end
	self.headers_received = true

	local sline, err = StatusLine():receive(self.soc)
	if not sline then
		return nil, err
	end

	local status = tonumber(sline.status)
	if not status then
		return nil, "unknown status"
	end
	self.status = status

	local headers, err = self.headers:receive(self.soc)
	if not headers then
		return nil, err
	end

	self:process_headers()

	return 1
end

---@return 1?
---@return "closed"|"timeout"?
function Response:send_headers()
	self:assert_mode("w")

	if self.headers_sent then
		return 1
	end
	self.headers_sent = true

	local sline, err = StatusLine(self.status):send(self.soc)
	if not sline then
		return nil, err
	end

	local headers, err = self.headers:send(self.soc)
	if not headers then
		return nil, err
	end

	self:process_headers()

	return 1
end

return Response
