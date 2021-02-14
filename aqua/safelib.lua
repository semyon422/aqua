local ffi = require("ffi")
local jit = require("jit")

local win64prefix = "./"

local win64 = {
	bass = "bass.dll",
	bass_fx = "bass_fx.dll",
	libcrypto = "libcrypto-1_1-x64.dll",
	libcurl = "libcurl.dll",
	libssl = "libssl-1_1-x64.dll",
	discordrpc = "discord-rpc.dll",
	avcodec = "avcodec-58.dll",
	avdevice = "avdevice-58.dll",
	avfilter = "avfilter-7.dll",
	avformat = "avformat-58.dll",
	avutil = "avutil-56.dll",
	postproc = "postproc-55.dll",
	swresample = "swresample-3.dll",
	swscale = "swscale-5.dll",
	libcharset = "libcharset-1.dll",
	libiconv = "libiconv-2.dll",
	love = "love.dll",
	sqlite3 = "sqlite3.dll",
	z = "z.dll",
}

local safelib = {}

safelib.root = "./"

safelib.setRoot = function(path)
	safelib.root = path
end

safelib.get = function(name)
	local os = jit.os
	local arch = jit.arch

	if os == "Windows" then
		if arch == "x64" then
			return safelib.root .. win64prefix .. win64[name] or name
		elseif arch == "x86" then
			return safelib.root .. win64prefix .. win64[name] or name
		end
	elseif os == "Linux" then
		return name
	end

	error(os .. " " .. arch .. " is not supported")
end

safelib.load = function(name, global)
	local status, lib = pcall(function() return ffi.load(safelib.get(name), global) end)
	if status and lib then
		return lib
	else
		return false, lib
	end
end

return safelib
