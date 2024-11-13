local class = require("class")
local ffi = require("ffi")

---@class ngx.buf_t
---@operator call: ngx.buf_t
local ngx_buf_t = class()

---@param size integer
function ngx_buf_t:new(size)
	self.data = ffi.new("uint8_t[?]", size)
	self.start = 0
	self._end = size
	self.pos = 0
	self.last = 0
end

---@param b ngx.buf_t
function ngx_buf_t:clone_from(b)
	self.data = b.data
	self.start = b.start
	self._end = b._end
	self.pos = b.pos
	self.last = b.last
end

---@return ngx.buf_t
function ngx_buf_t:clone()
	return setmetatable({
		data = self.data,
		start = self.start,
		_end = self._end,
		pos = self.pos,
		last = self.last,
	}, ngx_buf_t)
end

---@param i integer?
---@return string
function ngx_buf_t:charAtPos0(i)
	local j = self.pos + (i or 0)
	return string.char(self.data[j])
end

---@param offset integer
---@return ffi.cdata*
function ngx_buf_t:get_ptr(offset)
	return self.data + offset
end

---@return string
function ngx_buf_t:sub()
	local chunk_size = self.last - self.pos
	return ffi.string(self.data + self.pos, chunk_size)
end

---@return string
function ngx_buf_t:sub_full()
	local chunk_size = self._end - self.start
	return ffi.string(self.data, chunk_size)
end

---@return integer
function ngx_buf_t:size()
	return self.last - self.pos
end

---@param offset integer
---@param c string
function ngx_buf_t:set(offset, c)
	self.data[offset] = c:byte()
end

---@param s string|ffi.cdata*
---@param size integer
---@return integer
function ngx_buf_t:ngx_copy(offset, s, size)
	ffi.copy(self.data + offset, s, size)
	return offset + size
end

---@param size integer
---@return integer
function ngx_buf_t:ngx_palloc(size)
	self.data = ffi.new("uint8_t[?]", size)
	return 0
end

---@return string
function ngx_buf_t:__tostring()
	return ("%q:%s-%s"):format(
		ffi.string(self.data, self:size()),
		self.pos, self.last
	)
end

return ngx_buf_t
