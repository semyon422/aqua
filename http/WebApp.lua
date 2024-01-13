local class = require("class")
local autoload = require("autoload")

local Router = require("http.Router")
local SessionHandler = require("http.SessionHandler")
local RequestHandler = require("http.RequestHandler")
local Validator = require("http.Validator")
local Usecases = require("http.Usecases")
local Views = require("http.Views")

local Access = require("abac.Access")

local Models = require("rdb.Models")
local TableOrm = require("rdb.TableOrm")
local LsqliteDatabase = require("rdb.LsqliteDatabase")

---@class http.WebApp
---@operator call: http.WebApp
local WebApp = class()

---@param config table
function WebApp:new(config)
	local db = LsqliteDatabase()
	db:open("db.sqlite")
	db:query("PRAGMA foreign_keys = ON;")
	self.db = db

	local models = Models(autoload("models"), TableOrm(db))
	local access = Access(autoload("rules"))
	local usecases = Usecases(
		autoload("usecases"),
		Validator(),
		models,
		access,
		config,
		function(uc, params)
			models:select(params, {session_user = {"users", {id = {"session", "user_id"}}, "user_roles"}})
		end
	)

	------------

	local views = Views(autoload("views"), usecases)

	------------

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
	})
end

function WebApp:handle(req)
	local rh = self.requestHandler
	local ok, code, headers, body = xpcall(rh.handle, debug.traceback, rh, req)
	return ok, code, headers, body
end

function WebApp:create_tables()
	for _, model_name in ipairs(model_list) do
		local mod = require("models." .. model_name)
		self.db:query(mod.create_query)
	end
end

return WebApp
