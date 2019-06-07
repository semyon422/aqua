local ffi = require('ffi')
local liblove = ffi.load('love')

ffi.cdef [[
int PHYSFS_mount(const char *newDir, const char *mountPoint, int appendToPath);
int PHYSFS_removeFromSearchPath(const char *oldDir);
int PHYSFS_setWriteDir(const char *newDir);
const char *PHYSFS_getLastError(void);
]]

local filesystem = {}

filesystem.setWriteDir = function(path)
	local out = liblove.PHYSFS_setWriteDir(path)
	if out == 0 then
		error(("%s: %s"):format(ffi.string(liblove.PHYSFS_getLastError()), path))
	end
	return out
end

filesystem.mount = function(newDir, mountPoint, appendToPath)
	local out = liblove.PHYSFS_mount(newDir, mountPoint, appendToPath)
	if out == 0 then
		error(("%s: %s"):format(ffi.string(liblove.PHYSFS_getLastError()), newDir))
	end
	return out
end

filesystem.unmount = function(oldDir)
	local out = liblove.PHYSFS_removeFromSearchPath(oldDir)
	if out == 0 then
		error(("%s: %s"):format(ffi.string(liblove.PHYSFS_getLastError()), oldDir))
	end
	return out
end

return filesystem
