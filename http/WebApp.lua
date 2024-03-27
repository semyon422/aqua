local class = require("class")
local autoload = require("autoload")

local Router = require("http.Router")
local SessionHandler = require("http.SessionHandler")
local RequestHandler = require("http.RequestHandler")
local Usecases = require("http.Usecases")
local Views = require("http.Views")

---@class http.WebApp
---@operator call: http.WebApp
local WebApp = class()

---@param config table
---@param domain table
---@param models table
function WebApp:new(config, domain, models)
	local usecases = Usecases(
		autoload("usecases"),
		config,
		domain
	)

	local views = Views(autoload("views"), usecases)

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
		body_handlers = autoload("body"),
		input_converters = autoload("input"),
		session_handler = session_handler,
		usecases = usecases,
		default_results = default_results,
		views = views,
		config = config,
		models = models,
	})
end

function WebApp:handle(req)
	local rh = self.requestHandler
	local ok, code, headers, body = xpcall(rh.handle, debug.traceback, rh, req)
	return ok, code, headers, body
end

return WebApp
