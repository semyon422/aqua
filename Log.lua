local Class = require("Class")

local Log = Class:new()

Log.write = function(self, name, ...)
	local args = {...}
	for i, v in ipairs(args) do
		args[i] = tostring(v)
	end
	local message = table.concat(args, "\t")

	if self.console then
		io.write(("[%-8s]: %s\n"):format(name:upper(), message))
	end
	if self.path then
		love.filesystem.append(self.path, ("[%-8s%s]: %s\n"):format(name:upper(), os.date(), message))
	end
end

return Log
