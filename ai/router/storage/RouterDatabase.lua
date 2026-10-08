local class = require("class")
local TableOrm = require("rdb.TableOrm")
local Models = require("rdb.Models")
local SqliteMigrator = require("rdb.db.SqliteMigrator")
local users_model = require("ai.router.storage.models.router_users")
local user_models_model = require("ai.router.storage.models.router_user_models")
local subscriptions_model = require("ai.router.storage.models.router_subscriptions")
local models_model = require("ai.router.storage.models.router_models")
local windows_model = require("ai.router.storage.models.router_subscription_windows")
local usage_model = require("ai.router.storage.models.router_usage_models")
local io_util = require("io_util")

---@class ai.router.RouterDatabase
---@operator call: ai.router.RouterDatabase
---@field db rdb.SqliteDatabase
---@field orm rdb.TableOrm
---@field models rdb.Models
---@field migrator rdb.SqliteMigrator
---@field migrations table
local RouterDatabase = class()

RouterDatabase.path = "userdata/ai_router.db"
local user_version = 1

---@param db rdb.SqliteDatabase
function RouterDatabase:new(db)
	self.db = db
	self.orm = TableOrm(db)
	self.models = Models({
		router_users = users_model,
		router_user_models = user_models_model,
		router_subscriptions = subscriptions_model,
		router_models = models_model,
		router_subscription_windows = windows_model,
		router_usage_models = usage_model,
	}, self.orm)
	self.migrator = SqliteMigrator(db)
	self.migrations = {}
end

function RouterDatabase:open()
	local db = self.db
	db:open(self.path)
	local ok, err = pcall(function()
		db:exec("PRAGMA journal_mode = WAL")
		db:exec("PRAGMA synchronous = NORMAL")
		db:exec("PRAGMA busy_timeout = 10000")
		self:migrate()
	end)
	if not ok then
		db:close()
		error(err)
	end
end

function RouterDatabase:migrate()
	assert(self.db:user_version() <= user_version, "router database is newer than this code")
	local ok, err = pcall(function()
		if self.db:user_version() == 0 then
			self.db:exec("BEGIN")
			self.db:exec(io_util.read_file("aqua/ai/router/storage/db.sql"))
			self.db:user_version(user_version)
			self.db:exec("COMMIT")
		else
			self.migrator:migrate(user_version, self.migrations)
		end
	end)
	if not ok then
		self.db:exec("ROLLBACK")
		error(err)
	end
end

function RouterDatabase:close()
	self.db:close()
end

return RouterDatabase
