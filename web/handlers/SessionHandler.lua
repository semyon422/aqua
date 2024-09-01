local IHandler = require("web.IHandler")
local cookie_util = require("http.cookie_util")
local session_util = require("http.session_util")

---@class web.SessionContext: web.HandlerContext
---@field session table
local SessionContext = {}

---@class web.SessionHandler: web.IHandler
---@operator call: web.SessionHandler
local SessionHandler = IHandler + {}

---@param handler web.IHandler
---@param name string
---@param secret string
function SessionHandler:new(handler, name, secret)
	self.handler = handler
	self.name = name
	self.secret = secret
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function SessionHandler:handle(req, res, ctx)
	---@cast ctx +web.SessionContext

	local name, secret = self.name, self.secret

	local cookies = cookie_util.decode(req.headers["Cookie"])
	ctx.session = session_util.decode(cookies[name], secret) or {}

	self.handler:handle(req, res, ctx)

	cookies = {}
	cookies[name] = session_util.encode(ctx.session, secret)
	res.headers["Set-Cookie"] = cookie_util.encode(cookies)
end

return SessionHandler
