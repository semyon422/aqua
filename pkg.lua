---@type table?
local pkg = package.loaded.pkg

if type(pkg) == "table" then
	return pkg
end

pkg = {}
package.loaded.pkg = pkg

---@alias pkg.Path string|table

local CWD = {}  -- current working directory

local os_ext = {
	Windows = {"dll"},
	Linux = {"so"},
	OSX = {"dylib", "so"},
}

local exts = os_ext[jit.os]

---@param a pkg.Path
---@param b string
---@return string
local function join(a, b)
	if a == CWD then
		return b
	end
	return ("%s/%s"):format(a, b)
end

function pkg.reset()
	---@type pkg.Path[]
	pkg.lua_paths = {}
	---@type pkg.Path[]
	pkg.c_paths = {}
end
pkg.reset()

---@param t pkg.Path[]
---@param v pkg.Path
---@return number?
local function indexof(t, v)
	for i, _v in ipairs(t) do
		if _v == v then
			return i
		end
	end
end

---@param path string?
function pkg.add(path)
	path = path or CWD
	if not indexof(pkg.lua_paths, path) then
		table.insert(pkg.lua_paths, path)
	end
end

---@param path string?
function pkg.addc(path)
	path = path or CWD
	if not indexof(pkg.c_paths, path) then
		table.insert(pkg.c_paths, path)
	end
end

---@param path string?
function pkg.remove(path)
	local index = indexof(pkg.lua_paths, path or CWD)
	if index then
		table.remove(pkg.lua_paths, index)
	end
end

---@param path string?
function pkg.removec(path)
	local index = indexof(pkg.c_paths, path or CWD)
	if index then
		table.remove(pkg.c_paths, index)
	end
end

---@return string
function pkg.compile_path()
	local out = {}
	for i = 1, #pkg.lua_paths do
		local p = pkg.lua_paths[i]
		table.insert(out, join(p, "?.lua"))
		table.insert(out, join(p, "?/init.lua"))
	end
	return table.concat(out, ";")
end

---@return string
function pkg.compile_cpath()
	local out = {}
	for i = 1, #pkg.c_paths do
		local p = pkg.c_paths[i]
		for _, ext in ipairs(exts) do
			table.insert(out, join(p, ("?.%s"):format(ext)))
		end
	end
	return table.concat(out, ";")
end

function pkg.export_lua()
	package.path = pkg.compile_path()
	package.cpath = pkg.compile_cpath()
end

function pkg.export_love()
	love.filesystem.setRequirePath(pkg.compile_path())
	love.filesystem.setCRequirePath(pkg.compile_cpath())
end

---@param package_path string
---@param package_cpath string
function pkg.import(package_path, package_cpath)
	for path in package_path:gmatch("([^;]*)?") do
		if path == "" then
			pkg.add()
		else
			pkg.add(path:match("^(.-)/?$"))
		end
	end

	for path in package_cpath:gmatch("([^;]*)?") do
		if path == "" then
			pkg.addc()
		else
			pkg.addc(path:match("^(.-)/?$"))
		end
	end
end

function pkg.import_lua()
	pkg.import(package.path, package.cpath)
end

function pkg.import_love()
	pkg.import(love.filesystem.getRequirePath(), love.filesystem.getCRequirePath())
end

return pkg
