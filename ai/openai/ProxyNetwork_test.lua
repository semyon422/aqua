local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local ProxyNetwork = require("ai.openai.ProxyNetwork")

local test = {}

---@param socks5 table?
---@return aqua.openai.ProxyNetwork
local function makeNetwork(socks5)
	return ProxyNetwork({
		scheduler = CosocketScheduler(),
		timeout = 30,
		ssl_params = {mode = "client"},
		socks5 = socks5,
	})
end

---@param t testing.T
function test.routes_with_game_domain_rules(t)
	local network = makeNetwork({
		enabled = true,
		host = "127.0.0.1",
		port = 1080,
		whitelist = {"*.openai.com", "chatgpt.com"},
		blacklist = {"auth.openai.com"},
	})
	t:eq(network:shouldUseSocks5("chatgpt.com"), true)
	t:eq(network:shouldUseSocks5("sub.chatgpt.com"), true)
	t:eq(network:shouldUseSocks5("api.openai.com"), true)
	t:eq(network:shouldUseSocks5("auth.openai.com"), false)
	t:eq(network:shouldUseSocks5("example.com"), false)
end

---@param t testing.T
function test.empty_whitelist_proxies_except_blacklist(t)
	local network = makeNetwork({
		enabled = true,
		host = "127.0.0.1",
		port = 1080,
		blacklist = {"localhost", "127.0.0.1"},
	})
	t:eq(network:shouldUseSocks5("chatgpt.com"), true)
	t:eq(network:shouldUseSocks5("localhost"), false)
	local options = network:getOptions("https://chatgpt.com/backend-api/codex/responses")
	t:assert(options.tcp_socket)
	local tcp_socket = options.tcp_socket --[[@as web.Socks5TcpSocket]]
	t:eq(tcp_socket.proxy.host, "127.0.0.1")
	t:eq(options.timeout, 30)
	t:eq(options.ssl_params.mode, "client")

	options = network:getOptions("http://localhost:28081/v1/models")
	t:eq(options.tcp_socket, nil)
end

---@param t testing.T
function test.disabled_proxy_uses_direct_transport(t)
	local network = makeNetwork({enabled = false})
	local options = network:getOptions("https://chatgpt.com/backend-api/codex/responses")
	t:eq(options.tcp_socket, nil)
end

return test
