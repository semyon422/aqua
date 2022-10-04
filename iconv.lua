local ffi = require("ffi")

ffi.cdef([[
typedef void* libiconv_t;
libiconv_t libiconv_open (const char* tocode, const char* fromcode);
size_t libiconv (libiconv_t cd, const char* * inbuf, size_t *inbytesleft, char* * outbuf, size_t *outbytesleft);
int libiconv_close (libiconv_t cd);
]])

local libiconv = ffi.load("iconv")

local iconv = {}
iconv.__index = iconv

iconv.open = function(self, tocode, fromcode)
	local cd = libiconv.libiconv_open(tocode, fromcode)

	if cd == -1 then
		return false, "iconv open error"
	end

	ffi.gc(cd, libiconv.libiconv_close)

	return setmetatable({cd = cd}, self)
end

iconv.close = function(self)
	local cd = self.cd
	libiconv.libiconv_close(cd)
	ffi.gc(cd, nil)
end

local outbuff_size = 1024
local outbuff = ffi.new("char[?]", outbuff_size)
local outbuff_ptr = ffi.new("char*[1]", outbuff)
local outbytesleft = ffi.new("size_t[1]", outbuff_size)

local inbuff_ptr = ffi.new("const char*[1]")
local inbytesleft = ffi.new("size_t[1]")

iconv.convert = function(self, instr)
	local out = {}

	inbuff_ptr[0] = instr
	inbytesleft[0] = #instr

	local cd = self.cd
	repeat
		local inbytesleft0 = inbytesleft[0]
		local ok = libiconv.libiconv(cd, inbuff_ptr, inbytesleft, outbuff_ptr, outbytesleft)
		-- if ok == -1ull then
		-- 	print("error", ffi.errno()) -- errno doesn't work
		-- end
		if inbytesleft[0] - inbytesleft0 == 0 and inbytesleft[0] ~= 0 then
			return false, "failed"
		end
		out[#out + 1] = ffi.string(outbuff, outbuff_size - outbytesleft[0])
		outbuff_ptr[0] = outbuff
		outbytesleft[0] = outbuff_size
	until inbytesleft[0] == 0

	libiconv.libiconv(cd, nil, nil, nil, nil)

	return table.concat(out)
end

return iconv
