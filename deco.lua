local class = require("class")

local deco = {}

---@class deco.Decorator
---@operator call: deco.Decorator
local Decorator = class()
deco.Decorator = Decorator

function Decorator:next(line) end

---@class deco.FunctionDecorator: deco.Decorator
---@operator call: deco.FunctionDecorator
---@field func_name string?
local FunctionDecorator = class(Decorator)
deco.FunctionDecorator = FunctionDecorator

function FunctionDecorator:next(line)
	local matched =
		line:match("^function ([%w%.:_]+)%(") or
		line:match("^local function ([%w_]+)%(") or
		line:match("^([%w%._]+) = function%(") or
		line:match("^local ([%w_]+) = function%(")

	if matched then
		self:func_begin(matched)
	end

	self.func_name = self.func_name or matched
	if self.func_name and line:match("^end") or matched and line:match("end$") then
		local _line = self:func_end(self.func_name)
		self.func_name = nil
		return _line
	end
end

function FunctionDecorator:func_begin(func_name) end
function FunctionDecorator:func_end(func_name) end

---@param path string
---@return string?
function deco.read_file(path)
	error("not implemented")
end

deco.blacklist = {}

deco.decorators = {}

function deco.add(f)
	table.insert(deco.decorators, f)
end

local function split(s, p)
	if not p then
		return
	end
	local a, b = s:find("\n", p, true)
	if not a then
		return false, s:sub(p)
	end
	return b + 1, s:sub(p, a - 1)
end

function deco.process(s)
	if #deco.decorators == 0 then
		return s
	end

	local lines = {}
	for _, line in split, s, 1 do
		local base_line = line
		for _, d in ipairs(deco.decorators) do
			local _line = d:next(base_line)
			if _line then
				line = line .. " " .. _line
			end
		end
		table.insert(lines, line)
	end

	s = table.concat(lines, "\n")
	return s
end

local function lua_loader(name)
	name = name:gsub("%.", "/")

	local errors = {}

	for path in package.path:gsub("%?", name):gmatch("[^;]+") do
		local blacklisted = false
		for _, item in ipairs(deco.blacklist) do
			if path:find(item, 1, true) then
				blacklisted = true
			end
		end
		local content = deco.read_file(path)
		if content then
			if not blacklisted then
				content = deco.process(content, name:match("([^/]+)$"))
			end
			local loader, err = loadstring(content, "@" .. path) -- [string "mod.lua"] -> mod.lua
			if loader then
				return loader
			end
			error(err .. "\n" .. content)
		else
			table.insert(errors, ("no file '%s'"):format(path))
		end
	end

	return "\n\t" .. table.concat(errors, "\n\t")
end

function deco.replace_loader()
	package.loaders[2] = lua_loader
end

return deco
