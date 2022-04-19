local transform

local args = {}
return function(t)
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

	transform = transform or love.math.newTransform()
	return transform:setTransformation(unpack(args))
end
