local ffi = require("ffi")

local c7z = ffi.load("/usr/lib/p7zip/7z.so")

local l7z = {}

ffi.cdef[[
	void * malloc(size_t size);
	void free(void * ptr);

	typedef unsigned int UInt32;
	typedef int64_t Int64;
	typedef uint64_t UInt64;
	typedef int SRes;
	typedef unsigned char Byte;
	typedef size_t SizeT;
	typedef short Int16;
	typedef unsigned short UInt16;

	typedef UInt16 CLzmaProb;

	typedef enum {
		LZMA_FINISH_ANY,
		LZMA_FINISH_END
	} ELzmaFinishMode;

	typedef enum {
		LZMA_STATUS_NOT_SPECIFIED,
		LZMA_STATUS_FINISHED_WITH_MARK,
		LZMA_STATUS_NOT_FINISHED,
		LZMA_STATUS_NEEDS_MORE_INPUT,
		LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK
	} ELzmaStatus;

	typedef struct ISzAlloc ISzAlloc;
	typedef const ISzAlloc * ISzAllocPtr;

	struct ISzAlloc {
		void *(*Alloc)(ISzAllocPtr p, size_t size);
		void (*Free)(ISzAllocPtr p, void *address);
	};

	typedef struct {
		int level;
		UInt32 dictSize;
		int lc;
		int lp;
		int pb;
		int algo;
		int fb;
		int btMode;
		int numHashBytes;
		unsigned numHashOutBits;
		UInt32 mc;
		unsigned writeEndMark;
		int numThreads;
		UInt64 reduceSize;
		UInt64 affinity;
	} CLzmaEncProps;

	typedef const struct ICompressProgress_ *ICompressProgressPtr;

	struct ICompressProgress_ {
		SRes (*Progress)(ICompressProgressPtr p, UInt64 inSize, UInt64 outSize);
	};

	void LzmaEncProps_Init(CLzmaEncProps *p);
	void LzmaEncProps_Normalize(CLzmaEncProps *p);

	SRes LzmaDecode(Byte *dest, SizeT *destLen, const Byte *src, SizeT *srcLen,
	const Byte *propData, unsigned propSize, ELzmaFinishMode finishMode,
	ELzmaStatus *status, ISzAllocPtr alloc);

	SRes LzmaEncode(Byte *dest, SizeT *destLen, const Byte *src, SizeT srcLen,
	const CLzmaEncProps *props, Byte *propsEncoded, SizeT *propsSize, int writeEndMark,
	ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	typedef struct ISeqInStream *ISeqInStreamPtr;
	typedef struct ISeqInStream ISeqInStream;
	struct ISeqInStream {
		SRes (*Read)(ISeqInStreamPtr p, void *buf, size_t *size);
			/* if (input(*size) != 0 && output(*size) == 0) means end_of_stream.
			(output(*size) < input(*size)) is allowed */
	};

	typedef struct ISeqOutStream *ISeqOutStreamPtr;
	typedef struct ISeqOutStream ISeqOutStream;
	struct ISeqOutStream {
		size_t (*Write)(ISeqOutStreamPtr p, const void *buf, size_t size);
			/* Returns: result - the number of actually written bytes.
			(result < size) means error */
	};

	typedef struct CLzmaEnc CLzmaEnc;
	typedef CLzmaEnc * CLzmaEncHandle;

	CLzmaEncHandle LzmaEnc_Create(ISzAllocPtr alloc);
	void LzmaEnc_Destroy(CLzmaEncHandle p, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	SRes LzmaEnc_SetProps(CLzmaEncHandle p, const CLzmaEncProps *props);
	void LzmaEnc_SetDataSize(CLzmaEncHandle p, UInt64 expectedDataSiize);
	SRes LzmaEnc_WriteProperties(CLzmaEncHandle p, Byte *properties, SizeT *size);
	unsigned LzmaEnc_IsWriteEndMark(CLzmaEncHandle p);

	SRes LzmaEnc_Encode(CLzmaEncHandle p, ISeqOutStreamPtr outStream, ISeqInStreamPtr inStream,
		ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);
	SRes LzmaEnc_MemEncode(CLzmaEncHandle p, Byte *dest, SizeT *destLen, const Byte *src, SizeT srcLen,
		int writeEndMark, ICompressProgressPtr progress, ISzAllocPtr alloc, ISzAllocPtr allocBig);

	typedef struct {
		Byte lc;
		Byte lp;
		Byte pb;
		Byte _pad_;
		UInt32 dicSize;
	} CLzmaProps;

	SRes LzmaProps_Decode(CLzmaProps *p, const Byte *data, unsigned size);

	typedef struct {
		CLzmaProps prop;
		CLzmaProb *probs;
		CLzmaProb *probs_1664;
		Byte *dic;
		SizeT dicBufSize;
		SizeT dicPos;
		const Byte *buf;
		UInt32 range;
		UInt32 code;
		UInt32 processedPos;
		UInt32 checkDicSize;
		UInt32 reps[4];
		UInt32 state;
		UInt32 remainLen;
		UInt32 numProbs;
		unsigned tempBufSize;
		Byte tempBuf[20];
	} CLzmaDec;

	void LzmaDec_Init(CLzmaDec *p);

	SRes LzmaDec_AllocateProbs(CLzmaDec *p, const Byte *props, unsigned propsSize, ISzAllocPtr alloc);
		void LzmaDec_FreeProbs(CLzmaDec *p, ISzAllocPtr alloc);

	SRes LzmaDec_Allocate(CLzmaDec *p, const Byte *props, unsigned propsSize, ISzAllocPtr alloc);
		void LzmaDec_Free(CLzmaDec *p, ISzAllocPtr alloc);

	SRes LzmaDec_DecodeToBuf(CLzmaDec *p, Byte *dest, SizeT *destLen,
		const Byte *src, SizeT *srcLen, ELzmaFinishMode finishMode, ELzmaStatus *status);
]]

local res_codes = {
	SZ_OK = 0,
	SZ_ERROR_DATA = 1,
	SZ_ERROR_MEM = 2,
	SZ_ERROR_CRC = 3,
	SZ_ERROR_UNSUPPORTED = 4,
	SZ_ERROR_PARAM = 5,
	SZ_ERROR_INPUT_EOF = 6,
	SZ_ERROR_OUTPUT_EOF = 7,
	SZ_ERROR_READ = 8,
	SZ_ERROR_WRITE = 9,
	SZ_ERROR_PROGRESS = 10,
	SZ_ERROR_FAIL = 11,
	SZ_ERROR_THREAD = 12,
	SZ_ERROR_ARCHIVE = 16,
	SZ_ERROR_NO_ARCHIVE = 17,
}

local LZMA_DIC_MIN = bit.lshift(1, 12)
local LZMA_PROPS_SIZE = 5
local HEADER_SIZE = LZMA_PROPS_SIZE + 8

local g_alloc_p = ffi.new("ISzAlloc[1]")
local g_alloc = g_alloc_p[0]
function g_alloc.Alloc(p, size)
	return ffi.C.malloc(size)
end
function g_alloc.Free(p, address)
	return ffi.C.free(address)
end

local function get_default_props_p()
	local props_p = ffi.new("CLzmaEncProps[1]")
	c7z.LzmaEncProps_Init(props_p)
	c7z.LzmaEncProps_Normalize(props_p)
	return props_p
end

--- for some reason LzmaProps_Decode does not work
--- also write to CLzmaEncProps instead of CLzmaProps
---@param p ffi.cdata*
---@param data_p ffi.cdata*
---@param size integer
---@return integer
local function props_decode(p, data_p, size)
	if size < LZMA_PROPS_SIZE then
		return res_codes.SZ_ERROR_UNSUPPORTED
	end

	local dicSize = bit.bor(data_p[1], bit.lshift(data_p[2], 8), bit.lshift(data_p[3], 16), bit.lshift(data_p[4], 24))
	if dicSize < LZMA_DIC_MIN then
		dicSize = LZMA_DIC_MIN
	end
	p.dictSize = dicSize

	local d = data_p[0]
	if d >= 9 * 5 * 5 then
		return res_codes.SZ_ERROR_UNSUPPORTED
	end

	p.lc = d % 9
	d = math.floor(d / 9)
	p.pb = d / 5
	p.lp = d % 5

	return res_codes.SZ_OK
end

--------------------------------------------------------------------------------
--- WIP streamning functions
--------------------------------------------------------------------------------

---@param s string
---@return string
function l7z.compress_stream_s(s)
	local src_p = ffi.cast("const unsigned char *", s)
	local src_size = #s

	local enc_handle = c7z.LzmaEnc_Create(g_alloc_p)

	local props = get_default_props_p()
	props[0].writeEndMark = 1

	assert(c7z.LzmaEnc_SetProps(enc_handle, props) == res_codes.SZ_OK)

	local out_props_size = ffi.new("size_t[1]", LZMA_PROPS_SIZE)
	local out_props = ffi.new("unsigned char[?]", LZMA_PROPS_SIZE)
	local res = c7z.LzmaEnc_WriteProperties(enc_handle, out_props, out_props_size)
	assert(res == res_codes.SZ_OK and out_props_size[0] == LZMA_PROPS_SIZE)

	local out = {}
	table.insert(out, ffi.string(out_props, out_props_size[0]))

	local data_size_s_p = ffi.new("uint8_t[8]")
	local data_size_i_p = ffi.cast("uint64_t*", data_size_s_p)
	data_size_i_p[0] = src_size
	table.insert(out, ffi.string(data_size_s_p, 8))

	local function read(buf, size)
		if src_size == 0 then
			size[0] = 0  -- end of stream
			return true
		end

		local copy_size = src_size
		if copy_size > size[0] then
			copy_size = size[0]
		end

		ffi.copy(buf, src_p, copy_size)
		size[0] = copy_size
		src_size = src_size - copy_size
		src_p = src_p + copy_size

		return true
	end

	local function write(buf, size)
		table.insert(out, ffi.string(buf, size))
		return size
	end

	local in_stream_p = ffi.new('ISeqInStream[1]')
	in_stream_p[0].Read = function(p, buf, size)  -- ISeqInStreamPtr p, void *buf, size_t *size
		if read(buf, size) then
			return 0
		end
		return res_codes.SZ_ERROR_INPUT_EOF
	end

	local out_stream = ffi.new('ISeqOutStream[1]')
	out_stream[0].Write = function(p, buf, size)  -- ISeqOutStreamPtr p, const void *buf, size_t size
		return write(buf, size)  -- the number of actually written bytes, (result < size) means error
	end

	local res = c7z.LzmaEnc_Encode(enc_handle, out_stream, in_stream_p, nil, g_alloc_p, g_alloc_p)
	assert(res == res_codes.SZ_OK, res)

	c7z.LzmaEnc_Destroy(enc_handle, g_alloc_p, g_alloc_p)

	return table.concat(out)
end

---@param s string
---@return string
function l7z.uncompress_stream_s(s)
	local src_p = ffi.cast("const unsigned char *", s)
	local src_size = #s

	local dec_handle = ffi.new("CLzmaDec[1]")

	local res = c7z.LzmaDec_Allocate(dec_handle, src_p, LZMA_PROPS_SIZE, g_alloc_p)  -- read pointer to props
	assert(res == res_codes.SZ_OK)

	local data_size = ffi.cast("uint64_t*", src_p + LZMA_PROPS_SIZE)[0]

	src_p = src_p + HEADER_SIZE
	src_size = src_size - HEADER_SIZE

	c7z.LzmaDec_Init(dec_handle)

	local src_pos = 0
	local status = ffi.new("ELzmaStatus[1]")

	local BUF_SIZE = 128
	local out_buf = ffi.new("unsigned char[?]", BUF_SIZE)
	local dst_len = ffi.new("size_t[1]", BUF_SIZE)

	local src_size_p = ffi.new("size_t[1]", src_size)

	local out = {}

	while true do
		local finish_mode = src_pos == src_size and "LZMA_FINISH_END" or "LZMA_FINISH_ANY"
		local res = c7z.LzmaDec_DecodeToBuf(dec_handle, out_buf, dst_len, src_p + src_pos, src_size_p, finish_mode, status)
		assert(res == res_codes.SZ_OK, res)
		table.insert(out, ffi.string(out_buf, dst_len[0]))

		if src_pos == src_size then
			break
		end

		dst_len[0] = BUF_SIZE
		src_pos = src_pos + src_size_p[0]
		src_size_p[0] = src_size - src_pos
		if status[0] == 1 then  -- LZMA_STATUS_FINISHED_WITH_MARK
			break
		end
	end

	c7z.LzmaDec_Free(dec_handle, g_alloc_p)

	return table.concat(out)
end

--------------------------------------------------------------------------------
--- single call functions for pointers
--------------------------------------------------------------------------------

---@param src_p ffi.cdata*
---@param src_size integer
---@param props_data_p ffi.cdata*?
---@return ffi.cdata*
---@return integer
function l7z.encode(src_p, src_size, props_data_p)
	local lzma_dst_size = src_size + bit.rshift(src_size, 3) + 16384

	local dst_p = ffi.new("unsigned char[?]", lzma_dst_size + HEADER_SIZE)
	ffi.cast("uint64_t*", dst_p + LZMA_PROPS_SIZE)[0] = src_size

	local lzma_p = dst_p + HEADER_SIZE
	local lzma_size_p = ffi.new("size_t[1]", lzma_dst_size)

	local props_size_p = ffi.new("size_t[1]", LZMA_PROPS_SIZE)

	local enc_props = get_default_props_p()
	if props_data_p then
		local res = props_decode(enc_props[0], props_data_p, LZMA_PROPS_SIZE)
		assert(res == res_codes.SZ_OK, res)
	end

	local res = c7z.LzmaEncode(lzma_p, lzma_size_p, src_p, src_size, enc_props, dst_p, props_size_p, 0, nil, g_alloc_p, g_alloc_p)
	assert(res == res_codes.SZ_OK, res)

	return dst_p, lzma_size_p[0] + HEADER_SIZE
end

---@param src_p ffi.cdata*
---@param src_size integer
---@return ffi.cdata*
---@return integer
function l7z.decode(src_p, src_size)
	local data_size = ffi.cast("uint64_t*", src_p + LZMA_PROPS_SIZE)[0]

	local dst_p = ffi.new("unsigned char[?]", data_size)
	local dst_size_p = ffi.new("size_t[1]", data_size)

	local lzma_p = src_p + HEADER_SIZE
	local lzma_size_p = ffi.new("size_t[1]", src_size - HEADER_SIZE)

	local status = ffi.new("ELzmaStatus[1]")
	local res = c7z.LzmaDecode(dst_p, dst_size_p, lzma_p, lzma_size_p, src_p, LZMA_PROPS_SIZE, "LZMA_FINISH_ANY", status, g_alloc_p)
	assert(res == res_codes.SZ_OK, res)

	return dst_p, dst_size_p[0]
end

--------------------------------------------------------------------------------
--- single call functions for string
--------------------------------------------------------------------------------

---@param s string
---@param props string?
---@return string
function l7z.encode_s(s, props)
	local props_p  ---@type ffi.cdata*
	if props then
		assert(#props == 5)
		props_p = ffi.cast("const unsigned char *", props)
	end
	local src_p, src_size = ffi.cast("const unsigned char *", s), #s
	return ffi.string(l7z.encode(src_p, src_size, props_p))
end

---@param s string
---@return string
---@return string
function l7z.decode_s(s)
	local src_p, src_size = ffi.cast("const unsigned char *", s), #s
	return ffi.string(l7z.decode(src_p, src_size)), ffi.string(src_p, LZMA_PROPS_SIZE)
end

--------------------------------------------------------------------------------
--- tests
--------------------------------------------------------------------------------

do
	local data = ("test"):rep(100)

	local comp_data_1 = l7z.encode_s(data)
	local comp_data_2 = l7z.compress_stream_s(data)
	assert(#comp_data_1 == #comp_data_2, #comp_data_1 .. " " .. #comp_data_2)
	assert(comp_data_1 == comp_data_2)

	local comp_data = comp_data_2

	local uncomp_data_1 = l7z.decode_s(comp_data)
	local uncomp_data_2 = l7z.uncompress_stream_s(comp_data)
	assert(#uncomp_data_1 == #uncomp_data_2)
	assert(uncomp_data_1 == uncomp_data_2)
	assert(uncomp_data_2 == data)
end

do
	local data = ("test"):rep(100)
	local props = string.char(93, 0, 0, 32, 0)

	local comp_data = l7z.encode_s(data, props)

	local _data, _props = l7z.decode_s(comp_data)
	assert(_data == data)
	assert(_props == props)
end

return l7z
