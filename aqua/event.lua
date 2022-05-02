local Observable = require("aqua.util.Observable")
local aquathread = require("aqua.thread")
local aquatimer = require("aqua.timer")
local asynckey = require("aqua.asynckey")
local imgui = require("cimgui")
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
aquaevent.imguiShowDemoWindow = false

local midikeys = {}
for i = 1, 88 do
	midikeys[i] = false
end
aquaevent.midikeys = midikeys

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

	imgui.love.Init()

	require("aqua.imgui.config")

	return function()
		if aquaevent.asynckey and asynckey.start then
			asynckey.start()
		end

		aquaevent.dt = love.timer.step()
		aquaevent.time = love.timer.getTime()
		local aquaeventTime = aquaevent.time

		love.event.pump()

		framestarted.time = aquaevent.time
		framestarted.dt = aquaevent.dt
		aquaevent:send(framestarted)

		local asynckeyWorking = aquaevent.asynckey and asynckey.events
		if asynckeyWorking then
			if love.window.hasFocus() then
				for event in asynckey.events do
					aquaevent.time = event.time
					if event.state then
						love.keypressed(event.key, event.key)
					else
						love.keyreleased(event.key, event.key)
					end
				end
			else
				asynckey.clear()
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
			-- command, note, velocity, delta-time-to-last-event
			local a, b, c, d = LuaMidi.getMessage(0)

			if a ~= nil then
				if a == 144 then
					love.midipressed(b, c, d)
					midikeys[b] = true
				elseif a == 128 then
					love.midireleased(b, c, d)
					midikeys[b] = false
				end
			end
		end
		aquaevent.time = aquaeventTime

		aquathread.update()
		aquatimer.update()
		love.update(aquaevent.dt)
		imgui.love.Update(aquaevent.dt)
		imgui.NewFrame()

		local frameEndTime
		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw()
			love.graphics.origin()
			love.graphics.setColor(1, 1, 1, 1)
			if aquaevent.imguiShowDemoWindow then
				imgui.ShowDemoWindow()
			end
			imgui.Render()
			imgui.love.RenderDrawLists()
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

local callbacks = require("aqua.imgui.callbacks")

aquaevent.init = function()
	love.run = aquaevent.run

	local e = {}
	for _, name in pairs(aquaevent.callbacks) do
		love[name] = function(...)
			local icb = callbacks[name]
			if icb and icb(...) then return end
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
