local escape = require("socket.url").escape

-- from lapis
return function(t, sep)
	if sep == nil then
		sep = "&"
	end
	local i = 0
	local buf = {}
	for k, v in pairs(t) do
		local continue = false
		repeat
			if type(k) == "number" and type(v) == "table" then
				k, v = v[1], v[2]
				if v == nil then
					v = true
				end
			end
			if v == false then
				continue = true
				break
			end
			buf[i + 1] = escape(k)
			if v == true then
				buf[i + 2] = sep
				i = i + 2
			else
				buf[i + 2] = "="
				buf[i + 3] = escape(v)
				buf[i + 4] = sep
				i = i + 4
			end
			continue = true
		until true
		if not continue then
			break
		end
	end
	buf[i] = nil
	return table.concat(buf)
end
