local test = {}

---@param t testing.T
function test.clients_and_proxies_require_injected_clocks(t)
	for _, name in ipairs({
		"ai.openai.ChatCompletionsClient", "ai.openai.Client", "ai.zai.Client",
		"ai.openai.BaseResponsesClient", "ai.openai.ResponsesClient", "ai.openai.SubscriptionClient",
		"ai.openai.ProxyServer", "ai.zai.ProxyServer",
	}) do
		local Constructor = require(name)
		local options = {
			base_url = "http://localhost/v1", api_key = "key", model = "model",
			request = function() error("not used") end,
			open_stream = function() error("not used") end,
			auth = {}, scheduler = {},
			users = {{name = "test", access_token = "token"}}, models = {"model"},
			create_client = function() error("not used") end,
		}
		for _, clock_options in ipairs({{}, {get_time = false}, {get_time = 123}, {get_time = "clock"}}) do
			options.get_time = clock_options.get_time
			local ok, err = pcall(Constructor, options)
			t:eq(ok, false)
			t:assert(tostring(err):find("get_time is required", 1, true), name .. ": " .. tostring(err))
		end
		local clock = function() return 42.125 end
		options.get_time = clock
		local instance = Constructor(options)
		t:eq(instance.get_time, clock)
		t:eq(instance.get_time(), 42.125)
	end
end

return test
