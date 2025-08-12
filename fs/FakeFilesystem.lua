local IFilesystem = require("fs.IFilesystem")
local table_util = require("table_util")

---@class fs.FakeFilesystemNode
---@field info fs.FileInfo
---@field items {[string]: fs.FakeFilesystemNode}?
---@field content string?

---@class fs.FakeFilesystem: fs.IFilesystem
---@operator call: fs.FakeFilesystem
local FakeFilesystem = IFilesystem + {}

FakeFilesystem.time = 0

function FakeFilesystem:new()
	---@type fs.FakeFilesystemNode
	self.tree = {
		info = {
			type = "directory",
			size = 0,
			modtime = self.time,
		},
		items = {},
	}
end

---@param time integer
function FakeFilesystem:setTime(time)
	self.time = time
end

---@param path string
---@return string[]
local function splitPath(path)
	local parts = {}
	for part in path:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

---@private
---@param path string
---@return fs.FakeFilesystemNode?, fs.FakeFilesystemNode?, string?
function FakeFilesystem:findNode(path)
	if path == "" or path == "/" then
		return self.tree, nil, nil
	end

	local parts = splitPath(path)
	local current = self.tree
	local parent = nil
	local name = nil

	for i, part in ipairs(parts) do
		parent = current
		name = part
		if not parent.items or not parent.items[name] then
			return nil, parent, name
		end
		current = parent.items[name]
	end

	return current, parent, name
end

---@param path string
---@return boolean
function FakeFilesystem:createDirectory(path)
	if path == "" or path == "/" then
		return false
	end

	local parts = splitPath(path)
	local current = self.tree

	for i, part in ipairs(parts) do
		if not current.items[part] then
			current.items[part] = {
				info = {
					type = "directory",
					size = 0,
					modtime = self.time,
				},
				items = {},
			}
		elseif current.items[part].info.type ~= "directory" then
			return false
		end
		current = current.items[part]
	end

	return true
end

---@param path string
---@param info? table
---@return fs.FileInfo?
function FakeFilesystem:getInfo(path, info)
	local node = self:findNode(path)
	if not node then return nil end

	if info then
		return table_util.copy(node.info, info)
	end

	return {
		type = node.info.type,
		size = node.info.size,
		modtime = node.info.modtime,
	}
end

---@param dir string
---@return table
function FakeFilesystem:getDirectoryItems(dir)
	local node = self:findNode(dir)
	if not node or not node.items then
		return {}
	end

	---@type {name: string, is_dir: boolean}[]
	local items = {}
	for name, child in pairs(node.items) do
		table.insert(items, {
			name = name,
			is_dir = child.info.type == "directory",
		})
	end

	table.sort(items, function(a, b)
		if a.is_dir ~= b.is_dir then
			return a.is_dir
		end
		return a.name < b.name
	end)

	local result = {}
	for _, item in ipairs(items) do
		table.insert(result, item.name)
	end

	return result
end

---@param name string
---@param size? number
---@return string?
---@return string?
function FakeFilesystem:read(name, size)
	local node = self:findNode(name)
	if not node or node.items ~= nil then
		return nil, "File not found"
	end

	local content = node.content or ""
	if size then
		return content:sub(1, size)
	end
	return content
end

---@param name string
---@param data string
---@param size? number
---@return boolean
---@return string?
function FakeFilesystem:write(name, data, size)
	local node, parent, node_name = self:findNode(name)

	if not node then
		if not parent or not parent.items then
			return false, "Parent is not a directory"
		end

		---@cast parent -?
		---@cast node_name -?

		parent.items[node_name] = {
			info = {
				type = "file",
				size = 0,
				modtime = self.time,
			},
			content = "",
		}
		node = parent.items[node_name]
	end

	if node.items ~= nil then
		return false, "Is a directory"
	end

	data = size and data:sub(1, size) or data
	node.content = data
	node.info.size = #data
	node.info.modtime = self.time

	return true
end

---@param name string
---@return boolean
function FakeFilesystem:remove(name)
	local node, parent, node_name = self:findNode(name)
	if not node then
		return false
	end

	---@cast parent -?
	---@cast node_name -?

	if node.items and next(node.items) ~= nil then
		return false
	end

	parent.items[node_name] = nil
	return true
end

return FakeFilesystem
