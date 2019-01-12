local aqua = {}

aqua.audio = require("aqua.audio")
aqua.assets = require("aqua.assets")
aqua.graphics = require("aqua.graphics")
aqua.image = require("aqua.image")
aqua.io = require("aqua.io")
aqua.math = require("aqua.math")
aqua.package = require("aqua.package")
aqua.sound = require("aqua.sound")
aqua.string = require("aqua.string")
aqua.table = require("aqua.table")
aqua.thread = require("aqua.thread")
aqua.ui = require("aqua.ui")
aqua.utf8 = require("aqua.utf8")
aqua.util = require("aqua.util")

local callbacks = {
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

for _, name in pairs(callbacks) do
	love[name] = function(...)
		aqua.io:send({
			name = name,
			args = {...}
		})
	end
end

love.run = function()
	love.math.setRandomSeed(os.time())
	love.timer.step()
	
	while true do
		if love.event then
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

return aqua