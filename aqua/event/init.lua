local Observable = require("aqua.util.Observable")

local aquaevent = Observable:new()

aquaevent.fpslimit = 240
aquaevent.tpslimit = 240

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
	love.timer.step()
	
	local time = love.timer.getTime()
	local eventTime = love.timer.getTime()
	while true do
		local currentTime = love.timer.getTime()

		if currentTime >= eventTime + 1 / aquaevent.tpslimit then
			aquaevent.handle()
			-- print("event ", 1 / (currentTime - eventTime))
			eventTime = math.max(currentTime, eventTime + 1 / aquaevent.tpslimit)
			
			love.timer.step()
			love.update(love.timer.getDelta())
		else
			love.timer.sleep(eventTime + 1 / aquaevent.tpslimit - love.timer.getTime())
		end

		if currentTime >= time + 1 / aquaevent.fpslimit then
			if love.graphics and love.graphics.isActive() then
				love.graphics.clear(love.graphics.getBackgroundColor())
				love.graphics.origin()
				love.draw()
				love.graphics.present()
			end

			-- print("draw ", 1 / (currentTime - time))
			time = time + 1 / aquaevent.fpslimit
		end
	end
end

aquaevent.callbacks = {
	"update",
	"draw",
	"textinput",
	"keypressed",
	"keyreleased",
	"mousepressed",
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
				time = love.timer.getTime(),
				args = {...}
			})
		end
	end
end

return aquaevent