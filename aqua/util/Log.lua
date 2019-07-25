local Class = require("aqua.util.Class")

local Log = Class:new()

Log.write = function(self, name, ...)
	local args = {...}
	for i, v in ipairs(args) do
		args[i] = tostring(v)
	end
	
	local message = table.concat(args, "\t")
	
	local info = debug.getinfo(2, "Sl")
	local logShort = ("[%-8s]: %s\n"):format(
		name:upper(),
		message
	)
	local logLong = ("[%-8s%s]: %s\n"):format(
		name:upper(),
		os.date(),
		message
	)
	
	if self.console then
		io.write(logShort)
	end
	
	if self.path then
		local file = io.open(self.path, "a")
		file:write(logLong)
		file:close()
	end
end

return Log
