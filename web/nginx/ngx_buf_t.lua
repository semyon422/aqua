local class = require("class")
local ffi = require("ffi")

---@class ngx.buf_t
---@operator call: ngx.buf_t
local ngx_buf_t = class()

---@param size integer
function ngx_buf_t:new(size)
	self.data = (" "):rep(size)
	self.start = 0
	self._end = size
	self.pos = 0
	self.last = 0
end

---@param i integer?
---@return string
function ngx_buf_t:charAtPos0(i)
	local j = self.pos + (i or 0) + 1
	return self.data:sub(j, j)
end

---@return string
function ngx_buf_t:sub()
	return self.data:sub(self.pos + 1, self.last)
end

---@return integer
function ngx_buf_t:size()
	return self._end - self.start
end

---@param offset integer
---@param c string
function ngx_buf_t:set(offset, c)
	local data = self.data
	self.data = data:sub(1, offset) .. c .. data:sub(offset + 2)
end

---@param s string
---@param size integer
---@return integer
function ngx_buf_t:ngx_copy(offset, s, size)
	local b = ffi.new("uint8_t[?]", #self.data, self.data)
	ffi.copy(b + offset, s, size)
	self.data = ffi.string(b, #self.data)
	return offset + size
end

return ngx_buf_t
