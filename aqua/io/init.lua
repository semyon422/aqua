local Observable = require("aqua.util.Observable")

local io = Observable:new()

io.handle = function()
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

io.run = function()
	love.math.setRandomSeed(os.time())
	love.timer.step()
	
	while true do
		io.handle()
		
		love.timer.step()
		love.update(love.timer.getDelta())
		
		if love.graphics and love.graphics.isActive() then
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()
			love.draw()
			love.graphics.present()
		end
	end
end

io.callbacks = {
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
	"quit"
}

io.init = function()
	love.run = io.run
	
	for _, name in pairs(io.callbacks) do
		love[name] = function(...)
			return io:send({
				name = name,
				time = love.timer.getTime(),
				args = {...}
			})
		end
	end
end

return io
