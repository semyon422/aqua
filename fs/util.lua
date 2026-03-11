local LoveFilesystem = require("fs.LoveFilesystem")

local util = {}

---@param src string
---@param dst string
---@param src_fs fs.IFilesystem
---@param dst_fs fs.IFilesystem?
function util.copy(src, dst, src_fs, dst_fs)
	dst_fs = dst_fs or LoveFilesystem()
	local info = src_fs:getInfo(src)
	if not info then
		error("Source not found: " .. src)
	end

	if info.type == "directory" then
		dst_fs:createDirectory(dst)
		local items = src_fs:getDirectoryItems(src)
		for _, item in ipairs(items) do
			local src_item = (src == "" or src == ".") and item or src .. "/" .. item
			local dst_item = (dst == "" or dst == ".") and item or dst .. "/" .. item
			util.copy(src_item, dst_item, src_fs, dst_fs)
		end
	else
		local data, err = src_fs:read(src)
		if not data then
			error("Failed to read " .. src .. ": " .. err)
		end
		local ok, write_err = dst_fs:write(dst, data)
		if not ok then
			error("Failed to write " .. dst .. ": " .. write_err)
		end
	end
end

return util
