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

return io_util
