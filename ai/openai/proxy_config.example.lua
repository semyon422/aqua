return {
	host = "127.0.0.1",
	port = 28081,
	auth_path = "userdata/ai_auth.lua",
	network_path = "userdata/network.lua",
	models = {
		"gpt-5.6-sol",
		"gpt-5.6-terra",
		"gpt-5.6-luna",
		"gpt-5.5",
		"gpt-5.4",
		"gpt-5.4-mini",
		"gpt-5.3-codex-spark",
	},
	reasoning_effort = "medium",
	upstream_timeout = 300,
	client_timeout = 300,
	max_body_size = 1024 * 1024,
	users = {
		{name = "local", access_token = "replace-with-a-long-random-token"},
	},
}
