local ffi = require("ffi")

local avbuf = ffi.load("aqua/video/avbuf.so")

ffi.cdef [[
	typedef struct {
		uint8_t *ptr;
		int64_t offset;
		int64_t size;
	} Avbuf;
	int Avbuf_read(void *ptr, uint8_t *buf, int len);
	int64_t Avbuf_seek(void *ptr, int64_t pos, int whence);
]]

---@class ffi.namespace*
---@field Avbuf_read fun(ptr: ffi.cdata*, buf: ffi.cdata*, len: integer): integer
---@field Avbuf_seek fun(ptr: ffi.cdata*, pos: integer, whence: integer): integer

return avbuf
