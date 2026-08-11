local class = require("class")
local deco = require("deco")

local reqprof = {}

---@class reqprof.Stat
---@field name string
---@field time number
---@field calls integer
---@field nt_calls integer

reqprof.max_level = 10
---@type {[string]: reqprof.Stat}
reqprof.stats = {}

local enabled, target_enabled = false, false
function reqprof.enable()
	target_enabled = true
end
function reqprof.disable()
	target_enabled = false
end

---@type boolean?
local want_print

---@type fun(): number
local getTime = love.timer.getTime
---@type integer
local level = 0
---@type number?
local prev_time
local total_calls = 0
function reqprof.start()
	enabled = target_enabled

	if want_print then
		reqprof._print()
		want_print = false
	end

	reqprof.stats = {}
	level = 0

	local t = getTime()
	if prev_time then
		reqprof.stats.reqprof = {
			name = "reqprof",
			time = t - prev_time,
			calls = total_calls,
			nt_calls = 0,
		}
	end
	prev_time = t
	total_calls = 0
end

---@param a reqprof.Stat
---@param b reqprof.Stat
---@return boolean
local function sort_stats(a, b)
	return a.time < b.time
end

function reqprof.print()
	want_print = true
end

function reqprof._print()
	if not enabled then
		print("total calls: " .. total_calls)
	end

	local lname, lcalls, lnt_calls, ltime = #("function"), #("calls"), #("nt_calls"), #("time")
	---@type reqprof.Stat[]
	local stats_sorted = {}
	for _, stat in pairs(reqprof.stats) do
		table.insert(stats_sorted, stat)
		lname = math.max(lname, #tostring(stat.name))
		lcalls = math.max(lcalls, #tostring(stat.calls))
		lnt_calls = math.max(lnt_calls, #tostring(stat.nt_calls))
		ltime = math.max(ltime, #tostring(stat.time))
	end
	table.sort(stats_sorted, sort_stats)

	io.write(("%" .. lcalls .. "s "):format("calls"))
	io.write(("%" .. lnt_calls .. "s "):format("nt_calls"))
	io.write("name")
	io.write((" "):rep(lname - #("function") + 1))
	io.write("time")
	io.write("\n")
	for _, stat in ipairs(stats_sorted) do
		io.write(("%" .. lcalls .. "s "):format(stat.calls))
		io.write(("%" .. lnt_calls .. "s "):format(stat.nt_calls))
		io.write(stat.name)
		io.write((" "):rep(lname - #stat.name + 1))
		io.write(stat.time)
		io.write("\n")
	end
end

---@generic F: function
---@param f F
---@param name string
---@return F
function reqprof.decorate(f, name)
	---@param t number
	---@param stats {[string]: reqprof.Stat}
	local function return_measured(t, stats, ...)
		level = level - 1

		stats[name].time = stats[name].time + getTime() - t
		stats[name].calls = stats[name].calls + 1

		return ...
	end

	return function(...)
		total_calls = total_calls + 1

		if not enabled then
			return f(...)
		end

		local stats = reqprof.stats
		stats[name] = stats[name] or {
			name = name,
			time = 0,
			calls = 0,
			nt_calls = 0,
		}

		if level >= reqprof.max_level then
			stats[name].nt_calls = stats[name].nt_calls + 1
			return f(...)
		end

		level = level + 1
		local t = getTime()
		return return_measured(t, stats, f(...))
	end
end

---@class reqprof.ProfileDecorator: deco.FunctionDecorator
---@operator call: reqprof.ProfileDecorator
local ProfileDecorator = class(deco.FunctionDecorator)
reqprof.ProfileDecorator = ProfileDecorator

---@param func_name string
---@return string
function ProfileDecorator:func_end(func_name)
	local func = func_name:gsub(":", ".")
	return ([[? = require("reqprof").decorate(?, %q)]]):gsub("?", func):format(func_name)
end

return reqprof
