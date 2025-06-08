local io_util = {}

---@param path string
---@return string?
---@return string?
function io_util.read_file_safe(path)
	local f, err = io.open(path, "rb")
	if not f then
		return nil, err
	end
	local data = f:read("*a")
	f:close()
	return data
end

---@param path string
---@return string
function io_util.read_file(path)
	return assert(io_util.read_file_safe(path))
end

---@param path string
---@param data string
---@return true?
---@return string?
function io_util.write_file_safe(path, data)
	local f, err = io.open(path, "wb")
	if not f then
		return nil, err
	end
	f:write(data)
	f:close()
	return true
end

---@param path string
---@param data string
---@return true
function io_util.write_file(path, data)
	return assert(io_util.write_file_safe(path, data))
end

return io_util
