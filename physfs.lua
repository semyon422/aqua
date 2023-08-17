local ffi = require("ffi")
local C = ffi.os == "Windows" and ffi.load("love") or ffi.C

ffi.cdef([[
int PHYSFS_mount(const char *newDir, const char *mountPoint, int appendToPath);
int PHYSFS_unmount(const char *oldDir);
int PHYSFS_setWriteDir(const char *newDir);
const char *PHYSFS_getLastError(void);
]])

local physfs = {}

function physfs.getLastError()
	local ptr = C.PHYSFS_getLastError()
	if ptr == nil then  -- cdata<const char *>: NULL
		return
	end
	return ffi.string(ptr)
end

---@param res boolean
---@return boolean?
---@return string?
local function protect(res)
	if res then return res end
	return nil, physfs.getLastError()
end

---@param path string
---@return boolean?
---@return string?
function physfs.setWriteDir(path)
	return protect(C.PHYSFS_setWriteDir(path) ~= 0)
end

---@param newDir string
---@param mountPoint string
---@param appendToPath boolean?
---@return boolean?
---@return string?
function physfs.mount(newDir, mountPoint, appendToPath)
	return protect(C.PHYSFS_mount(newDir, mountPoint, appendToPath and 1 or 0) ~= 0)
end

---@param oldDir string
---@return boolean?
---@return string?
function physfs.unmount(oldDir)
	return protect(C.PHYSFS_unmount(oldDir) ~= 0)
end

return physfs
