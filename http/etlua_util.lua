local etlua = require("etlua")

local html_escape_entities = {
	['&'] = '&amp;',
	['<'] = '&lt;',
	['>'] = '&gt;',
	['"'] = '&quot;',
	["'"] = '&#039;',
}
local function html_escape(str)
	return (str:gsub([=[["><'&]]=], html_escape_entities))
end

local etlua_util = {}

function etlua_util.compile(template, chunkname)
	local parser = etlua.Parser()
	local chunk = assert(parser:compile_to_lua(template))
	local fn = assert(parser:load(chunk, chunkname))

	return function(env)
		if not env then
			env = {}
		end
		local _env = setmetatable({}, {__index = function(self, name)
			local val = env[name]
			if val == nil then
				return _G[name]
			end
			return val
		end})

		setfenv(fn, _env)
		local ok, err = pcall(fn, tostring, html_escape, {}, 0)
		if ok then
			return table.concat(err)
		end

		local err_msg = parser:parse_error(err, chunk)
		if err_msg then
			error(err_msg)
		end

		error(err)
	end
end

local function read_file(path)
	local f = io.open(path, "rb")
	if not f then
		return
	end
	local c = f:read("*a")
	f:close()
	return c
end

etlua_util.path = "?.etlua;templates/?.etlua"

function etlua_util.loader(name)
	name = name:gsub("%.", "/")

	local errors = {}

	for path in etlua_util.path:gsub("%?", name):gmatch("[^;]+") do
		local content = read_file(path)
		if content then
			return function()
				return etlua_util.compile(content, "@" .. path)
			end
		else
			table.insert(errors, ("no file '%s'"):format(path))
		end
	end

	return "\n\t" .. table.concat(errors, "\n\t")
end

return etlua_util
