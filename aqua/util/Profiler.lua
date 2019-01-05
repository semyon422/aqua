local Class = require("aqua.util.Class")

local Profiler = Class:new()

local calls, total, this
Profiler.start = function(self)
	calls, total, this = {}, {}, {}
	debug.sethook(function(event)
		local i = debug.getinfo(2, "Sln")
		if i.what ~= 'Lua' then return end
		local func = i.short_src..':'..i.linedefined .. "\n" .. (i.name or "?")
		if event == 'call' then
			this[func] = os.clock()
		elseif this[func] then
			local time = os.clock() - this[func]
			total[func] = (total[func] or 0) + time
			calls[func] = (calls[func] or 0) + 1
		end
	end, "cr")
end

Profiler.stop = function(self)
	debug.sethook()
	local stats = {}
	for f, time in pairs(total) do
		table.insert(stats, {
			f, time, calls[f]
		})
	end
	table.sort(stats, function(a, b) return a[2] < b[2] end)
	print(("-"):rep(64))
	print("function, time, calls")
	for _, stat in ipairs(stats) do
		print(("%s\t%.3f\t%d"):format(stat[1], stat[2], stat[3]))
	end
end

return Profiler
