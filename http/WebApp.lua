local class = require("class")
local autoload = require("autoload")

local Router = require("http.Router")
local Views = require("http.Views")
local SessionHandler = require("web.handlers.SessionHandler")
local ParamsHandler = require("web.handlers.ParamsHandler")
local RouterHandler = require("web.handlers.RouterHandler")
local PageHandler = require("web.handlers.PageHandler")
local ErrorHandler = require("web.handlers.ErrorHandler")
local UsecaseHandler = require("web.handlers.UsecaseHandler")
local UserHandler = require("web.handlers.UserHandler")

---@class http.WebApp
---@operator call: http.WebApp
local WebApp = class()

---@param config table
---@param domain table
function WebApp:new(config, domain)
	local default_results = {
		forbidden = {403, "json", {["Content-Type"] = "application/json"}},
		not_found = {404, "json", {["Content-Type"] = "application/json"}},
	}

	local router = Router()
	router:route_many(require("routes"))

	local uch = UsecaseHandler(domain, autoload("usecases"), config)
	local ush = UserHandler(uch, domain)
	local sh = SessionHandler(ush, "session", config.secret)
	local ph = ParamsHandler(sh, autoload("body"), autoload("input"))
	local rh = RouterHandler(ph, router, default_results)
	local pageh = PageHandler(domain, config, autoload("pages"), Views(autoload("views")))

	self.read_handler = ErrorHandler(rh)
	self.write_handler = ErrorHandler(pageh)
end

---@param req web.IRequest
---@param res web.IResponse
function WebApp:handle(req, res)
	local ctx = {}
	if self.read_handler:handle(req, res, ctx) then
		return
	end
	self.write_handler:handle(req, res, ctx)
end

return WebApp
