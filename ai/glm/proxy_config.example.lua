return {
	host = "127.0.0.1",
	port = 28082,
	-- GLM Coding Plan OpenAI-compatible endpoint.
	base_url = "https://api.z.ai/api/coding/paas/v4",
	api_key = "replace-with-your-glm-coding-plan-api-key",
	network_path = "userdata/network.lua",
	tls_cafile = "resources/certs/cacert.pem",
	models = {
		"glm-4.7",
		"glm-5-turbo",
		"glm-5.2",
		"glm-5.2-highspeed",
		"glm-5.3",
		"glm-5.3-flash",
		"glm-5.3-highspeed",
	},
	-- Map public model names to different upstream models, for example:
	-- ["glm-5.3-flash"] = "glm-5.3",
	model_redirects = {},
	-- Default thinking mode applied when the request does not set `thinking`.
	thinking = "enabled",
	-- Request incremental tool-call streaming when tools are present.
	tool_stream = true,
	upstream_timeout = 300,
	client_timeout = 300,
	max_body_size = 16 * 1024 * 1024,
	max_clients = 64,
	max_concurrent_requests_per_user = 4,
	max_requests_per_minute = 120,
	users = {
		{name = "local", access_token = "replace-with-a-long-random-token"},
	},
}
