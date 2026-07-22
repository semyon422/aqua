local class = require("class")
local socket_url = require("socket.url")
local table_util = require("table_util")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local Socks5TcpSocket = require("web.socket.Socks5TcpSocket")

---@class aqua.openai.Socks5Config: web.Socks5ProxyOptions
---@field enabled boolean?
---@field whitelist string[]?
---@field blacklist string[]?

---@class aqua.openai.ProxyNetworkOptions
---@field scheduler web.CosocketScheduler
---@field timeout number
---@field ssl_params web.SslParams
---@field socks5 aqua.openai.Socks5Config?

---@class aqua.openai.ProxyNetwork
---@operator call: aqua.openai.ProxyNetwork
---@field scheduler web.CosocketScheduler
---@field timeout number
---@field ssl_params web.SslParams
---@field socks5 aqua.openai.Socks5Config?
local ProxyNetwork = class()

---@param options aqua.openai.ProxyNetworkOptions
function ProxyNetwork:new(options)
	self.scheduler = assert(options.scheduler, "scheduler is required")
	self.timeout = assert(options.timeout, "timeout is required")
	self.ssl_params = assert(options.ssl_params, "ssl_params are required")
	local socks5 = options.socks5
	if not socks5 or socks5.enabled == false then return end
	assert(type(socks5.host) == "string" and socks5.host ~= "", "SOCKS5 proxy host is required")
	assert(type(socks5.port) == "number" and socks5.port >= 1 and socks5.port <= 65535, "SOCKS5 proxy port is invalid")
	socks5.whitelist = socks5.whitelist or {}
	socks5.blacklist = socks5.blacklist or {}
	for _, domains in ipairs({socks5.whitelist, socks5.blacklist}) do
		for _, domain in ipairs(domains) do
			assert(type(domain) == "string" and domain ~= "", "invalid SOCKS5 proxy domain")
		end
	end
	self.socks5 = socks5
end

---@param host string
---@param domain string
---@return boolean
local function matchesDomain(host, domain)
	host = host:lower():gsub("%.$", "")
	domain = domain:lower():gsub("%.$", "")
	if domain:sub(1, 2) == "*." then
		domain = domain:sub(3)
	elseif domain:sub(1, 1) == "." then
		domain = domain:sub(2)
	end
	return host == domain or host:sub(-#domain - 1) == "." .. domain
end

---@param host string
---@return boolean
function ProxyNetwork:shouldUseSocks5(host)
	local socks5 = self.socks5
	if not socks5 then return false end
	for _, domain in ipairs(socks5.blacklist) do
		if matchesDomain(host, domain) then return false end
	end
	if #socks5.whitelist == 0 then return true end
	for _, domain in ipairs(socks5.whitelist) do
		if matchesDomain(host, domain) then return true end
	end
	return false
end

---@param url string
---@param options web.HttpClientOptions?
---@return web.HttpClientOptions
function ProxyNetwork:getOptions(url, options)
	local client_options = table_util.copy(options)
	client_options.scheduler = self.scheduler
	client_options.ssl_params = self.ssl_params
	client_options.timeout = client_options.timeout or self.timeout
	local parsed_url = assert(socket_url.parse(url))
	local host = assert(parsed_url.host, "HTTP URL has no host")
	local socks5 = self.socks5
	if socks5 and self:shouldUseSocks5(host) then
		local ip_version = socks5.host:find(":", 1, true) and 6 or 4
		local tcp_socket = CosocketTcpSocket(self.scheduler, ip_version)
		client_options.tcp_socket = Socks5TcpSocket(tcp_socket, socks5)
	end
	return client_options
end

return ProxyNetwork
