local class = require("class")

---@class ai.router.RequestLogRow
---@field id integer?
---@field created_at integer
---@field user string
---@field model string
---@field channel string
---@field upstream_model string
---@field protocol "responses"|"chat_completions"
---@field stream boolean
---@field status integer logical outcome, including failures after SSE commit
---@field duration_ms integer
---@field input_tokens integer
---@field output_tokens integer
---@field cached_input_tokens integer
---@field estimated boolean

---@class ai.router.RequestLogFilters
---@field before integer?
---@field user string?
---@field model string?
---@field channel string?
---@field outcome "success"|"error"?

-- Bounded metadata only: no prompts, responses, addresses, keys or error text.
---@class ai.router.RequestLogsRepo
---@operator call: ai.router.RequestLogsRepo
---@field models rdb.Models
local RequestLogsRepo = class()

RequestLogsRepo.max_rows = 10000
RequestLogsRepo.retention_seconds = 7 * 24 * 3600
RequestLogsRepo.page_size = 50

---@param models rdb.Models
function RequestLogsRepo:new(models)
	self.models = models
end

---@param row ai.router.RequestLogRow
function RequestLogsRepo:record(row)
	local model = self.models.router_request_logs
	model:create(row)
	model.orm:query("DELETE FROM router_request_logs WHERE created_at < ?", {row.created_at - self.retention_seconds})
	model.orm:query([[DELETE FROM router_request_logs WHERE id <=
		(SELECT id FROM router_request_logs ORDER BY id DESC LIMIT 1 OFFSET ?)]], {self.max_rows})
end

---@param filters ai.router.RequestLogFilters
---@param now integer
---@return ai.router.RequestLogRow[] rows
---@return integer? next_before
function RequestLogsRepo:list(filters, now)
	local clauses = {"created_at >= ?"}
	---@type (string|number)[]
	local values = {now - self.retention_seconds}
	for _, key in ipairs({"user", "model", "channel"}) do
		local value = filters[key]
		if value and value ~= "" then
			table.insert(clauses, key .. " = ?")
			table.insert(values, value)
		end
	end
	if filters.before then
		table.insert(clauses, "id < ?")
		table.insert(values, filters.before)
	end
	if filters.outcome == "error" then table.insert(clauses, "status >= 400")
	elseif filters.outcome == "success" then table.insert(clauses, "status < 400") end
	table.insert(values, self.page_size + 1)
	local rows = self.models.router_request_logs.orm:query("SELECT * FROM router_request_logs WHERE "
		.. table.concat(clauses, " AND ") .. " ORDER BY id DESC LIMIT ?", values)
	for _, row in ipairs(rows) do
		for _, key in ipairs({"id", "created_at", "status", "duration_ms", "input_tokens", "output_tokens", "cached_input_tokens"}) do
			row[key] = assert(tonumber(row[key]))
		end
		row.stream = row.stream == 1
		row.estimated = row.estimated == 1
	end
	local next_before
	if #rows > self.page_size then
		table.remove(rows)
		next_before = rows[#rows].id
	end
	return rows, next_before
end

return RequestLogsRepo
