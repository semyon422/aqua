local ISharedDict = require("web.nginx.ISharedDict")

---@class web.FakeSharedDictEntry
---@field value any
---@field expire_at number
---@field flags integer
---@field is_list? boolean

---@class web.FakeSharedDict : web.ISharedDict
---@field data table<ngx.shared.DICT.key, web.FakeSharedDictEntry>
---@field get_now fun(): number
---@operator call: web.FakeSharedDict
local FakeSharedDict = ISharedDict + {}

---@param get_now? fun(): number
function FakeSharedDict:new(get_now)
	self.get_now = get_now or os.time
	self.data = {}
end

---@private
---@param key ngx.shared.DICT.key
---@return web.FakeSharedDictEntry?
---@return web.FakeSharedDictEntry? stale_entry
function FakeSharedDict:_get_entry(key)
	local entry = self.data[key]
	if not entry then
		return
	end

	if entry.expire_at ~= 0 and entry.expire_at < self.get_now() then
		return nil, entry -- return entry as second value for get_stale
	end

	return entry
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.value? value
---@return ngx.shared.DICT.flags|string|nil flags_or_error
function FakeSharedDict:get(key)
	local entry = self:_get_entry(key)
	if not entry then
		return
	end
	return entry.value, entry.flags
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.value? value
---@return ngx.shared.DICT.flags|string flags_or_error
---@return boolean stale
function FakeSharedDict:get_stale(key)
	local entry = self.data[key]
	if not entry then
		return nil, "not found", false -- TODO: check 2nd arg on real shared dict
	end

	local now = self.get_now()
	local stale = entry.expire_at ~= 0 and entry.expire_at < now
	return entry.value, entry.flags, stale
end

---@private
---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function FakeSharedDict:_set(key, value, exptime, flags)
	local expire_at = 0
	if exptime and exptime > 0 then
		expire_at = self.get_now() + exptime
	end

	self.data[key] = {
		value = value,
		expire_at = expire_at,
		flags = flags or 0,
	}
	return true, nil, false
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function FakeSharedDict:set(key, value, exptime, flags)
	return self:_set(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function FakeSharedDict:safe_set(key, value, exptime, flags)
	return self:_set(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function FakeSharedDict:add(key, value, exptime, flags)
	if self:_get_entry(key) then
		return false, "exists", false
	end
	return self:_set(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function FakeSharedDict:safe_add(key, value, exptime, flags)
	return self:add(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.value
---@param exptime? ngx.shared.DICT.exptime
---@param flags? ngx.shared.DICT.flags
---@return boolean ok
---@return ngx.shared.DICT.error? error
---@return boolean forcible
function FakeSharedDict:replace(key, value, exptime, flags)
	if not self:_get_entry(key) then
		return false, "not found", false
	end
	return self:_set(key, value, exptime, flags)
end

---@param key ngx.shared.DICT.key
function FakeSharedDict:delete(key)
	self.data[key] = nil
end

---@param key ngx.shared.DICT.key
---@param value number
---@param init? number
---@param init_ttl? ngx.shared.DICT.exptime
---@return integer? new
---@return ngx.shared.DICT.error? error
---@return boolean? forcible
function FakeSharedDict:incr(key, value, init, init_ttl)
	local entry = self:_get_entry(key)
	if not entry then
		if init == nil then
			return nil, "not found"
		end
		local new_val = init + value
		self:_set(key, new_val, init_ttl)
		return new_val, nil, false
	end

	if type(entry.value) ~= "number" then
		return nil, "not a number"
	end

	entry.value = entry.value + value
	return entry.value, nil, false
end

---@private
function FakeSharedDict:_get_list(key, create)
	local entry = self:_get_entry(key)
	if not entry then
		if not create then
			return nil
		end
		entry = {value = {}, expire_at = 0, flags = 0, is_list = true}
		self.data[key] = entry
	end

	if not entry.is_list then
		return nil, "value not a list"
	end

	return entry.value
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.list_value
---@return number? len
---@return ngx.shared.DICT.error? error
function FakeSharedDict:lpush(key, value)
	local list, err = self:_get_list(key, true)
	if not list then
		return nil, err
	end
	table.insert(list, 1, value)
	return #list
end

---@param key ngx.shared.DICT.key
---@param value ngx.shared.DICT.list_value
---@return number? len
---@return ngx.shared.DICT.error? error
function FakeSharedDict:rpush(key, value)
	local list, err = self:_get_list(key, true)
	if not list then
		return nil, err
	end
	table.insert(list, value)
	return #list
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.list_value? item
---@return ngx.shared.DICT.error? error
function FakeSharedDict:lpop(key)
	local list, err = self:_get_list(key, false)
	if not list then
		return nil, err
	end
	if #list == 0 then
		return nil
	end
	return table.remove(list, 1)
end

---@param key ngx.shared.DICT.key
---@return ngx.shared.DICT.list_value? item
---@return ngx.shared.DICT.error? error
function FakeSharedDict:rpop(key)
	local list, err = self:_get_list(key, false)
	if not list then
		return nil, err
	end
	if #list == 0 then
		return nil
	end
	return table.remove(list)
end

---@param key ngx.shared.DICT.key
---@return number? len
---@return ngx.shared.DICT.error? error
function FakeSharedDict:llen(key)
	local list, err = self:_get_list(key, false)
	if not list then
		if err then return nil, err end
		return 0
	end
	return #list
end

---@param key ngx.shared.DICT.key
---@return number? ttl
---@return ngx.shared.DICT.error? error
function FakeSharedDict:ttl(key)
	local entry = self.data[key]
	if not entry then
		return nil, "not found"
	end

	local now = self.get_now()
	if entry.expire_at ~= 0 and entry.expire_at < now then
		return nil, "not found"
	end

	if entry.expire_at == 0 then
		return 0
	end

	return entry.expire_at - now
end

---@param key ngx.shared.DICT.key
---@param exptime ngx.shared.DICT.exptime
---@return boolean? ok
---@return ngx.shared.DICT.error? error
function FakeSharedDict:expire(key, exptime)
	local entry = self:_get_entry(key)
	if not entry then
		return nil, "not found"
	end

	if exptime == 0 then
		entry.expire_at = 0
	else
		entry.expire_at = self.get_now() + exptime
	end
	return true
end

function FakeSharedDict:flush_all()
	self.data = {}
end

---@param max_count? number
---@return number flushed
function FakeSharedDict:flush_expired(max_count)
	local now = self.get_now()
	local count = 0
	for key, entry in pairs(self.data) do
		if entry.expire_at ~= 0 and entry.expire_at < now then
			self.data[key] = nil
			count = count + 1
			if max_count and max_count > 0 and count >= max_count then
				break
			end
		end
	end
	return count
end

---@param max_count? number
---@return string[] keys
function FakeSharedDict:get_keys(max_count)
	local now = self.get_now()
	local keys = {}
	local count = 0
	for key, entry in pairs(self.data) do
		if entry.expire_at == 0 or entry.expire_at >= now then
			table.insert(keys, key)
			count = count + 1
			if max_count and max_count > 0 and count >= max_count then
				break
			end
		end
	end
	return keys
end

---@return number
function FakeSharedDict:capacity()
	return 1024 * 1024 * 1024 -- 1GB dummy
end

---@return number
function FakeSharedDict:free_space()
	return 1024 * 1024 * 1024 -- 1GB dummy
end

return FakeSharedDict
