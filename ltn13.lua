-- https://github.com/lunarmodules/luasocket/blob/master/ltn013.md

local ltn13 = {}

---@param ok boolean
---@param ... any?
---@return any?...
local function ret(ok, ...)
	if ok then return ... end
	return nil, ...
end

---@param f function
---@return function
function ltn13.protect(f)
	return function(...)
		return ret(pcall(f, ...))
	end
end

---@param f function?
---@return function
function ltn13.newtry(f)
	---@param ... any
	---@return any ...
	return function(...)
		local ok, err = ...
		if ok then return ... end
		if f then f() end
		error(err)
	end
end

return ltn13
