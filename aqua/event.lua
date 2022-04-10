local Observable = require("aqua.util.Observable")
local aquathread = require("aqua.thread")
local aquatimer = require("aqua.timer")
local asynckey = require("aqua.asynckey")
local LuaMidi = require("luamidi")

local aquaevent = Observable:new()

aquaevent.fpslimit = 240
aquaevent.tpslimit = 240
aquaevent.time = 0
aquaevent.startTime = 0
aquaevent.needQuit = false
aquaevent.stats = {}
aquaevent.asynckey = false
aquaevent.dwmflush = false

local dwmapi
if love.system.getOS() == "Windows" then
	local ffi = require("ffi")
	dwmapi = ffi.load("dwmapi")
	ffi.cdef("void DwmFlush();")
end

local framestarted = {name = "framestarted"}
aquaevent.run = function()
	love.math.setRandomSeed(os.time())
	math.randomseed(os.time())
	love.timer.step()

	local fpsLimitTime = love.timer.getTime()
	aquaevent.time = fpsLimitTime
	aquaevent.startTime = fpsLimitTime
	aquaevent.dt = 0

	if aquaevent.asynckey and asynckey.supported and not asynckey.started then
		asynckey.start()
	end

	return function()
		aquaevent.dt = love.timer.step()
		aquaevent.time = love.timer.getTime()
		local aquaeventTime = aquaevent.time

		love.event.pump()

		framestarted.time = aquaevent.time
		framestarted.dt = aquaevent.dt
		aquaevent:send(framestarted)

		local asynckeyWorking = aquaevent.asynckey and asynckey.supported and asynckey.started
		if asynckeyWorking and love.window.hasFocus() then
			for event in asynckey.events do
				aquaevent.time = event.time
				if event.state then
					love.keypressed(event.key, event.key)
				else
					love.keyreleased(event.key, event.key)
				end
			end
		end

		aquaevent.time = aquaevent.time - aquaevent.dt / 2
		for name, a, b, c, d, e, f in love.event.poll() do
			if name == "quit" then
				if not love.quit or not love.quit() then
					return a or 0
				end
			end
			if not asynckeyWorking or name ~= "keypressed" and name ~= "keyreleased" then
				love.handlers[name](a, b, c, d, e, f)
			end
		end

		if LuaMidi.getinportcount() > 0 then
			local a, b, c, d = LuaMidi.getMessage(0)

			if a ~= nil and a == 144 then
				if c == 0 then
					love["midireleased"](b, c, d)
				else
					love["midipressed"](b, c, d)
				end
			end
		end
		aquaevent.time = aquaeventTime

		aquathread.update()
		aquatimer.update()
		love.update(aquaevent.dt)

		local frameEndTime
		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw()
			love.graphics.getStats(aquaevent.stats)
			love.graphics.present() -- all new events are read when present is called
			if dwmapi and aquaevent.dwmflush then
				dwmapi.DwmFlush()
			end
			frameEndTime = love.timer.getTime()
		end

		fpsLimitTime = math.max(fpsLimitTime + 1 / aquaevent.fpslimit, frameEndTime)
		love.timer.sleep(fpsLimitTime - frameEndTime)
	end
end

aquaevent.callbacks = {
	"update",
	"draw",
	"textinput",
	"keypressed",
	"keyreleased",
	"mousepressed",
	"gamepadpressed",
	"gamepadreleased",
	"joystickpressed",
	"joystickreleased",
	"midipressed",
	"midireleased",
	"mousemoved",
	"mousereleased",
	"wheelmoved",
	"resize",
	"quit",
	"filedropped",
	"directorydropped",
	"focus",
	"mousefocus",
}

-- all events are from [time - dt, time]
local clampEventTime = function(time)
	return math.min(math.max(time, aquaevent.time - aquaevent.dt), aquaevent.time)
end

aquaevent.init = function()
	love.run = aquaevent.run

	local e = {}
	for _, name in pairs(aquaevent.callbacks) do
		love[name] = function(...)
			e[1], e[2], e[3], e[4], e[5], e[6] = ...
			e.name = name
			e.time = clampEventTime(aquaevent.time)
			return aquaevent:send(e)
		end
	end
end

aquaevent.quit = function()
	LuaMidi.gc()
	return false
end

return aquaevent
