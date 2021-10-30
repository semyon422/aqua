return function(r, g, b, a)
	local imageData = love.image.newImageData(1, 1)
	imageData:setPixel(0, 0, r or 1, g or 1, b or 1, a or 1)
	return love.graphics.newImage(imageData)
end
