local class = require("class")
local autoload = require("autoload")

local Router = require("http.Router")
local SessionHandler = require("http.SessionHandler")
local RequestHandler = require("http.RequestHandler")
local Views = require("http.Views")

---@class http.WebApp
---@operator call: http.WebApp
local WebApp = class()

---@param config table
---@param domain table
function WebApp:new(config, domain)
	local session_handler = SessionHandler({
		name = "session",
		secret = config.secret,
	})

	local default_results = {
		forbidden = {403, "json", {["Content-Type"] = "application/json"}},
		not_found = {404, "json", {["Content-Type"] = "application/json"}},
	}

	local router = Router()
	router:route_many(require("routes"))

	self.requestHandler = RequestHandler({
		router = router,
		pages = autoload("pages"),
		body_handlers = autoload("body"),
		input_converters = autoload("input"),
		session_handler = session_handler,
		usecases = autoload("usecases"),
		default_results = default_results,
		views = Views(autoload("views")),
		config = config,
		domain = domain,
	})
end

---@param req web.IRequest
---@param res web.IResponse
function WebApp:handle(req, res)
	local rh = self.requestHandler
	local ok, code, headers, body = xpcall(rh.handle, debug.traceback, rh, req)

	if not ok then
		res.status = 500
		res:write("<pre>" .. tostring(code) .. "</pre>")
		return
	end

	if not code then
		res.status = 404
		res:write()
		return
	end

	res.status = code
	res.headers = headers
	res:write(body)
end

return WebApp
