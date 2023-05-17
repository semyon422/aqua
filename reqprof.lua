local reqprof = {}

reqprof.max_level = 10
reqprof.blacklist = {}
reqprof.stats = {}

local enabled, target_enabled = false, false
function reqprof.enable()
	target_enabled = true
end
function reqprof.disable()
	target_enabled = false
end

local want_print

local getTime = love.timer.getTime
local level
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

local function pack(t, ...)
	for i = 1, t.n do
		t[i] = 0
	end
	t.n = select("#", ...)
	for i = 1, t.n do
		t[i] = select(i, ...)
	end
end

function reqprof.decorate(f, name)
	local arg_list = {n = 0}
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
		pack(arg_list, f(...))
		local _t = getTime()
		level = level - 1

		stats[name].time = stats[name].time + _t - t
		stats[name].calls = stats[name].calls + 1

		return unpack(arg_list, 1, arg_list.n)
	end
end

local function decorate_string(func_name)
	return ([[? = __reqprof.decorate(?, "?")]]):gsub("?", (func_name:gsub(":", ".")))
end

local function split(s, p)
	if not p then
		return
	end
	local a, b = s:find("\n", p, true)
	if not a then
		return false, s:sub(p)
	end
	return b + 1, s:sub(p, a - 1)
end

function reqprof.process(s, name)
	local lines = {}
	local func_name, is_return
	for _, line in split, s, 1 do
		local matched =
			line:match("^function ([%w%.:_]+)%(") or
			line:match("^local function ([%w_]+)%(") or
			line:match("^([%w%._]+) = function%(") or
			line:match("^local ([%w_]+) = function%(")

		if line:match("^return function%(") then
			line = line:gsub("^return function", "return __reqprof.decorate(function")
			matched = name
			is_return = true
		end

		func_name = func_name or matched
		if func_name and line:match("^end") or matched and line:match("end$") then
			if is_return then
				line = line .. ([[, "?")]]):gsub("?", name)
			else
				line = line .. " " .. decorate_string(func_name)
			end
			is_return = nil
			func_name = nil
		end

		table.insert(lines, line)
	end
	s = [[local __reqprof = require("reqprof") ]] .. table.concat(lines, "\n")
	assert(not func_name, s)
	return s
end

local _lua_loader = package.loaders[2]
local function lua_loader(name)
	name = name:gsub("%.", "/")

	local errors = {}

	for path in love.filesystem.getRequirePath():gsub("%?", name):gmatch("[^;]+") do
		for _, item in ipairs(reqprof.blacklist) do
			if path:find(item, 1, true) then
				return _lua_loader(name)
			end
		end
		local content = love.filesystem.read(path)
		if content then
			content = reqprof.process(content, name:match("([^/]+)$"))
			local loader, err = loadstring(content, path)
			if loader then
				return loader
			end
			error(err .. "\n" .. content)
		else
			table.insert(errors, ("no file '%s'"):format(path))
		end
	end

	return "\n\t" .. table.concat(errors, "\n\t")
end

function reqprof.replace_loader()
	package.loaders[2] = lua_loader
end

return reqprof
