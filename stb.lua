-- based on stretchy buffer

local ffi = require("ffi")

ffi.cdef [[
	void * realloc(void * ptr, size_t newsize);
	void free(void * ptr);
	typedef struct {} stb_t;
]]

local NULL = ffi.new("void *")

---@param p ffi.cdata*?
---@return integer
local function ptr_to_int(p)
	---@type integer
	return tonumber(ffi.cast("size_t", p))
end

---@type {[integer]: integer}
local buffers = {}

---@param _p ffi.cdata*?
---@param size integer
---@return ffi.cdata*
local function realloc(_p, size)
	buffers[ptr_to_int(_p)] = nil
	---@type ffi.cdata*
	local p = ffi.C.realloc(_p, size)
	assert(p ~= NULL)
	buffers[ptr_to_int(p)] = size
	return p
end

---@param _p ffi.cdata*?
local function free(_p)
	buffers[ptr_to_int(_p)] = nil
	ffi.C.free(_p)
end

---@param _p ffi.cdata*?
---@return integer?
local function get_size(_p)
	return buffers[ptr_to_int(_p)]
end

--------------------------------------------------------------------------------

local PREFIX_SIZE = 2 -- * ffi.sizeof("size_t")
---@alias util.StbHeader {[0]: integer, [1]: integer}

---@param a util.Stb
---@return ffi.cdata*
local function to_raw(a)
	assert(a, "invalid buffer")
	---@type ffi.cdata*
	local p = ffi.cast("size_t*", a) - PREFIX_SIZE
	assert(get_size(p), "invalid buffer")
	return p
end

---@param a ffi.cdata*
---@return util.Stb
local function to_stb(a)
	assert(a, "invalid buffer")
	---@type ffi.cdata*
	local p = ffi.cast("size_t*", a) + PREFIX_SIZE
	---@type util.Stb
	return ffi.cast("stb_t*", p)
end

---@param _p ffi.cdata*?
---@param size integer
---@return ffi.cdata*
local function grow_raw(_p, size)
	local p = realloc(_p, size + ffi.sizeof("size_t"))
	---@type util.StbHeader
	p = ffi.cast("size_t*", p)
	p[0] = size
	return p
end

---@param _p ffi.cdata*
---@return integer
local function size_raw(_p)
	assert(_p, "invalid buffer")
	---@type util.StbHeader
	local p = ffi.cast("size_t*", _p)
	return p[0]
end

---@param _p ffi.cdata*
---@param offset integer
local function seek_raw(_p, offset)
	assert(_p, "invalid buffer")
	---@type util.StbHeader
	local p = ffi.cast("size_t*", _p)
	assert(offset >= 0 and offset <= p[0])
	p[1] = offset
end

---@param _p ffi.cdata*
---@return integer
local function tell_raw(_p)
	assert(_p, "invalid buffer")
	---@type util.StbHeader
	local p = ffi.cast("size_t*", _p)
	return p[1]
end

--------------------------------------------------------------------------------

---@class util.Stb: ffi.cdata*
local Stb = {}

function Stb:free()
	free(to_raw(self))
	ffi.gc(self, nil)
end

---@param offset integer
function Stb:seek(offset)
	seek_raw(to_raw(self), offset)
end

---@param offset integer
function Stb:step(offset)
	local raw = to_raw(self)
	seek_raw(raw, tell_raw(raw) + offset)
end

---@return integer
function Stb:tell()
	return tell_raw(to_raw(self))
end

---@return integer
function Stb:size()
	return size_raw(to_raw(self))
end

---@param a util.Stb?
---@param size integer
---@return util.Stb
local function grow_stb(a, size)
	if a then ffi.gc(a, nil) end
	local _a = to_stb(grow_raw(a and to_raw(a), size))
	ffi.gc(_a, Stb.free)
	return _a
end

---@nodiscard
---@param size number
---@return util.Stb
function Stb:grow(size)
	if self:size() >= size then
		return self
	end
	return grow_stb(self, size)
end

ffi.metatype(ffi.typeof("stb_t"), {__index = Stb})

local stb = {}

---@param size integer
---@return util.Stb
function stb.new(size)
	return grow_stb(nil, size)
end

local buf = stb.new(100)
assert(buf:size() == 100)
assert(buf:tell() == 0)

buf:seek(10)
assert(buf:tell() == 10)

buf:step(20)
assert(buf:tell() == 30)

local _buf = buf:grow(1000) -- realloc may return same pointer
assert(_buf:size() == 1000)
_buf:free()

assert(not pcall(buf.grow, buf, 1))
assert(not pcall(buf.size, buf))
assert(not pcall(buf.tell, buf))
assert(not pcall(buf.seek, buf, 0))
assert(not pcall(buf.free, buf))

return stb
