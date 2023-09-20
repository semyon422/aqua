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
			local content, err = love.filesystem.read(fileFrom)
			if not content then
				print(err)
			end
			local ok, err = love.filesystem.write(fileTo, content)
			if not ok then
				print(err)
			end
		end
	end
end

return rcopy
