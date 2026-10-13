local class = require("class")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local Server = require("ai.router.Server")
local AdminPages = require("ai.router.AdminPages")
local Management = require("ai.router.Management")
local McpTools = require("ai.router.McpTools")
local McpServer = require("mcp.Server")
local UsageMonitor = require("ai.router.UsageMonitor")
local UsageRepo = require("ai.router.UsageRepo")
local UsersRepo = require("ai.router.UsersRepo")
local SubscriptionsRepo = require("ai.router.SubscriptionsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local WindowsRepo = require("ai.router.WindowsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

---@class ai.router.testing.Stack
---@operator call: ai.router.testing.Stack
---@field storage ai.router.RouterDatabase
---@field scheduler web.CosocketScheduler
---@field server ai.router.Server
---@field admin ai.router.AdminPages
---@field management ai.router.Management
---@field mcp mcp.Server
---@field users ai.router.UsersRepo
---@field subscriptions ai.router.SubscriptionsRepo
---@field models ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
local Stack = class()

Stack.password = "admin-password-admin-password"
Stack.token = "test-management-token-test-management-token"

function Stack:new()
	self.scheduler = CosocketScheduler()
	self.storage = RouterDatabase(LjsqliteDatabase())
	self.storage.path = ":memory:"
	self.storage:open()
	self.users = UsersRepo(self.storage.models)
	self.subscriptions = SubscriptionsRepo(self.storage.models)
	self.models = ModelsRepo(self.storage.models)
	self.usage_repo = UsageRepo(self.storage.models)
	self.monitor = UsageMonitor({usage_repo = self.usage_repo, windows_repo = WindowsRepo(self.storage.models), logger = function() end})
	self.server = Server({scheduler = self.scheduler, users_repo = self.users, usage_repo = self.usage_repo,
		monitor = self.monitor, logger = function() end, provider_factory = function() return nil end})
	self.server:reload({}, {})
	local options = {users_repo = self.users, subscriptions_repo = self.subscriptions, models_repo = self.models,
		usage_repo = self.usage_repo, monitor = self.monitor, server = self.server, password = self.password}
	self.admin = AdminPages(options)
	self.management = Management(options)
	self.server.admin_handler = function(req, res) return self.admin:handle(req, res) end
	self.mcp = McpServer(self.scheduler, McpTools.create(self.management), {
		host = "127.0.0.1", port = 0, token = self.token, server_info = {name = "ai-router", version = "test"},
	})
	assert(self.server:start("127.0.0.1", 0))
	assert(self.mcp:start())
end

function Stack:close()
	self.mcp:stop()
	self.server:stop()
	self.storage:close()
end

return Stack
