return function(prefix)
	return setmetatable({}, {
		__index = function(self, mod_name)
			local mod = require(prefix .. "." .. mod_name)
			self[mod_name] = mod
			return mod
		end
	})
end
