local class = require("class")

---@alias aqua.Path.Component { name: string, isDirectory: boolean }
---
---@class aqua.Path
---@operator call: aqua.Path
---@field components aqua.Path.Component[]
---@field leadingSlash boolean
---@field driveLetter string?
---@field cached string?
local Path = class()

---@param path string | string[] | nil
function Path:new(path)
	if type(path) == "table" then
		self:fromArray(path)
	elseif type(path) == "string" then
		self:fromString(path)
	elseif type(path) == "nil" then
		self.components = {}
		self:determineKind("")
		return
	else
		error(("Expected string or string[] type, got %s"):format(type(path)))
	end

	if self.driveLetter then
		table.remove(self.components, 1)
	end
end

---@param without_extension boolean?
---@return string
function Path:getFileName(without_extension)
	if self:isEmpty() then
		return ""
	end

	local c = self.components[#self.components]

	if c.isDirectory then
		return ""
	end

	if not without_extension then
		return c.name
	end

	local split = c.name:split(".")
	if #split == 1 then
		return c.name
	end

	table.remove(split, #split)
	return table.concat(split, ".")
end

---@return string
function Path:getExtension()
	if self:isEmpty() then
		return ""
	end

	local file_name = self.components[#self.components].name
	if not file_name then
		return ""
	end

	local ext = file_name:match("^.+%.(.-)$")
	if ext then
		return ext:lower()
	end

	return ""
end

---@return boolean
function Path:isDirectory()
	if self:isEmpty() then
		return false
	end
	return self.components[#self.components].isDirectory
end

---@return boolean
function Path:isFile()
	if self:isEmpty() then
		return false
	end
	return not self.components[#self.components].isDirectory
end

---@return boolean
function Path:isEmpty()
	return #self.components == 0
end

function Path:trimLast()
	if self:isEmpty() then
		return
	end
	self.cached = nil
	table.remove(self.components, #self.components)
end

function Path:toDirectory()
	if self:isEmpty() then
		return
	end
	self.cached = nil
	self.components[#self.components].isDirectory = true
end

function Path:toFile()
	if self:isEmpty() then
		return
	end
	self.cached = nil
	self.components[#self.components].isDirectory = false
end

---@return aqua.Path
function Path:copy()
	local new = Path()
	new.leadingSlash = self.leadingSlash
	new.driveLetter = self.driveLetter

	for _, v in ipairs(self.components) do
		table.insert(new.components, v)
	end

	return new
end

---@param component aqua.Path.Component
---@private
function Path:appendComponent(component)
	self.cached = nil
	table.insert(self.components, component)
end

---@param other aqua.Path
function Path:__concat(other)
	local new = self:copy()

	if other:isEmpty() then
		return new
	end

	if not new:isEmpty() then
		new.components[#new.components].isDirectory = true
	end

	for _, v in ipairs(other.components) do
		new:appendComponent(v)
	end

	return new
end

---@return string
function Path:__tostring()
	if self.cached then
		return self.cached
	end

	-- Normalizing here so things like `Path("/home/user/") .. Path("..")` will work
	self:normalize()

	local s = ""

	for _, v in ipairs(self.components) do
		if v.isDirectory then
			s = ("%s%s/"):format(s, v.name)
		else
			s = s .. v.name
		end
	end

	if self.leadingSlash then
		s = "/" .. s
	end

	if self.driveLetter then
		s = ("%s:/%s"):format(self.driveLetter, s)
	end

	self.cached = s
	return s
end

---@param path string
---@private
function Path:fromString(path)
	path = path:gsub("\\", "/")
	self.components = {}

	local split = path:split("/")
	for _, name in ipairs(split) do
		if name ~= "" then
			table.insert(self.components, {
				name = name,
				isDirectory = true
			})
		end
	end

	if not self:isEmpty() then
		self.components[#self.components].isDirectory = path:sub(#path, #path) == "/"
	end

	self:determineKind(path)
end

---@param array string[]
---@private
function Path:fromArray(array)
	self.components = {}

	for _, v in ipairs(array) do
		local path = v:gsub("\\", "/")
		local split = path:split("/")

		for _, name in ipairs(split) do
			if name ~= "" then
				table.insert(self.components, {
					name = name,
					isDirectory = true
				})
			end
		end
	end

	if not self:isEmpty() then
		local last = array[#array]
		self.components[#self.components].isDirectory = last:sub(#last, #last) == "/"
		self:determineKind(self.components[1].name)
	end
end

---@param str string
function Path:determineKind(str)
	self.leadingSlash = str:sub(1, 1) == "/"
	if self.leadingSlash then
		return
	end

	---@type string[]
	local split = str:split("/")

	if #split == 0 then
		return
	end

	if split[1]:find(":") then
		self.driveLetter = split[1]:sub(1, 1)
		return
	end
end

function Path:normalize()
	local processed_components = {}
	for _, component in ipairs(self.components) do
		local name = component.name
		if name == ".." then
			if #processed_components > 0 then
				table.remove(processed_components)
			end
		elseif name ~= "." then
			table.insert(processed_components, component)
		end
	end

	self.components = processed_components
end

return Path
