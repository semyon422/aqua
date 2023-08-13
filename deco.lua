local class = require("class_new2")

local deco = {}

deco.package_path = package.path

---@param path string
---@return string?
function deco.read_file(path)
	error("not implemented")
end

---@class deco.Decorator
---@operator call: deco.Decorator
local Decorator = class()
deco.Decorator = Decorator

function Decorator:next(line) end
function Decorator:func_begin(func_name) end
function Decorator:func_end(func_name) end

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
	local func_name
	for _, line in split, s, 1 do
		for _, d in ipairs(deco.decorators) do
			d:next(line)
		end

		local matched =
			line:match("^function ([%w%.:_]+)%(") or
			line:match("^local function ([%w_]+)%(") or
			line:match("^([%w%._]+) = function%(") or
			line:match("^local ([%w_]+) = function%(")

		if matched then
			for _, d in ipairs(deco.decorators) do
				d:func_begin(matched)
			end
		end

		func_name = func_name or matched
		if func_name and line:match("^end") or matched and line:match("end$") then
			for _, d in ipairs(deco.decorators) do
				local _line = d:func_end(func_name)
				if _line then
					line = line .. " " .. _line
				end
			end
			func_name = nil
		end

		table.insert(lines, line)
	end
	s = table.concat(lines, "\n")
	assert(not func_name, s)
	return s
end

local _lua_loader = package.loaders[2]
local function lua_loader(name)
	name = name:gsub("%.", "/")

	local errors = {}

	for path in deco.package_path:gsub("%?", name):gmatch("[^;]+") do
		for _, item in ipairs(deco.blacklist) do
			if path:find(item, 1, true) then
				return _lua_loader(name)
			end
		end
		local content = deco.read_file(path)
		if content then
			content = deco.process(content, name:match("([^/]+)$"))
			local loader, err = loadstring(content, path)
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
