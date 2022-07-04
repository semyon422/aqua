local canvases = {}

return function(key)
	local w, h = love.graphics.getDimensions()
	if not canvases[key] then
		canvases[key] = love.graphics.newCanvas(w, h)
		return canvases[key]
	end
	local canvas = canvases[key]
	if canvas:getWidth() ~= w or canvas:getHeight() ~= h then
		canvas:release()
		canvases[key] = love.graphics.newCanvas(w, h)
	end
	return canvases[key]
end
