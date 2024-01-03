local ls = {}

function ls.iter(path)
	local cmd = "ls -pA"
	if path and #path > 0 then
		cmd = cmd .. " %q"
	end
	local pipe = assert(io.popen(cmd:format(path)))
	local lines = pipe:lines()
	return function()
		local line = lines()
		if not line then
			return
		end
		local dir = line:match("^(.+)/$")
		if dir then
			return dir, "directory"
		end
		return line, "file"
	end
end

return ls
