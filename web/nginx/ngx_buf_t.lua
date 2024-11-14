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
function ngx_buf_t:clone(b)
	self.data = b.data
	self.start = b.start
	self._end = b._end
	self.pos = b.pos
	self.last = b.last
end

---@param i integer
---@param c integer
function ngx_buf_t:set(i, c)
	self.data[i] = c
end

---@param i integer
---@return integer
function ngx_buf_t:get(i)
	return self.data[i]
end

---@param offset integer?
---@return ffi.cdata*
function ngx_buf_t:ref(offset)
	return self.data + (offset or 0)
end

--- ngx_buf_size
---@return integer
function ngx_buf_t:size()
	return self.last - self.pos
end

---ngx_copy
---@param s string|ffi.cdata*
---@param size integer
---@return integer
function ngx_buf_t:copy(offset, s, size)
	ffi.copy(self.data + offset, s, size)
	return offset + size
end

---@return string
function ngx_buf_t:__tostring()
	return ("%q:%s-%s"):format(
		ffi.string(self.data, self:size()),
		self.pos, self.last
	)
end

return ngx_buf_t
