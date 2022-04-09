local ffi = require('ffi')
local liblove = ffi.os == 'Windows' and ffi.load('love') or ffi.C

ffi.cdef([[
int PHYSFS_mount(const char *newDir, const char *mountPoint, int appendToPath);
int PHYSFS_unmount(const char *oldDir);
int PHYSFS_setWriteDir(const char *newDir);
const char *PHYSFS_getLastError(void);

typedef unsigned char PHYSFS_uint8;
typedef struct PHYSFS_Version
{
	PHYSFS_uint8 major;
	PHYSFS_uint8 minor;
	PHYSFS_uint8 patch;
} PHYSFS_Version;
void PHYSFS_getLinkedVersion(PHYSFS_Version *ver);
]])

local filesystem = {}

filesystem.version = function()
	local version = ffi.new("PHYSFS_Version[1]")
	liblove.PHYSFS_getLinkedVersion(version)
	return ("%d.%d.%d"):format(version[0].major, version[0].minor, version[0].patch)
end

filesystem.lastError = function(arg)
	return error(("%s: %s"):format(ffi.string(liblove.PHYSFS_getLastError()), arg))
end

filesystem.setWriteDir = function(path)
	local out = liblove.PHYSFS_setWriteDir(path)
	if out == 0 then
		return filesystem.lastError(path)
	end
	return out
end

filesystem.mount = function(newDir, mountPoint, appendToPath)
	local out = liblove.PHYSFS_mount(newDir, mountPoint, appendToPath)
	if out == 0 then
		return filesystem.lastError(newDir)
	end
	return out
end

filesystem.unmount = function(oldDir)
	local out = liblove.PHYSFS_unmount(oldDir)
	if out == 0 then
		return filesystem.lastError(oldDir)
	end
	return out
end

return filesystem
