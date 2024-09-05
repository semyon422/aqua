local autoload = require("autoload")

local ParamsHandler = require("web.handlers.ParamsHandler")
local ErrorHandler = require("web.handlers.ErrorHandler")
local UserHandler = require("web.handlers.UserHandler")
local ProtectedHandler = require("web.handlers.ProtectedHandler")
local ConverterHandler = require("web.handlers.ConverterHandler")
local SequentialHandler = require("web.handlers.SequentialHandler")
local SelectHandler = require("web.handlers.SelectHandler")
local StaticHandler = require("web.handlers.StaticHandler")

local Router = require("web.router.Router")
local Views = require("web.page.Views")

local UsecaseHandler = require("web.usecase.UsecaseHandler")
local RouterHandler = require("web.router.RouterHandler")
local PageHandler = require("web.page.PageHandler")
local SessionHandler = require("web.cookie.SessionHandler")

local IHandler = require("web.IHandler")

---@class web.WebApp: web.IHandler
---@operator call: web.WebApp
local WebApp = IHandler + {}

---@param config table
---@param domain table
function WebApp:new(config, domain)
	local default_results = {
		forbidden = {403, "json", {["Content-Type"] = "application/json"}},
		not_found = {404, "json", {["Content-Type"] = "application/json"}},
	}

	local router = Router()
	router:route_many(require("routes"))

	local cpsuu = SequentialHandler({
		ConverterHandler(autoload("input")),
		ParamsHandler(autoload("body")),
		SessionHandler("session", config.secret, SequentialHandler({
			UserHandler(domain),
			UsecaseHandler(domain, autoload("usecases"), config, default_results),
		})),
	})

	local ro_seq_h = SequentialHandler({
		RouterHandler(router),
		SelectHandler(function(ctx)
			if not ctx.static then
				return cpsuu
			end
		end),
	})

	local static = StaticHandler()
	local page_h = PageHandler(domain, config, autoload("pages"), Views(autoload("views")))
	local w_seq_h = SelectHandler(function(ctx)
		if ctx.static then
			return static
		end
		return page_h
	end)

	self.handler = ErrorHandler(ProtectedHandler(ro_seq_h, w_seq_h))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function WebApp:handle(req, res, ctx)
	self.handler:handle(req, res, ctx)
end

return WebApp
