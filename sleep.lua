local ffi = require("ffi")
local jit = require("jit")

if jit.os == "Windows" then
	local winapi = require("winapi")
	return winapi.sleep
end

if jit.os ~= "Linux" then
	return love.timer.sleep
end

ffi.cdef [[
	struct timespec {
		long tv_sec;
		long tv_nsec;
	};
	int nanosleep(const struct timespec *__requested_time, struct timespec *__remaining);
]]

---@class C.timespec
---@field tv_sec integer
---@field tv_nsec integer

---@type {[0]: C.timespec}
local rt = ffi.new("struct timespec[1]")

---@param s number
local function nanosleep(s)
	local i, f = math.modf(s)
	rt[0].tv_sec = i
	rt[0].tv_nsec = f * 1e9
	ffi.C.nanosleep(rt, nil)
end

return nanosleep
