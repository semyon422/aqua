local IHandler = require("web.IHandler")

---@class web.ProtectedHandler: web.IHandler
---@operator call: web.ProtectedHandler
local ProtectedHandler = IHandler + {}

---@param read_handler web.IHandler
---@param write_handler web.IHandler
function ProtectedHandler:new(read_handler, write_handler)
	self.read_handler = read_handler
	self.write_handler = write_handler
end

---@param self web.IResponse
local function write_error(self)
	self.write = nil
	error("write protected", 2)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function ProtectedHandler:handle(req, res, ctx)
	res.write = write_error
	local rh = self.read_handler
	local ok, err = xpcall(rh.handle, debug.traceback, rh, req, res, ctx)
	res.write = nil
	assert(ok, err)
	self.write_handler:handle(req, res, ctx)
end

return ProtectedHandler
