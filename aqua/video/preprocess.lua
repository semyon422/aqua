local p = io.popen("gcc -E ffmpeg.c")
local out = io.open("headers.lua", "w")

out:write("return [[\n")
for line in p:lines() do
	line = line:match("^%s*(.-)%s*$")
	if line ~= "" and not line:find("^#") then
		out:write(line)
		out:write("\n")
	end
end
out:write("]]\n")

p:close()
out:close()
