-- based on stretchy buffer

local ffi = require("ffi")

ffi.cdef[[
	void * realloc(void * ptr, size_t newsize);
	void free(void * ptr);
	typedef struct {} stb_t;
]]

local NULL = ffi.new("void *")

local buffers = {}

---@class util.Stb: ffi.cdata*
local Stb = {}

---@param p util.Stb
---@return integer
local function stb_id(p)
	---@type integer
	return tonumber(ffi.cast("size_t", p))
end

---@param a util.Stb?
---@return ffi.cdata*
local function raw(a)
	if not a or not buffers[stb_id(a)] then
		return NULL
	end
	return ffi.cast("size_t*", a) - 1
end

function Stb:free()
	buffers[stb_id(self)] = nil
	ffi.C.free(raw(self))
	ffi.gc(self, nil)
end

---@return integer
function Stb:size()
	local p = raw(self)
	if p == NULL then
		return 0
	end
	---@type integer
	return tonumber(p[0])
end

---@param _p ffi.cdata*
---@param size integer
---@return ffi.cdata*
local function grow_raw(_p, size)
	local p = ffi.C.realloc(_p, size + ffi.sizeof("size_t"))
	assert(p ~= NULL)
	p = ffi.cast("size_t*", p)
	p[0] = size
	return p
end

---@param a util.Stb?
---@param size integer
---@return util.Stb
local function grow_stb(a, size)
	local _a = ffi.cast("stb_t*", grow_raw(raw(a), size) + 1)
	---@cast _a util.Stb
	buffers[stb_id(_a)] = true
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
	buffers[stb_id(self)] = nil
	ffi.gc(self, nil)
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
buf = buf:grow(200)
assert(buf:size() == 200)
buf:free()

return stb
