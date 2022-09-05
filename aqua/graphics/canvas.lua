local canvases = {}

local function newCanvas(w, h)
	local _, _, flags = love.window.getMode()
	return love.graphics.newCanvas(w, h, {msaa = flags.msaa})
end

return function(key)
	local w, h = love.graphics.getDimensions()
	if not canvases[key] then
		canvases[key] = newCanvas(w, h)
		return canvases[key]
	end
	local canvas = canvases[key]
	if canvas:getWidth() ~= w or canvas:getHeight() ~= h then
		canvas:release()
		canvases[key] = newCanvas(w, h)
	end
	return canvases[key]
end
