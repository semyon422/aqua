return function(t)
	local args = {}
	for i = 1, 9 do
		local value = t[i]
		if type(value) == "table" then
			local w, h = love.graphics.getDimensions()
			args[i] = value[1] * w + value[2] * h
		elseif type(value) == "number" then
			args[i] = value
		elseif type(value) == "function" then
			args[i] = value()
		else
			error("Invalid value: " .. i)
		end
	end

	return love.math.newTransform(unpack(args))
end
