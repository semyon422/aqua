local jit = require("jit")

local win64 = {
	bass = "bass.dll",
	bass_fx = "bass_fx.dll",
	libcrypto = "libcrypto-1_1-x64.dll",
	libcurl = "libcurl.dll",
	libssl = "libssl-1_1-x64.dll",
	discordrpc = "discord-rpc.dll",
	avcodec = "avcodec-59.dll",
	avdevice = "avdevice-59.dll",
	avfilter = "avfilter-8.dll",
	avformat = "avformat-59.dll",
	avutil = "avutil-57.dll",
	postproc = "postproc-56.dll",
	swresample = "swresample-4.dll",
	swscale = "swscale-6.dll",
	libcharset = "libcharset-1.dll",
	libiconv = "libiconv-2.dll",
	love = "love.dll",
	sqlite3 = "sqlite3.dll",
	z = "z.dll",
}

local dl = {} -- dynamic linking helper

dl.get = function(name)
	local os = jit.os
	local arch = jit.arch

	if os == "Windows" then
		if arch == "x64" then
			return win64[name] or name
		elseif arch == "x86" then
			return win64[name] or name
		end
	end

	return name
end

return dl
