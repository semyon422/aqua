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

aquaevent.present = function()
	local width, height, flags = love.window.getMode()

	-- if not flags.vsync then
	-- 	love.timer.sleep(self.lastFrameStartTime + 1 / aquaevent.fpslimit - currentTime)
	-- end

	love.graphics.present()
end

aquaevent.run = function()
	love.math.setRandomSeed(os.time())
	love.timer.step()

	local updateDelta = 0
	local drawDelta = 0
	local drawStartTime, drawEndTime, presentStartTime, presentEndTime = 0, 0, 0, 0
	while false do
		local updateStartTime = love.timer.getTime()
		aquaevent.lastFrameStartTime = updateStartTime

		local width, height, flags = love.window.getMode()
		local fpslimit = flags.vsync and flags.refreshrate or aquaevent.fpslimit

		local eventPerFrame = 0
		local dt = 0.001
		for i = 1, math.huge do
			local eventTime = love.timer.getTime()

			aquaevent.handle()

			eventPerFrame = i

			if love.timer.getTime() - updateStartTime > 1 / fpslimit / 2 then
				break
			end
			
			love.timer.sleep(updateStartTime + i * dt - love.timer.getTime())
		end
		updateDelta = love.timer.getTime() - updateStartTime
		
		if love.graphics and love.graphics.isActive() then
			love.timer.step()
			love.update(love.timer.getDelta())

			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()

			drawStartTime = love.timer.getTime()
			love.draw()
			drawEndTime = love.timer.getTime()

			presentStartTime = love.timer.getTime()
			print(("%0.6f"):format(presentStartTime - presentEndTime))
			aquaevent.present()
			presentEndTime = love.timer.getTime()
		end
		drawDelta = drawEndTime - drawStartTime

		-- if presentEndTime - presentStartTime > 0.020 then
		-- 	print(presentEndTime - presentStartTime)
		-- end
		print(("frametime %0.3f"):format(love.timer.getTime() - updateStartTime))
		print(("%3d\t%0.3f\t%0.3f\t%0.3f"):format(eventPerFrame, updateDelta, drawDelta, presentEndTime - presentStartTime))
	end

	local time = love.timer.getTime()
	local eventTime = love.timer.getTime()
	while true do
		local currentTime = love.timer.getTime()

		if currentTime >= eventTime + 1 / aquaevent.tpslimit then
			aquaevent.handle()
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

			time = time + 1 / aquaevent.fpslimit
		end
		-- print(love.timer.getTime() - currentTime)
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
