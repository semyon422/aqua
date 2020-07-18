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

local linux64prefix = "./aqua/linux64/"

local linux64 = {
	bass = "libbass.so",
	bass_fx = "libbass_fx.so",
	libcrypto = "libcrypto.so",
	libcurl = "libcurl.so",
	libssl = "libssl.so",
	discordrpc = "libdiscord-rpc.so",
	avcodec = "libavcodec.so",
	avdevice = "libavdevice.so",
	avfilter = "libavfilter.so",
	avformat = "libavformat.so",
	avutil = "libavutil.so",
	postproc = "libpostproc.so",
	swresample = "libswresample.so",
	swscale = "libswscale.so",
	libcharset = "libcharset.so",
	libiconv = "libiconv.so",
	love = "liblove.so",
	sqlite3 = "libsqlite3.so",
	z = "libz.so",
}

local safelib = {}

safelib.get = function(name)
	local os = jit.os
	local arch = jit.arch

	if os == "Windows" then
		if arch == "x64" then
			return win64prefix .. win64[name] or name
		elseif arch == "x86" then
			return win64prefix .. win64[name] or name
		end
	elseif os == "Linux" then
		if arch == "x64" then
			return linux64prefix .. linux64[name] or name
		elseif arch == "x86" then
			return linux64prefix .. linux64[name] or name
		end
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
