local gfx_util = {}

---@param text string
---@param x number
---@param baseline number
---@param limit number
---@param scale number
---@param ax string
function gfx_util.printBaseline(text, x, baseline, limit, scale, ax)
	local font = love.graphics.getFont()

	local y = baseline - font:getBaseline() * scale

	local status, err = pcall(love.graphics.printf, text, x, y, limit, ax, 0, scale)
	if not status then
		love.graphics.printf(err, x, y, limit, ax, 0, scale)
	end
end

---@param drawable any
---@param x number
---@param y number
---@param w number
---@param h number
---@param locate string
function gfx_util.drawFrame(drawable, x, y, w, h, locate)
	local dw = drawable:getWidth()
	local dh = drawable:getHeight()

	local s = 1
	local s1 = w / h <= dw / dh
	local s2 = w / h >= dw / dh

	if locate == "out" and s1 or locate == "in" and s2 then
		s = h / dh
	elseif locate == "out" and s2 or locate == "in" and s1 then
		s = w / dw
	end

	love.graphics.draw(drawable, x + (w - dw * s) / 2, y + (h - dh * s) / 2, 0, s)
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param ax string
---@param ay string
function gfx_util.printFrame(text, x, y, w, h, ax, ay)
	if w < 0 then
		x, w = w, -w
	end
	if h < 0 then
		y, h = h, -h
	end

	local font = love.graphics.getFont()
	local _, wrappedText = font:getWrap(text, w)
	local height = font:getHeight() * font:getLineHeight() * #wrappedText

	if ay == "center" then
		y = y + (h - height) / 2
	elseif ay == "bottom" then
		y = y + h - height
	end

	love.graphics.printf(text, x, y, w, ax, 0)
end

-- https://love2d.org/wiki/Gradients

---@param dir string
---@param ... table
---@return love.Mesh
function gfx_util.newGradient(dir, ...)
	local isHorizontal = true
	if dir == "vertical" then
		isHorizontal = false
	elseif dir ~= "horizontal" then
		error("bad argument #1 to 'gradient' (invalid value)", 2)
	end

	local colorLen = select("#", ...)
	if colorLen < 2 then
		error("color list is less than two", 2)
	end

	local meshData = {}
	if isHorizontal then
		for i = 1, colorLen do
			local color = select(i, ...)
			local x = (i - 1) / (colorLen - 1)

			meshData[#meshData + 1] = {x, 1, x, 1, unpack(color)}
			meshData[#meshData + 1] = {x, 0, x, 0, unpack(color)}
		end
	else
		for i = 1, colorLen do
			local color = select(i, ...)
			local y = (i - 1) / (colorLen - 1)

			meshData[#meshData + 1] = {1, y, 1, y, unpack(color)}
			meshData[#meshData + 1] = {0, y, 0, y, unpack(color)}
		end
	end

	return love.graphics.newMesh(meshData, "strip", "static")
end

---@param r number?
---@param g number?
---@param b number?
---@param a number?
---@return love.Image
function gfx_util.newPixel(r, g, b, a)
	local imageData = love.image.newImageData(1, 1)
	imageData:setPixel(0, 0, r or 1, g or 1, b or 1, a or 1)
	return love.graphics.newImage(imageData)
end

local transform
local args = {}

---@param ... any
---@return love.Transform
function gfx_util.transform(...)
	transform = transform or love.math.newTransform()

	local t = ...
	if type(t) ~= "table" then
		return transform:setTransformation(...)
	end

	for i = 1, 9 do
		local value = t[i]
		if type(value) == "table" then
			local w, h = love.graphics.getDimensions()
			args[i] = value[1] * w + value[2] * h + (value[3] or 0)
		elseif type(value) == "number" then
			args[i] = value
		elseif type(value) == "function" then
			args[i] = value()
		else
			error("Invalid value: " .. i)
		end
	end

	return transform:setTransformation(unpack(args))
end

local canvases = {}

---@param w number
---@param h number
---@return love.Canvas
local function newCanvas(w, h)
	local _, _, flags = love.window.getMode()
	return love.graphics.newCanvas(w, h, {msaa = flags.msaa})
end

---@param key any
---@return love.Canvas
function gfx_util.getCanvas(key)
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

local colorShader1

function gfx_util.setInverseColorScale()
	colorShader1 = colorShader1 or love.graphics.newShader([[
		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			vec4 pixel = Texel(texture, texture_coords);
			return color * (pixel - 1) + 1;
		}
	]])
	love.graphics.setShader(colorShader1)
end

local colorShader2

---@param r number|table
---@param g number?
---@param b number?
---@param a number?
function gfx_util.setPixelColor(r, g, b, a)
	if type(r) == "number" then
		r = {r, g, b, a}
	end
	colorShader2 = colorShader2 or love.graphics.newShader([[
		extern vec4 pixel;
		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			return pixel;
		}
	]])
	love.graphics.setShader(colorShader2)
	colorShader2:send("pixel", r)
end

---@param offset number
---@param size number
---@param _w table
---@return table
---@return table
function gfx_util.layout(offset, size, _w)
	local w = {}
	local x = {}

	local piexls = 0
	for i = 1, #_w do
		local v = _w[i]
		if v ~= "*" and v > 0 then
			piexls = piexls + _w[i]
		end
	end

	local pos = offset
	local fill = false
	for i = 1, #_w do
		local v = _w[i]
		w[i] = v
		if v == "*" then
			w[i] = 0
			assert(not fill)
			fill = true
		elseif v < 0 then
			w[i] = -v * (size - piexls)
		end
		pos = pos + w[i]
	end

	local rest = size - pos
	pos = offset

	for i = 1, #_w do
		if w[i] == 0 then
			w[i] = rest
		end
		x[i] = pos
		pos = pos + w[i]
	end

	return x, w
end

---@param imageData love.ImageData
---@return love.ImageData
function gfx_util.limitImageData(imageData)
	local size = love.graphics.getSystemLimits().texturesize
	local w, h = imageData:getDimensions()
	if w <= size and h <= size then
		return imageData
	end

	local _w, _h = math.min(w, size), math.min(h, size)
	local _imageData = love.image.newImageData(_w, _h)
	_imageData:paste(imageData, 0, 0, 0, 0, _w, _h)

	return _imageData
end

return gfx_util
