---@class ai.router.UsageTotals
---@field requests integer
---@field errors integer
---@field input_tokens integer
---@field output_tokens integer
---@field cached_input_tokens integer
---@field estimated_requests integer
---@field cost_usd number

---@class ai.router.UsageHour: ai.router.UsageTotals
---@field bucket integer
---@field label string
---@field x number

---@class ai.router.UsageSection
---@field title string
---@field rows {key: string, item: ai.router.UsageTotals}[]

---@class ai.router.UsageSeries
---@field label string
---@field style string
---@field points string

---@class ai.router.UsageChart
---@field id string
---@field title string
---@field note string
---@field series ai.router.UsageSeries[]
---@field ticks {label: string, y: number}[]
---@field hours {x: number, width: number, label: string}[]

---@class ai.router.UsageDashboardData
---@field hours integer
---@field totals ai.router.UsageTotals
---@field timeline ai.router.UsageHour[]
---@field sections ai.router.UsageSection[]
---@field charts ai.router.UsageChart[]
---@field first_label string
---@field middle_label string
---@field last_label string
---@field generated_label string

---@class ai.router.UsageDashboardGenerator
local UsageDashboardGenerator = {}

---@return ai.router.UsageTotals
local function totals()
	return {requests = 0, errors = 0, input_tokens = 0, output_tokens = 0,
		cached_input_tokens = 0, estimated_requests = 0, cost_usd = 0}
end

---@param target ai.router.UsageTotals
---@param row ai.router.UsageTotals
local function add(target, row)
	target.requests = target.requests + row.requests
	target.errors = target.errors + row.errors
	target.input_tokens = target.input_tokens + row.input_tokens
	target.output_tokens = target.output_tokens + row.output_tokens
	target.cached_input_tokens = target.cached_input_tokens + row.cached_input_tokens
	target.estimated_requests = target.estimated_requests + row.estimated_requests
	target.cost_usd = target.cost_usd + row.cost_usd
end

---@param timeline ai.router.UsageHour[]
---@param id string
---@param title string
---@param note string
---@param fields {key: "requests"|"errors"|"input_tokens"|"output_tokens"|"cached_input_tokens", label: string, style: string}[]
---@return ai.router.UsageChart
local function chart(timeline, id, title, note, fields)
	local maximum = 0
	for _, hour in ipairs(timeline) do
		for _, field in ipairs(fields) do maximum = math.max(maximum, hour[field.key]) end
	end
	local magnitude = 10 ^ math.floor(math.log10(math.max(1, maximum / 4)))
	local step = magnitude
	for _, multiplier in ipairs({1, 2, 5, 10}) do
		step = magnitude * multiplier
		if step >= maximum / 4 then break end
	end
	local top = math.max(1, math.ceil(maximum / step)) * step
	---@type ai.router.UsageChart
	local result = {id = id, title = title, note = note, series = {}, ticks = {}, hours = {}}
	for value = 0, top, step do
		local label = value >= 1000000000 and ("%gB"):format(value / 1000000000)
			or value >= 1000000 and ("%gM"):format(value / 1000000)
			or value >= 1000 and ("%gk"):format(value / 1000) or ("%.0f"):format(value)
		table.insert(result.ticks, {label = label, y = 100 - value / top * 100})
	end
	for _, field in ipairs(fields) do
		---@type string[]
		local points = {}
		for _, hour in ipairs(timeline) do
			table.insert(points, ("%.2f,%.2f"):format(hour.x, 180 - hour[field.key] / top * 180))
		end
		table.insert(result.series, {label = field.label, style = field.style, points = table.concat(points, " ")})
	end
	for i, hour in ipairs(timeline) do
		local labels = {hour.label}
		for _, field in ipairs(fields) do
			table.insert(labels, ("%s: %.0f"):format(field.label, hour[field.key]))
		end
		table.insert(result.hours, {x = (i - 1) * 720 / #timeline, width = 720 / #timeline,
			label = table.concat(labels, " · ")})
	end
	return result
end

---@param history ai.router.UsageHistory
---@param hours integer
---@return ai.router.UsageDashboardData
function UsageDashboardGenerator.generate(history, hours)
	assert(hours == 24 or hours == 168, "expected 24 or 168 hourly buckets")
	local last = history.last_bucket
	local first = last - (hours - 1) * 3600
	---@type ai.router.UsageHour[]
	local timeline = {}
	for i = 1, hours do
		---@type ai.router.UsageHour
		local hour = totals()
		hour.bucket = first + (i - 1) * 3600
		hour.label = os.date("!%Y-%m-%d %H:00 UTC", hour.bucket)
		hour.x = (i - 0.5) * 720 / hours
		table.insert(timeline, hour)
	end
	---@type {title: string, field: "user"|"model"|"channel", entries: {[string]: ai.router.UsageTotals}}[]
	local groups = {{title = "By user", field = "user", entries = {}},
		{title = "By model", field = "model", entries = {}}, {title = "By channel", field = "channel", entries = {}}}
	---@type ai.router.UsageDashboardData
	local data = {hours = hours, totals = totals(), timeline = timeline, sections = {}, charts = {},
		first_label = os.date("!%d %b %H:%M", first),
		middle_label = os.date("!%d %b %H:%M", timeline[math.ceil(hours / 2)].bucket),
		last_label = os.date("!%d %b %H:%M", last), generated_label = os.date("!%Y-%m-%d %H:%M UTC", history.generated_at)}
	for _, row in ipairs(history.rows) do
		if row.bucket >= first and row.bucket <= last then
			add(data.totals, row)
			add(timeline[(row.bucket - first) / 3600 + 1], row)
			for _, group in ipairs(groups) do
				---@type string
				local name = row[group.field]
				local item = group.entries[name] or totals()
				group.entries[name] = item
				add(item, row)
			end
		end
	end
	for _, group in ipairs(groups) do
		---@type ai.router.UsageSection
		local section = {title = group.title, rows = {}}
		for name, item in pairs(group.entries) do table.insert(section.rows, {key = name, item = item}) end
		table.sort(section.rows, function(a, b)
			if a.item.requests == b.item.requests then return a.key < b.key end
			return a.item.requests > b.item.requests
		end)
		table.insert(data.sections, section)
	end
	data.charts = {
		chart(timeline, "requests", "Requests & errors", "Errors are included in requests; lines are not stacked.", {
			{key = "requests", label = "Requests", style = "primary"}, {key = "errors", label = "Errors", style = "danger"},
		}),
		chart(timeline, "tokens", "Tokens", "Cached input is included in input tokens; lines are not stacked.", {
			{key = "input_tokens", label = "Input", style = "primary"},
			{key = "output_tokens", label = "Output", style = "secondary"},
			{key = "cached_input_tokens", label = "Cached input", style = "cached"},
		}),
	}
	return data
end

return UsageDashboardGenerator
