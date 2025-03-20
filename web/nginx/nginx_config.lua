---@class web.NginxConfig
local config = {
	listen = 8080,
	lua_code_cache = "off",
	client_max_body_size = "10M",
	handler = "sea.app.handler",
	proxied = false,
	require = {
		"socket",
		"ltn12",
		"mime",
	},
}

return config
