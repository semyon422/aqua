local icc_co = {}

-- no coroutine.wrap because of
-- https://github.com/openresty/lua-nginx-module/issues/2406

---@param ok boolean
---@param ... any
---@return any ...
function icc_co.assert_pcall(ok, ...)
	if not ok then
		local level = 2
		error(debug.traceback(..., level), level)
	end
	return ...
end

---@param f async fun(...):...
---@return fun(...):...
---@nodiscard
function icc_co.wrap(f)
	local co = coroutine.create(f)
	return function(...)
		return icc_co.assert_pcall(coroutine.resume(co, ...))
	end
end

---@param f async fun(...):...
---@return fun(...):...
---@nodiscard
function icc_co.callwrap(f)
	return function(...)
		local co = coroutine.create(f)
		return icc_co.assert_pcall(coroutine.resume(co, ...))
	end
end

---@generic F: function
---@param f F
---@param result fun(ok: boolean, ...: any)
---@return thread
function icc_co.pcreate(f, result)
	return coroutine.create(function(...)
		result(pcall(f, ...))
	end)
end

---@generic F: function
---@param f F
---@param result fun(ok: boolean, ...: any)
---@return F
function icc_co.pwrap(f, result)
	return function(...)
		local co = icc_co.pcreate(f, result)
		return assert(coroutine.resume(co, ...))
	end
end

return icc_co
