local log_print = {}

local function open(path, truncate)
	-- io.open, not love.filesystem: PhysFS append seeks once on open instead of using O_APPEND.
	local file = assert(io.open(path, truncate and "w" or "a"))
	if truncate then
		file:close()
		file = assert(io.open(path, "a"))
	end
	local raw_print = print
	function print(...)
		raw_print(...)
		local t = {}
		for i = 1, select("#", ...) do
			t[i] = tostring((select(i, ...)))
		end
		file:write(table.concat(t, "\t") .. "\n")
		file:flush()
	end
end

---Replaces the global print with one that also writes to a log file,
---and shares the path so threads started later log there too.
---@param path string relative to the cwd
---@param truncate boolean? clear the file first
function log_print.install(path, truncate)
	open(path, truncate)
	-- A named channel is the one state every thread can read.
	local channel = love.thread.getChannel("log_print")
	channel:clear()
	channel:push(path)
end

---Called in thread bootstraps: appends to the main thread's log, if it installed one.
function log_print.inherit()
	local path = love.thread.getChannel("log_print"):peek()
	if path then
		open(path)
	end
end

return log_print
