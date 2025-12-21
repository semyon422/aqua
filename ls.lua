local ls = {}

--[[
	-p  append / indicator to directories
	-A  do not list implied . and ..
	-L  when showing file information for a symbolic
        link, show information for the file the link
        references rather than for the link itself
]]

function ls.iter(path)
	local cmd = "ls -pAL"
	if path and #path > 0 then
		cmd = cmd .. " %q"
	end
	local pipe = assert(io.popen(cmd:format(path)))
	local lines = pipe:lines()
	return function()
		---@type string
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
