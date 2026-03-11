local zlib = require("zlib")
local byte = require("byte")
local ffi = require("ffi")

local zip = {}

-- Signatures
local SIG_LFH = 0x04034b50
local SIG_CDFH = 0x02014b50
local SIG_EOCD = 0x06054b50

local METHOD_STORE = 0
local METHOD_DEFLATE = 8

--------------------------------------------------------------------------------
-- Reader
--------------------------------------------------------------------------------

---@class zip.Entry
---@field name string
---@field method integer
---@field compressed_size integer
---@field uncompressed_size integer
---@field crc32 integer
---@field time integer
---@field date integer
---@field offset integer? @ relative offset of local file header (0-based)
---@field data string

---@class zip.Reader
---@field buf byte.Buffer
---@field entries zip.Entry[]
local Reader = {}
Reader.__index = Reader

---@param data string
---@return zip.Reader
function zip.Reader(data)
	local buf = byte.buffer(#data)
	buf:fill(data)
	buf:seek(0)

	local self = setmetatable({
		buf = buf,
		entries = {}
	}, Reader)
	self:parse()

	return self
end

function Reader:parse()
	local buf = self.buf
	local len = tonumber(buf.size)

	-- Find EOCD signature (search backwards from end)
	local eocd_pos = -1
	local min_offset = math.max(0, len - 65535 - 22)
	for i = len - 22, min_offset, -1 do
		buf:seek(i)
		if buf:read("u32") == SIG_EOCD then
			eocd_pos = i
			break
		end
	end

	if eocd_pos == -1 then
		error("ZIP End of Central Directory signature not found")
	end

	buf:seek(eocd_pos + 10)
	local cd_records = buf:read("u16")
	buf:seek(eocd_pos + 16)
	local cd_offset = buf:read("u32")

	buf:seek(cd_offset)
	for i = 1, cd_records do
		if buf:read("u32") ~= SIG_CDFH then
			error("ZIP Central Directory File Header signature mismatch at " .. tonumber(buf.offset) - 4)
		end

		buf:seek(buf.offset + 6) -- skip version made/needed and gp flag
		local method = buf:read("u16")
		local time = buf:read("u16")
		local date = buf:read("u16")
		local crc32 = buf:read("u32")
		local comp_size = buf:read("u32")
		local uncomp_size = buf:read("u32")
		local name_len = buf:read("u16")
		local extra_len = buf:read("u16")
		local comment_len = buf:read("u16")
		buf:seek(buf.offset + 8) -- skip disk start, attrs
		local offset = buf:read("u32")
		local name = buf:string(name_len)
		buf:seek(buf.offset + extra_len + comment_len)

		table.insert(self.entries, {
			name = name,
			method = method,
			time = time,
			date = date,
			crc32 = crc32,
			compressed_size = comp_size,
			uncompressed_size = uncomp_size,
			offset = offset
		})
	end
end

---@param name string
---@return string
function Reader:extract(name)
	---@type zip.Entry?
	local entry
	for _, e in ipairs(self.entries) do
		if e.name == name then
			entry = e
			break
		end
	end

	if not entry then
		error("File not found in zip: " .. name)
	end

	return self:extract_entry(entry)
end

---@param entry zip.Entry
---@return string
function Reader:extract_entry(entry)
	local buf = self.buf
	buf:seek(entry.offset)

	if buf:read("u32") ~= SIG_LFH then
		error("ZIP Local File Header signature mismatch at " .. tonumber(entry.offset))
	end

	buf:seek(buf.offset + 22) -- skip to lengths
	local name_len = buf:read("u16")
	local extra_len = buf:read("u16")
	buf:seek(buf.offset + name_len + extra_len)

	local comp_data = buf:string(entry.compressed_size)

	if entry.method == METHOD_STORE then
		return comp_data
	elseif entry.method == METHOD_DEFLATE then
		if entry.compressed_size == 0 then return "" end
		return zlib.inflate_raw(comp_data, entry.uncompressed_size)
	else
		error("Unsupported compression method: " .. entry.method)
	end
end

function Reader:free()
	self.buf:free()
end

--------------------------------------------------------------------------------
-- Writer
--------------------------------------------------------------------------------

local u = byte.yield_union()

---@class zip.WriterEntry: zip.Entry

---@class zip.Writer
---@field entries zip.WriterEntry[]
local Writer = {}
Writer.__index = Writer

---@return zip.Writer
function zip.Writer()
	local self = setmetatable({
		entries = {},
	}, Writer)
	return self
end

---@param name string
---@param data string
---@param time integer?
---@param date integer?
function Writer:add(name, data, time, date)
	time = time or 0
	date = date or 0

	local crc = zlib.crc32(0, data)
	local uncomp_size = #data

	---@type string?
	local comp_data
	---@type integer?
	local method

	if uncomp_size > 0 then
		local deflated = zlib.deflate_raw(data, 6)
		if #deflated < uncomp_size then
			comp_data = deflated
			method = METHOD_DEFLATE
		else
			comp_data = data
			method = METHOD_STORE
		end
	else
		comp_data = ""
		method = METHOD_STORE
	end

	---@type zip.Entry
	local entry = {
		name = name,
		method = method,
		time = time,
		date = date,
		crc32 = crc,
		compressed_size = #comp_data,
		uncompressed_size = uncomp_size,
		data = comp_data,
	}

	table.insert(self.entries, entry)
end

---@param buf byte.Buffer
function Writer:encode_async(buf)
	local entries = self.entries
	local gp_flag = 0x0800 -- UTF-8

	-- Pass 1: LFH + Data
	for _, e in ipairs(entries) do
		local offset = tonumber(buf.offset)
		---@cast offset -?
		e.offset = offset
		u.u32 = SIG_LFH
		u.u16 = 20
		u.u16 = gp_flag
		u.u16 = e.method
		u.u16 = e.time
		u.u16 = e.date
		u.u32 = e.crc32
		u.u32 = e.compressed_size
		u.u32 = e.uncompressed_size
		u.u16 = #e.name
		u.u16 = 0
		u.char = e.name
		u.char = e.data
	end

	local cd_start = tonumber(buf.offset)
	---@cast cd_start -?

	-- Pass 2: CDFH
	for _, e in ipairs(entries) do
		u.u32 = SIG_CDFH
		u.u16 = 20 -- version made by
		u.u16 = 20 -- version needed
		u.u16 = gp_flag
		u.u16 = e.method
		u.u16 = e.time
		u.u16 = e.date
		u.u32 = e.crc32
		u.u32 = e.compressed_size
		u.u32 = e.uncompressed_size
		u.u16 = #e.name
		u.u16 = 0
		u.u16 = 0
		u.u16 = 0
		u.u16 = 0
		u.u32 = 0
		u.u32 = e.offset
		u.char = e.name
	end

	local cd_end = tonumber(buf.offset)
	local cd_size = cd_end - cd_start

	-- Pass 3: EOCD
	u.u32 = SIG_EOCD
	u.u16 = 0
	u.u16 = 0
	u.u16 = #entries
	u.u16 = #entries
	u.u32 = cd_size
	u.u32 = cd_start
	u.u16 = 0
end

---@param max_size integer?
---@return string
function Writer:finish(max_size)
	local buf = byte.buffer(8192)
	local f = byte.stretchy_seeker(buf, max_size or 1e9)

	local ok, bytes = byte.apply(f, self.encode_async, self, buf)
	if not ok then
		buf:free()
		error("Failed to encode ZIP")
	end

	local s = ffi.string(buf.ptr, bytes)
	buf:free()
	return s
end

return zip
