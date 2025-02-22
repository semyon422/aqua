local class = require("class")

---@alias aqua.Path.Part { name: string, isDirectory: boolean }

---@class aqua.Path
---@operator call: aqua.Path
---@field parts aqua.Path.Part[]
---@field leadingSlash boolean
---@field driveLetter string?
local Path = class()

---@param path string | string[] | nil
function Path:new(path)
	if type(path) == "table" then
		self:fromArray(path)
	elseif type(path) == "string" then
		self:fromString(path)
	elseif type(path) == "nil" then
		self.parts = {}
		self:determineKind("")
		return
	else
		error(("Expected string or string[] type, got %s"):format(type(path)))
	end

	if self.driveLetter then
		table.remove(self.parts, 1)
	end
end

---@param without_extension boolean?
---@return string
function Path:getFileName(without_extension)
	if self:isEmpty() then
		return ""
	end

	local c = self.parts[#self.parts]

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

	local file_name = self.parts[#self.parts].name
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
	return self.parts[#self.parts].isDirectory
end

---@return boolean
function Path:isFile()
	if self:isEmpty() then
		return false
	end
	return not self.parts[#self.parts].isDirectory
end

---@return boolean
function Path:isEmpty()
	return #self.parts == 0
end

function Path:trimLast()
	if self:isEmpty() then
		return
	end
	table.remove(self.parts, #self.parts)
end

function Path:toDirectory()
	if self:isEmpty() then
		return
	end
	self.parts[#self.parts].isDirectory = true
end

function Path:toFile()
	if self:isEmpty() then
		return
	end
	self.parts[#self.parts].isDirectory = false
end

---@return aqua.Path
function Path:copy()
	local new = Path()
	new.leadingSlash = self.leadingSlash
	new.driveLetter = self.driveLetter

	for _, v in ipairs(self.parts) do
		table.insert(new.parts, v)
	end

	return new
end

---@param component aqua.Path.Part
---@private
function Path:appendComponent(component)
	table.insert(self.parts, component)
end

---@param other aqua.Path
---@return aqua.Path
function Path:__concat(other)
	local new = self:copy()

	if other:isEmpty() then
		return new
	end

	if not new:isEmpty() then
		new.parts[#new.parts].isDirectory = true
	end

	for _, v in ipairs(other.parts) do
		new:appendComponent(v)
	end

	return new
end

---@return string
function Path:__tostring()
	-- Normalizing here so things like `Path("/home/user/") .. Path("..")` will work
	self:normalize()

	local s = ""

	for _, v in ipairs(self.parts) do
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

	return s
end

---@param path string
---@private
function Path:fromString(path)
	path = path:gsub("\\", "/")
	self.parts = {}

	local split = path:split("/")
	for _, name in ipairs(split) do
		if name ~= "" then
			table.insert(self.parts, {
				name = name,
				isDirectory = true
			})
		end
	end

	if not self:isEmpty() then
		self.parts[#self.parts].isDirectory = path:sub(#path, #path) == "/"
	end

	self:determineKind(path)
end

---@param array string[]
---@private
function Path:fromArray(array)
	self.parts = {}

	for _, v in ipairs(array) do
		local path = v:gsub("\\", "/")
		local split = path:split("/")

		for _, name in ipairs(split) do
			if name ~= "" then
				table.insert(self.parts, {
					name = name,
					isDirectory = true
				})
			end
		end
	end

	if not self:isEmpty() then
		local last = array[#array]
		self.parts[#self.parts].isDirectory = last:sub(#last, #last) == "/"
		self:determineKind(self.parts[1].name)
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
	local processed_parts = {}
	for _, part in ipairs(self.parts) do
		local name = part.name
		if name == ".." then
			if #processed_parts > 0 then
				table.remove(processed_parts)
			end
		elseif name ~= "." then
			table.insert(processed_parts, part)
		end
	end

	self.parts = processed_parts
end

return Path
