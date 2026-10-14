local OAuthRepo = require("ai.router.OAuthRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@param t testing.T
function test.persists_credentials_independently_per_channel(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	local repo = OAuthRepo(storage.models)
	repo:create(1)
	repo:create(2)
	local first = repo:get(1)
	t:eq(first.access_token, "")
	t:eq(first.expires_at, 0)
	repo:save(1, first.generation, {access_token = "access", refresh_token = "refresh", expires_at = 1234, account_id = "account"})
	local reloaded = OAuthRepo(storage.models):get(1)
	t:eq(reloaded.access_token, "access")
	t:eq(reloaded.refresh_token, "refresh")
	t:eq(reloaded.expires_at, 1234)
	t:eq(reloaded.account_id, "account")
	t:eq(repo:get(2).access_token, "")
	storage:close()
end

---@param t testing.T
function test.stale_refresh_cannot_recreate_or_overwrite_reused_channel_credentials(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	local repo = OAuthRepo(storage.models)
	repo:create(1)
	local old = repo:get(1)
	repo:delete(1)
	t:has_error(function() repo:save(1, old.generation, old) end)
	repo:create(1)
	t:ne(repo:get(1).generation, old.generation)
	t:has_error(function() repo:save(1, old.generation, old) end)
	t:eq(repo:get(1).refresh_token, "")
	storage:close()
end

return test
