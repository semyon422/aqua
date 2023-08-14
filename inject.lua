local class = require("class_new")

local function tryreq(s)
	if type(s) == "string" then
		s = require(s)
	end
	return s
end

local function inject(injects)
	for _mod, _obj in pairs(injects) do
		local mod = tryreq(_mod)
		local obj = tryreq(_obj)

		if type(mod) == "table" then
			local mt = assert(getmetatable(mod), ("not injectable module '%s'"):format(_mod))
			mt.__index = obj
		else
			local T = class(mod, true)
			if mod == obj then
				T.new = nil
			elseif type(obj) == "function" then
				function T:new(...)
					return obj(...)
				end
			else
				function T()
					return obj
				end
			end
		end
	end
end

return inject
