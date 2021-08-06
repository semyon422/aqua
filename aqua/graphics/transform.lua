local cache = {}

local width, height = 0, 0

return function(t)
	local w, h = love.graphics.getDimensions()
	if width ~= w or height ~= h then
		cache = {}
		width, height = w, h
	end

	if cache[t] then
		return cache[t]
	end

	local hasFunction = false
	local args = {}
	for i = 1, 9 do
		local value = t[i]
		if type(value) == "table" then
			args[i] = value[1] * w + value[2] * h
		elseif type(value) == "number" then
			args[i] = value
		elseif type(value) == "function" then
			args[i] = value()
			hasFunction = true
		else
			error("Invalid value: " .. i)
		end
	end

	local transform = love.math.newTransform(unpack(args))
	if not hasFunction then
		cache[t] = transform
	end
	return transform
end
