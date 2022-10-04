local function rcopy(from, to)
	if to ~= "" and not love.filesystem.getInfo(to, "directory") then
		love.filesystem.createDirectory(to)
	end

	for _, name in ipairs(love.filesystem.getDirectoryItems(from)) do
		local fileFrom = from .. "/" .. name
		local fileTo = to ~= "" and to .. "/" .. name or name

		if love.filesystem.getInfo(fileFrom, "directory") then
			rcopy(fileFrom, fileTo)
		else
			love.filesystem.write(fileTo, (love.filesystem.read(fileFrom)))
		end
	end
end

return rcopy
