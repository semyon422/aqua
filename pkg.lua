---@type table?
local pkg = package.loaded.pkg

if pkg then
	return pkg
end

pkg = {}
package.loaded.pkg = pkg

local os_ext = {
	Windows = {"dll"},
	Linux = {"so"},
	OSX = {"dylib", "so"},
}

local exts = os_ext[jit.os]

local function join(a, b)
	if not a then
		return b
	end
	return ("%s/%s"):format(a, b)
end

local lua_paths, c_paths

function pkg.reset()
	lua_paths = {}
	c_paths = {}
end
pkg.reset()

---@param path string
function pkg.add(path)
	table.insert(lua_paths, path)
end

---@param path string
function pkg.addc(path)
	table.insert(c_paths, path)
end

---@return string
function pkg.compile_path()
	local out = {}
	for i = 0, #lua_paths do  -- start with nil path
		local p = lua_paths[i]
		table.insert(out, join(p, "?.lua"))
		table.insert(out, join(p, "?/init.lua"))
	end
	return table.concat(out, ";")
end

---@return string
function pkg.compile_cpath()
	local out = {}
	for i = 0, #c_paths do  -- start with nil path
		local p = c_paths[i]
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

return pkg
