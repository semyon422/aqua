local RequestLogsRepo = require("ai.router.RequestLogsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@return ai.router.RequestLogsRepo
---@return ai.router.RouterDatabase
local function open()
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	return RequestLogsRepo(storage.models), storage
end

---@param now integer
---@param status integer?
---@return ai.router.RequestLogRow
local function row(now, status)
	return {created_at = now, user = "alice", model = "fast", channel = "zai", upstream_model = "glm",
		protocol = "chat_completions", stream = true, status = status or 200, duration_ms = 1250,
		input_tokens = 10, output_tokens = 5, cached_input_tokens = 3, estimated = false}
end

---@param t testing.T
function test.persists_individual_rows_and_filters_safely(t)
	local repo, storage = open()
	repo:record(row(1000))
	repo:record(row(1001, 429))
	local other = row(1002)
	other.user, other.model, other.channel = "bob", "other", "openai"
	other.protocol, other.stream, other.estimated = "responses", false, true
	repo:record(other)
	local reloaded = RequestLogsRepo(storage.models)
	local rows = reloaded:list({}, 1002)
	t:eq(#rows, 3)
	t:eq(rows[1].id, 3)
	t:eq(rows[1].protocol, "responses")
	t:eq(rows[1].stream, false)
	t:eq(rows[1].estimated, true)
	rows = repo:list({user = "alice", model = "fast", channel = "zai", outcome = "error"}, 1002)
	t:eq(#rows, 1)
	t:eq(rows[1].status, 429)
	t:eq(rows[1].cached_input_tokens, 3)
	t:eq(rows[1].duration_ms, 1250)
	t:eq(#repo:list({outcome = "success"}, 1002), 2)
	t:eq(#repo:list({user = "' OR 1=1 --"}, 1002), 0)
	storage:close()
end

---@param t testing.T
function test.pagination_is_stable_when_new_requests_arrive(t)
	local repo, storage = open()
	repo.page_size = 2
	for now = 1000, 1004 do repo:record(row(now)) end
	local rows, cursor = repo:list({}, 1004)
	t:eq(rows[1].id, 5)
	t:eq(rows[2].id, 4)
	t:eq(cursor, 4)
	repo:record(row(1005))
	rows, cursor = repo:list({before = cursor}, 1005)
	t:eq(rows[1].id, 3)
	t:eq(rows[2].id, 2)
	t:eq(cursor, 2)
	rows, cursor = repo:list({before = cursor}, 1005)
	t:eq(#rows, 1)
	t:eq(rows[1].id, 1)
	t:eq(cursor, nil)
	storage:close()
end

---@param t testing.T
function test.retention_is_bounded_by_age_and_count_without_reusing_ids(t)
	local repo, storage = open()
	repo.max_rows, repo.retention_seconds = 2, 30
	repo:record(row(1000))
	repo:record(row(1010))
	repo:record(row(1020))
	local rows = repo:list({}, 1020)
	t:eq(#rows, 2)
	t:eq(rows[2].id, 2)
	t:eq(#repo:list({}, 1051), 0)
	repo:record(row(1060))
	rows = repo:list({}, 1060)
	t:eq(#rows, 1)
	t:eq(rows[1].id, 4)
	t:eq(#storage.db:query("SELECT * FROM router_request_logs"), 1)
	storage:close()
end

return test
