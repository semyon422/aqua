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

local function protect(res)
	if res then return res end
	return nil, physfs.getLastError()
end

function physfs.setWriteDir(path)
	return protect(C.PHYSFS_setWriteDir(path) ~= 0)
end

function physfs.mount(newDir, mountPoint, appendToPath)
	return protect(C.PHYSFS_mount(newDir, mountPoint, appendToPath) ~= 0)
end

function physfs.unmount(oldDir)
	return protect(C.PHYSFS_unmount(oldDir) ~= 0)
end

return physfs
