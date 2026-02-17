local class = require("class")
local NginxSharedDict = require("web.nginx.NginxSharedDict")
local FakeSharedDict = require("web.nginx.FakeSharedDict")

---@class web.SharedMemory
---@operator call: web.SharedMemory
local SharedMemory = class()

function SharedMemory:new()
	self.dicts = {}
end

---@param name string
---@return web.ISharedDict
function SharedMemory:get(name)
	if self.dicts[name] then
		return self.dicts[name]
	end

	local dict
	if ngx and ngx.shared then
		local ngx_dict = ngx.shared[name]
		if not ngx_dict then
			error("ngx.shared dict not found: " .. tostring(name))
		end
		dict = NginxSharedDict(ngx_dict)
	else
		dict = FakeSharedDict()
	end

	self.dicts[name] = dict
	return dict
end

return SharedMemory
