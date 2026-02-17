local class = require("class")

---@class web.ISharedDict
---@operator call: web.ISharedDict
local ISharedDict = class()

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.value? value
---@return ngx.shared.DICT.flags|string|nil flags_or_error
function ISharedDict:get(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.value? value
---@return ngx.shared.DICT.flags|string flags_or_error
---@return boolean stale
function ISharedDict:get_stale(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function ISharedDict:set(key, value, exptime, flags)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function ISharedDict:safe_set(key, value, exptime, flags)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function ISharedDict:add(key, value, exptime, flags)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function ISharedDict:safe_add(key, value, exptime, flags)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function ISharedDict:replace(key, value, exptime, flags)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
function ISharedDict:delete(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value number
---@param init? number
---@param init_ttl? ngx.shared.DICT.exptime
---@return integer? new
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function ISharedDict:incr(key, value, init, init_ttl)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.list_value
---@return number? len
---@return ngx.shared.DICT.error? error
function ISharedDict:lpush(key, value)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.list_value
---@return number? len
---@return ngx.shared.DICT.error? error
function ISharedDict:rpush(key, value)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.list_value? item
---@return ngx.shared.DICT.error? error
function ISharedDict:lpop(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.list_value? item
---@return ngx.shared.DICT.error? error
function ISharedDict:rpop(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@return number? len
---@return ngx.shared.DICT.error? error
function ISharedDict:llen(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@return number? ttl
---@return ngx.shared.DICT.error? error
function ISharedDict:ttl(key)
	error("not implemented")
end

---@param key ngx.shared.DICT.key
---@param exptime ngx.shared.DICT.exptime
---@return boolean ok
---@return ngx.shared.DICT.error? error
function ISharedDict:expire(key, exptime)
	error("not implemented")
end

function ISharedDict:flush_all()
	error("not implemented")
end

---@param max_count? number
---@return number flushed
function ISharedDict:flush_expired(max_count)
	error("not implemented")
end

---@param max_count? number
---@return string[] keys
function ISharedDict:get_keys(max_count)
	error("not implemented")
end

---@return number
function ISharedDict:capacity()
	error("not implemented")
end

---@return number
function ISharedDict:free_space()
	error("not implemented")
end

return ISharedDict
