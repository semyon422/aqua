local ISharedDict = require("web.nginx.ISharedDict")

---@class web.NginxSharedDict : web.ISharedDict
---@field dict ngx.shared.DICT
---@operator call: web.NginxSharedDict
local NginxSharedDict = ISharedDict + {}

---@param dict ngx.shared.DICT
function NginxSharedDict:new(dict)
	self.dict = dict
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.value? value
---@return ngx.shared.DICT.flags|string|nil flags_or_error
function NginxSharedDict:get(key)
	return self.dict:get(key)
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.value? value
---@return ngx.shared.DICT.flags|string flags_or_error
---@return boolean stale
function NginxSharedDict:get_stale(key)
	return self.dict:get_stale(key)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function NginxSharedDict:set(key, value, exptime, flags)
	return self.dict:set(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function NginxSharedDict:safe_set(key, value, exptime, flags)
	return self.dict:safe_set(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function NginxSharedDict:add(key, value, exptime, flags)
	return self.dict:add(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function NginxSharedDict:safe_add(key, value, exptime, flags)
	return self.dict:safe_add(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function NginxSharedDict:replace(key, value, exptime, flags)
	return self.dict:replace(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
function NginxSharedDict:delete(key)
	return self.dict:delete(key)
end

---@param key ngx.shared.DICT.key
---@param value number
---@param init? number
---@param init_ttl? ngx.shared.DICT.exptime
---@return integer? new
---@return ngx.shared.DICT.error? error
---@return boolean? forcible
function NginxSharedDict:incr(key, value, init, init_ttl)
	return self.dict:incr(key, value, init, init_ttl)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.list_value
---@return number? len
---@return ngx.shared.DICT.error? error
function NginxSharedDict:lpush(key, value)
	return self.dict:lpush(key, value)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.list_value
---@return number? len
---@return ngx.shared.DICT.error? error
function NginxSharedDict:rpush(key, value)
	return self.dict:rpush(key, value)
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.list_value? item
---@return ngx.shared.DICT.error? error
function NginxSharedDict:lpop(key)
	return self.dict:lpop(key)
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.list_value? item
---@return ngx.shared.DICT.error? error
function NginxSharedDict:rpop(key)
	return self.dict:rpop(key)
end

---@param key ngx.shared.DICT.key
---@return number? len
---@return ngx.shared.DICT.error? error
function NginxSharedDict:llen(key)
	return self.dict:llen(key)
end

---@param key ngx.shared.DICT.key
---@return number? ttl
---@return ngx.shared.DICT.error? error
function NginxSharedDict:ttl(key)
	return self.dict:ttl(key)
end

---@param key ngx.shared.DICT.key
---@param exptime ngx.shared.DICT.exptime
---@return boolean? ok
---@return ngx.shared.DICT.error? error
function NginxSharedDict:expire(key, exptime)
	return self.dict:expire(key, exptime)
end

function NginxSharedDict:flush_all()
	return self.dict:flush_all()
end

---@param max_count? number
---@return number flushed
function NginxSharedDict:flush_expired(max_count)
	return self.dict:flush_expired(max_count)
end

---@param max_count? number
---@return string[] keys
function NginxSharedDict:get_keys(max_count)
	return self.dict:get_keys(max_count)
end

---@return number
function NginxSharedDict:capacity()
	return self.dict:capacity()
end

---@return number
function NginxSharedDict:free_space()
	return self.dict:free_space()
end

return NginxSharedDict
