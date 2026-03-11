local FakeFilesystem = require("fs.FakeFilesystem")
local zip = require("zip")

---@class fs.ZipFilesystem: fs.FakeFilesystem
---@operator call: fs.ZipFilesystem
local ZipFilesystem = FakeFilesystem + {}

---@param data string?
function ZipFilesystem:new(data)
	FakeFilesystem.new(self)
	if data then
		self:load(data)
	end
end

---@param data string
function ZipFilesystem:load(data)
	local reader = zip.Reader(data)
	for _, entry in ipairs(reader.entries) do
		-- Zip entries can be directories (ending in /) or files
		if entry.name:match("/$") then
			self:createDirectory(entry.name:sub(1, -2))
		else
			-- Ensure parent directories exist
			local dir = entry.name:match("(.+)/[^/]+$")
			if dir then
				self:createDirectory(dir)
			end

			local content = reader:extract_entry(entry)
			local ok, err = self:write(entry.name, content)
			if not ok then
				error(string.format("Failed to write %s to ZipFilesystem: %s", entry.name, err))
			end
		end
	end
	reader:free()
end

---@return string
function ZipFilesystem:save()
	local writer = zip.Writer()

	---@param node fs.FakeFilesystemNode
	---@param path string
	local function traverse(node, path)
		if node.items then
			-- Sort keys for deterministic zip output
			---@type string[]
			local names = {}
			for name in pairs(node.items) do
				table.insert(names, name)
			end
			table.sort(names)

			for _, name in ipairs(names) do
				local child = node.items[name]
				local child_path = path == "" and name or path .. "/" .. name
				if child.info.type == "directory" then
					-- Technically ZIPs don't need directory entries but some tools expect them
					writer:add(child_path .. "/", "")
					traverse(child, child_path)
				else
					writer:add(child_path, child.content or "")
				end
			end
		end
	end

	traverse(self.tree, "")
	return writer:finish()
end

return ZipFilesystem
