local _json = require("json")
local encode = _json.encode
local decode = _json.decode

local json = {}

json.read = function(path)
	local file = io.open(path, "r")
	local content = file:read("*all")
	file:close()
	return decode(file:read("*all"))
end

json.write = function(path, object)
	local file = io.open(path, "w")
	file:write(encode(object))
	return file:close()
end

json.encode = encode
json.decode = decode

return json