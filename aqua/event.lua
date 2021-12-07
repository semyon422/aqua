local Observable = require("aqua.util.Observable")
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

aquaevent.handle = function()
	love.event.pump()

	local asynckeyWorking = aquaevent.asynckey and asynckey.supported and asynckey.started
	if asynckeyWorking then
		local aquaeventTime = aquaevent.time
		for event in asynckey.events do
			aquaevent.time = event.time
			if event.state then
				love.keypressed(event.key, event.key)
			else
				love.keyreleased(event.key, event.key)
			end
		end
		aquaevent.time = aquaeventTime
	end

	for name, a, b, c, d, e, f in love.event.poll() do
		if name == "quit" then
			if not love.quit or not love.quit() then
				return a
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
end

local dwmapi
if love.system.getOS() == "Windows" then
	local ffi = require("ffi")
	dwmapi = ffi.load("dwmapi")
	ffi.cdef("void DwmFlush();")
end

aquaevent.run = function()
	love.math.setRandomSeed(os.time())
	math.randomseed(os.time())
	love.timer.step()

	local time = love.timer.getTime()
	aquaevent.time = time
	aquaevent.startTime = time
	aquaevent.dt = 0

	return function()
		if aquaevent.asynckey and asynckey.supported and not asynckey.started then
			asynckey.start()
		end

		aquaevent.framestarted()
		aquaevent.handle()
		if aquaevent.needQuit then
			return 0
		end

		love.update(aquaevent.dt)

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw()
			love.graphics.getStats(aquaevent.stats)
			love.graphics.present() -- all new events are readed when present() is called
			if dwmapi and aquaevent.dwmflush then
				dwmapi.DwmFlush()
			end
		end
		aquaevent.dt = love.timer.step() -- so we use this moment of time to separate new and old events
		aquaevent.time = love.timer.getTime() - aquaevent.dt / 2 -- and use the mathematical expectation as the moment of their appearance in the frame period


		time = time + 1 / aquaevent.fpslimit
		time = math.max(time, love.timer.getTime())

		love.timer.sleep(time - love.timer.getTime())
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

aquaevent.init = function()
	love.run = aquaevent.run

	for _, name in pairs(aquaevent.callbacks) do
		love[name] = function(...)
			return aquaevent:send({
				name = name,
				time = aquaevent.time,
				args = {...}
			})
		end
	end
end

aquaevent.framestarted = function()
	return aquaevent:send({
		name = "framestarted",
		time = aquaevent.time,
		dt = aquaevent.dt
	})
end

aquaevent.quit = function()
	LuaMidi.gc()
	aquaevent.needQuit = true
end

return aquaevent
