local class = require("class")
local autoload = require("autoload")

local ParamsHandler = require("web.handlers.ParamsHandler")
local ErrorHandler = require("web.handlers.ErrorHandler")
local UserHandler = require("web.handlers.UserHandler")
local ProtectedHandler = require("web.handlers.ProtectedHandler")
local ConverterHandler = require("web.handlers.ConverterHandler")

local Router = require("web.router.Router")
local Views = require("web.page.Views")

local UsecaseHandler = require("web.usecase.UsecaseHandler")
local RouterHandler = require("web.router.RouterHandler")
local PageHandler = require("web.page.PageHandler")
local SessionHandler = require("web.cookie.SessionHandler")

---@class web.WebApp
---@operator call: web.WebApp
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

	local uc_h = UsecaseHandler(domain, autoload("usecases"), config)
	local user_h = UserHandler(uc_h, domain)
	local sh = SessionHandler(user_h, "session", config.secret)
	local ph = ParamsHandler(sh, autoload("body"))
	local ch = ConverterHandler(ph, autoload("input"))
	local rh = RouterHandler(ch, router, default_results)
	local page_h = PageHandler(domain, config, autoload("pages"), Views(autoload("views")))

	self.handler = ErrorHandler(ProtectedHandler(rh, page_h))
end

---@param req web.IRequest
---@param res web.IResponse
function WebApp:handle(req, res)
	self.handler:handle(req, res, {})
end

return WebApp
