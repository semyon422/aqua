local ffi = require("ffi")

ffi.cdef([[
int _libiconv_version;
typedef void* libiconv_t;
libiconv_t libiconv_open (const char* tocode, const char* fromcode);
size_t libiconv (libiconv_t cd, const char* * inbuf, size_t *inbytesleft, char* * outbuf, size_t *outbytesleft);
int libiconv_close (libiconv_t cd);
int libiconvctl (libiconv_t cd, int request, void* argument);
void libiconvlist (int (*do_one) (unsigned int namescount,
const char * const * names,
void* data),
void* data);
void libiconv_set_relocation_prefix (const char *orig_prefix,
const char *curr_prefix);
]])

local libcharset = ffi.load("libcharset-1")
local libiconv = ffi.load("libiconv-2")

local max_outbuff_size = 4096
local iconv_open_err = ffi.cast("libiconv_t", ffi.new("int", -1))

local iconv = {}
iconv.__index = iconv

iconv.open = function(self, tocode, fromcode, outbuff_size)
	local cd = libiconv.libiconv_open(tocode, fromcode)
	
	if cd == iconv_open_err then
		return false, "iconv open error"
	end
	
	ffi.gc(cd, libiconv.libiconv_close)
	
	local outbuff_size = outbuff_size or max_outbuff_size
	local outbuff = ffi.new("char[?]", outbuff_size)
	
	return setmetatable({
		cd = cd,
		outbuff_size = outbuff_size,
		outbuff = outbuff
	}, self)
end

iconv.close = function(self)
	local cd = self.cd
	libiconv.libiconv_close(cd)
	ffi.gc(cd, nil)
end

iconv.convert = function(self, instr)
	local out = {}
	
	local outbuff_size = self.outbuff_size
	local outbuff = self.outbuff
	local outbuff_ptr = ffi.new("char*[1]", outbuff)
	local outbytesleft = ffi.new("size_t[1]", outbuff_size)
	
	local inbuff_size = #instr
	local inbuff = ffi.new("char[?]", inbuff_size)
	ffi.copy(inbuff, instr, #instr)
	local inbuff_ptr = ffi.new("const char*[1]", inbuff)
	local inbytesleft = ffi.new("size_t[1]", inbuff_size)

	local ok = libiconv.libiconv(self.cd, inbuff_ptr, inbytesleft, outbuff_ptr, outbytesleft)
	if ok == -1ull then
		return false, "failed"
	end
	
	return ffi.string(outbuff, outbuff_size - outbytesleft[0])
end

return iconv
