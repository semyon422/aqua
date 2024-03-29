---@param from string
---@param to string
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
			local content = assert(love.filesystem.read(fileFrom))
			assert(love.filesystem.write(fileTo, content))
		end
	end
end

return rcopy
