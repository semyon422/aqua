local Request = require("http.Request")
local class = require("class")

---@class http.HttpServer
---@operator call: http.HttpServer
local HttpServer = class()

function HttpServer:new(request_handler)
	self.request_handler = request_handler
end

function HttpServer:handle_client(client)
	local req = Request(client)

	local ok, err = req:read_header()
	if not ok then
		return nil, err
	end

	local code, headers, body = self.request_handler:handle_request(req)
	if code then
		req:send(code, headers, body)
	end
end

return HttpServer
