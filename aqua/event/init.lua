local Observable = require("aqua.util.Observable")

local aquaevent = Observable:new()

aquaevent.fpslimit = 240
aquaevent.tpslimit = 240
aquaevent.time = 0

aquaevent.handle = function()
	love.event.pump()
	for name, a, b, c, d, e, f in love.event.poll() do
		if name == "quit" then
			if not love.quit or not love.quit() then
				return a
			end
		end
		love.handlers[name](a, b, c, d, e, f)
	end
end

aquaevent.run = function()
	love.math.setRandomSeed(os.time())
	math.randomseed(os.time())
	love.timer.step()

	local time = love.timer.getTime()
	aquaevent.time = time
	aquaevent.dt = 0
	while true do

		aquaevent.framestarted()
		aquaevent.handle()

		love.update(aquaevent.dt)

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw()
			love.graphics.present() -- all new events are readed when present() is called
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

return aquaevent
