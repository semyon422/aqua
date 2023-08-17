local asynckey = {}
asynckey.delay = 0.001

if not love or love.system.getOS() ~= "Windows" then
	return asynckey
end

local keymap

---@param event table
---@return table
local function transform(event)
	local key = keymap[event.key]
	if key then
		event.key = key
	end
	return event
end

local threadCode
function asynckey.start()
	local thread = love.thread.newThread(threadCode:gsub("<delay>", asynckey.delay))
	thread:start()

	local channel = love.thread.getChannel("AsyncInputChannel")
	asynckey.events = coroutine.wrap(function()
		while true do
			local event = channel:pop()
			while event do
				coroutine.yield(transform(event))
				event = channel:pop()
			end
			coroutine.yield()
		end
	end)

	function asynckey.clear()
		channel:clear()
	end

	asynckey.start = nil
end

threadCode = [[
	local ffi = require("ffi")
	local bit = require("bit")

	ffi.cdef("int16_t GetAsyncKeyState(int vKey);")

	require("love.timer")

	local keys = {}
	for i = 0, 255 do
		keys[i] = false
	end

	local channel = love.thread.getChannel("AsyncInputChannel")
	local event = {}
	local function send(key, state, time)
		event.key = key
		event.state = state
		event.time = time
		channel:push(event)
	end

	while true do
		local time = love.timer.getTime()
		for key = 0, 255 do
			local state = bit.band(ffi.C.GetAsyncKeyState(key), 0x8000) ~= 0
			if keys[key] ~= state then
				send(key, state, time)
				keys[key] = state
			end
		end
		love.timer.sleep(<delay>)
	end
]]

keymap = {
	[0x08] = "backspace",
	[0x09] = "tab",
	[0x0C] = "kp5",
	[0x0D] = "return",
	[0x10] = "lshift",
	[0x11] = "rctrl",
	[0x12] = "lalt",
	[0x14] = "capslock",
	[0x1B] = "escape",
	[0x20] = "space",
	[0x21] = "pageup",
	[0x22] = "pagedown",
	[0x23] = "end",
	[0x24] = "home",
	[0x25] = "left",
	[0x26] = "up",
	[0x27] = "right",
	[0x28] = "down",
	[0x2C] = "printscreen",
	[0x2D] = "insert",
	[0x2E] = "delete",
	[0x30] = "0",
	[0x31] = "1",
	[0x32] = "2",
	[0x33] = "3",
	[0x34] = "4",
	[0x35] = "5",
	[0x36] = "6",
	[0x37] = "7",
	[0x38] = "8",
	[0x39] = "9",
	[0x41] = "a",
	[0x42] = "b",
	[0x43] = "c",
	[0x44] = "d",
	[0x45] = "e",
	[0x46] = "f",
	[0x47] = "g",
	[0x48] = "h",
	[0x49] = "i",
	[0x4A] = "j",
	[0x4B] = "k",
	[0x4C] = "l",
	[0x4D] = "m",
	[0x4E] = "n",
	[0x4F] = "o",
	[0x50] = "p",
	[0x51] = "q",
	[0x52] = "r",
	[0x53] = "s",
	[0x54] = "t",
	[0x55] = "u",
	[0x56] = "v",
	[0x57] = "w",
	[0x58] = "x",
	[0x59] = "y",
	[0x5A] = "z",
	[0x5B] = "lgui",
	[0x60] = "kp0",
	[0x61] = "kp1",
	[0x62] = "kp2",
	[0x63] = "kp3",
	[0x64] = "kp4",
	[0x65] = "kp5",
	[0x66] = "kp6",
	[0x67] = "kp7",
	[0x68] = "kp8",
	[0x69] = "kp9",
	[0x6A] = "kp*",
	[0x6B] = "kp+",
	[0x6D] = "kp-",
	[0x6E] = "kp.",
	[0x6F] = "kp/",
	[0x70] = "f1",
	[0x71] = "f2",
	[0x72] = "f3",
	[0x73] = "f4",
	[0x74] = "f5",
	[0x75] = "f6",
	[0x76] = "f7",
	[0x77] = "f8",
	[0x78] = "f9",
	[0x79] = "f10",
	[0x7A] = "f11",
	[0x7B] = "f12",
	[0x90] = "numlock",
	[0xA0] = "lshift",
	[0xA1] = "rshift",
	[0xA2] = "lctrl",
	[0xA3] = "rctrl",
	[0xA4] = "lalt",
	[0xAD] = "audiomute",
	[0xAE] = "volumedown",
	[0xAF] = "volumeup",
	[0xB0] = "audionext",
	[0xB1] = "audioprev",
	[0xB3] = "audioplay",
	[0xBA] = ";",
	[0xBB] = "=",
	[0xBC] = ",",
	[0xBD] = "-",
	[0xBE] = ".",
	[0xBF] = "/",
	[0xC0] = "`",
	[0xDB] = "[",
	[0xDC] = "\\",
	[0xDD] = "]",
	[0xDE] = "'",
}

return asynckey
