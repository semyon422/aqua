local Container = require("aqua.graphics.Container")
local Drawable = require("aqua.graphics.Drawable")

local SpriteBatch = Container:new()

local newSpriteBatch = love.graphics.newSpriteBatch
SpriteBatch.construct = function(self, image, maxsprites)
	self.spriteBatch = newSpriteBatch(image, maxsprites)
	Container.construct(self)
end

local draw = love.graphics.draw
SpriteBatch.draw = function(self)
	local objectList = self.objectList
	local spriteBatch = self.spriteBatch
	for i = 1, #objectList do
		objectList[i]:batch(spriteBatch)
	end
	
	Drawable.switchColor(self)
	Drawable.switchBlendMode(self)
	
	draw(
		spriteBatch,
		0,
		0,
		0,
		1,
		1,
		0,
		0
	)
	
	return spriteBatch:clear()
end

return SpriteBatch
