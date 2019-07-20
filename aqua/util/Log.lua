local Class = require("aqua.util.Class")

local Log = Class:new()

Log.log = function(self, name, ...)
	local message = table.concat({...}, "\t")
	
	local info = debug.getinfo(2, "Sl")
	local logString = ("[%-8s%s] %s: %s\n"):format(
		(name or ""):upper(),
		os.date(),
		info.short_src .. ":" .. info.currentline,
		message
	)
	
	if log.console then
		print(logString)
	end
	
	if self.path then
		local file = io.open(self.path, "a")
		file:write(logString)
		file:close()
	end
end

return Log
