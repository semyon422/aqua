local class = require("class")

---@class ngx.buf_t
---@operator call: ngx.buf_t
local ngx_buf_t = class()

---@param data string
function ngx_buf_t:new(data)
	data = data or ""
	self.data = data
	self.start = 0
	self._end = #data
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

return ngx_buf_t
