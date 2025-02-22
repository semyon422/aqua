local class = require("class")

---@alias aqua.Path.Part { name: string, isDirectory: boolean, isHidden: boolean }

---@class aqua.Path
---@operator call: aqua.Path
---@field parts aqua.Path.Part[]
---@field absolute boolean
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
---@return string?
function Path:getName(without_extension)
	if self:isEmpty() then
		return
	end

	local last = self.parts[#self.parts]

	if last.isDirectory then
		return last.name
	end

	local name = last.name

	if last.isHidden and name:len() > 1 and name ~= ".." then
		name = name:sub(2, #name)
	end

	if not without_extension then
		return name
	end

	local split = last.name:split(".")
	if #split == 1 then
		return name
	end

	table.remove(split, #split)
	return table.concat(split, ".")
end

---@return string?
function Path:getExtension()
	if self:isEmpty() then
		return
	end

	local last = self.parts[#self.parts]
	if last.isDirectory then
		return
	end

	if not last.name then
		return
	end

	local ext = last.name:match("^.+%.(.-)$")
	if ext then
		return ext:lower()
	end
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

---@return aqua.Path
function Path:trimLast()
	local new = self:copy()

	if self:isEmpty() then
		return new
	end

	table.remove(new.parts, #new.parts)
	return new
end

---@return aqua.Path
function Path:normalize()
	local new = self:copy()

	local processed_parts = {}
	for _, part in ipairs(new.parts) do
		local name = part.name
		if name == ".." then
			if #processed_parts > 0 then
				table.remove(processed_parts)
			end
		elseif name ~= "." then
			table.insert(processed_parts, part)
		end
	end

	new.parts = processed_parts
	return new
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
	new.absolute = self.absolute
	new.driveLetter = self.driveLetter

	for _, v in ipairs(self.parts) do
		table.insert(new.parts, v)
	end

	return new
end

---@param part aqua.Path.Part
---@private
function Path:appendPart(part)
	table.insert(self.parts, part)
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
		new:appendPart(v)
	end

	return new
end

---@return string
function Path:__tostring()
	local s = ""

	for _, v in ipairs(self.parts) do
		if v.isDirectory then
			s = ("%s%s/"):format(s, v.name)
		else
			s = s .. v.name
		end
	end

	if self.absolute and self.driveLetter then
		s = ("%s:/%s"):format(self.driveLetter, s)
	elseif self.absolute then
		s = "/" .. s
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
				isDirectory = true,
				isHidden = name:sub(1, 1) == "."
			})
		end
	end

	if not self:isEmpty() then
		local last = self.parts[#self.parts]
		last.isDirectory =
			(path:sub(#path, #path) == "/") or
			(last.name == ".") or
			(last.name == "..")
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
					isDirectory = true,
					isHidden = name:sub(1, 1) == "."
				})
			end
		end
	end

	if not self:isEmpty() then
		local last_str = array[#array]
		local last_part = self.parts[#self.parts]
		last_part.isDirectory =
			(last_str:sub(#last_str, #last_str) == "/") or
			(last_part.name == ".") or
			(last_part.name == "..")

		self:determineKind(self.parts[1].name)
	end
end

---@param str string
function Path:determineKind(str)
	self.absolute = str:sub(1, 1) == "/"
	if self.absolute then
		return
	end

	---@type string[]
	local split = str:split("/")

	if #split == 0 then
		return
	end

	if split[1]:find(":") then
		self.absolute = true
		self.driveLetter = split[1]:sub(1, 1)
		return
	end
end

return Path
