local class = require("class")

---@class web.HttpChunked
---@operator call: web.HttpChunked
local HttpChunked = class()

---@param read_line fun(): string?, string?
---@param read_chunk fun(size: integer): string?, string?
---@param headers web.Headers
---@return string?
---@return string?
function HttpChunked:decode(read_line, read_chunk, headers)
	local line, err = read_line()
	if not line then
		return nil, err
	end

	local size = tonumber(line:gsub(";.*", ""), 16)
	if not size then
		return nil, "invalid chunk size"
	end

	if size > 0 then
		local chunk, err = read_chunk(size)
		if chunk then
			read_line()
		end
		return chunk, err
	end

	local ok, err = headers:decode(read_line)
	if not ok then
		return nil, err
	end
end

---@param write_chunk fun(chunk: string): string?, string?
---@param chunk string
function HttpChunked:encode(write_chunk, chunk)
	if not chunk then
		return write_chunk("0\r\n\r\n")
	end
	return write_chunk(("%X\r\n%s\r\n"):format(#chunk, chunk))
end

return HttpChunked
