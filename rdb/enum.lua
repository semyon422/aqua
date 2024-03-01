local table_util = require("table_util")

return function(t)
	local enum = {}
	function enum.encode(k)
		local v = t[k]
		if v then
			return v
		end
		error("can not encode '" .. tostring(k) .. "'")
	end
	function enum.decode(v)
		local k = table_util.keyof(t, v)
		if k then
			return k
		end
		error("can not decode '" .. tostring(v) .. "'")
	end
	return enum
end
