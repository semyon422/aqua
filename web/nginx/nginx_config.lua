---@class web.NginxConfig
local config = {
	listen = 8180,
	lua_code_cache = "off",
	client_max_body_size = "10M",
	handler = "sea.app.handler",
	require = {
		"socket",
		"ltn12",
		"mime",
	},
}

return config
