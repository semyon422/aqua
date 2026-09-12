local ffi = require("ffi")
local jit = require("jit")

ffi.cdef [[
	typedef void* libiconv_t;
	libiconv_t libiconv_open (const char* tocode, const char* fromcode);
	size_t libiconv (libiconv_t cd, const char* * inbuf, size_t *inbytesleft, char* * outbuf, size_t *outbytesleft);
	int libiconv_close (libiconv_t cd);
]]

---@class ffi.namespace*
---@field libiconv_open fun(tocode: string, fromcode: string): ffi.cdata*
---@field libiconv fun(cd: ffi.cdata*, inbuf: ffi.cdata*?, inbytesleft: ffi.cdata*?, outbuf: ffi.cdata*?, outbytesleft: ffi.cdata*?): integer
---@field libiconv_close fun(cd: ffi.cdata*): integer

local library_name = jit.os == "Windows" and "libiconv-2" or "iconv"
local libiconv = ffi.load(library_name)
local iconv_open_error = ffi.cast("libiconv_t", -1)

---@class util.Iconv
---@field cd ffi.cdata*
local iconv = {}
iconv.__index = iconv

---@param tocode any
---@param fromcode any
---@return table?
---@return string?
function iconv:open(tocode, fromcode)
	local cd = libiconv.libiconv_open(tocode, fromcode)

	if cd == iconv_open_error then
		return nil, "iconv open error"
	end

	ffi.gc(cd, libiconv.libiconv_close)

	local obj = setmetatable({cd = cd}, self)

	return obj
end

function iconv:close()
	local cd = self.cd
	libiconv.libiconv_close(cd)
	ffi.gc(cd, nil)
end

local outbuff_size = 1024

---@param instr string
---@return string?
---@return string?
function iconv:convert(instr)
	-- These pointers are mutated by libiconv. They must start fresh for every
	-- conversion; reusing their previous offsets eventually writes past outbuff.
	local outbuff = ffi.new("char[?]", outbuff_size)
	local outbuff_ptr = ffi.new("char*[1]")
	outbuff_ptr[0] = outbuff
	local outbytesleft = ffi.new("size_t[1]", outbuff_size)
	local inbuff_ptr = ffi.new("const char*[1]")
	inbuff_ptr[0] = instr
	local inbytesleft = ffi.new("size_t[1]", #instr)

	---@type string[]
	local out = {}
	local cd = self.cd
	repeat
		local inbytesleft_before = inbytesleft[0]
		libiconv.libiconv(cd, inbuff_ptr, inbytesleft, outbuff_ptr, outbytesleft)
		if inbytesleft[0] == inbytesleft_before and inbytesleft[0] ~= 0 then
			libiconv.libiconv(cd, nil, nil, nil, nil)
			return nil, "failed"
		end
		out[#out + 1] = ffi.string(outbuff, outbuff_size - outbytesleft[0])
		outbuff_ptr[0] = outbuff
		outbytesleft[0] = outbuff_size
	until inbytesleft[0] == 0

	libiconv.libiconv(cd, nil, nil, nil, nil)
	return table.concat(out)
end

return iconv
