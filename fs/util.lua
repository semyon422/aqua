local LoveFilesystem = require("fs.LoveFilesystem")

local util = {}

---@param src string
---@param dst string
---@param src_fs fs.IFilesystem
---@param dst_fs fs.IFilesystem?
---@param filter? fun(path: string): boolean
function util.copy(src, dst, src_fs, dst_fs, filter)
	dst_fs = dst_fs or LoveFilesystem()
	local info = src_fs:getInfo(src)
	if not info then
		return false, "Source not found: " .. src
	end

	if filter and not filter(src) then return true end

	if info.type == "directory" then
		if dst ~= "" then dst_fs:createDirectory(dst) end
		local items = src_fs:getDirectoryItems(src)
		for _, item in ipairs(items) do
			local src_item = (src == "" or src == ".") and item or src .. "/" .. item
			local dst_item = (dst == "" or dst == ".") and item or dst .. "/" .. item
			local ok, err = util.copy(src_item, dst_item, src_fs, dst_fs, filter)
			if not ok then return false, err end
		end
	else
		local data, err = src_fs:read(src)
		if not data then
			return false, "Failed to read " .. src .. ": " .. tostring(err)
		end
		local ok, write_err = dst_fs:write(dst, data)
		if not ok then
			return false, "Failed to write " .. dst .. ": " .. tostring(write_err)
		end
	end
	return true
end

---@param path string
---@param fs fs.IFilesystem
function util.remove(path, fs)
	local info = fs:getInfo(path)
	if not info then return end

	if info.type == "directory" then
		local items = fs:getDirectoryItems(path)
		for _, item in ipairs(items) do
			util.remove(path .. "/" .. item, fs)
		end
	end
	fs:remove(path)
end

---@param path string
---@param fs fs.IFilesystem
---@param callback fun(file_path: string)
function util.find(path, fs, callback)
	local info = fs:getInfo(path)
	if not info then return end

	if info.type == "directory" then
		local items = fs:getDirectoryItems(path)
		for _, item in ipairs(items) do
			util.find(path .. "/" .. item, fs, callback)
		end
	else
		callback(path)
	end
end

---@param path string
---@param fs fs.IFilesystem
function util.removeEmptyDirs(path, fs)
	local info = fs:getInfo(path)
	if not info or info.type ~= "directory" then return end

	local items = fs:getDirectoryItems(path)
	for _, item in ipairs(items) do
		util.removeEmptyDirs(path .. "/" .. item, fs)
	end

	items = fs:getDirectoryItems(path)
	if #items == 0 then
		fs:remove(path)
	end
end

return util
