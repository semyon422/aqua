local class = require("class")
local digest = require("digest")
local mime = require("mime")
local Observable = require("Observable")
local random = require("web.random")
local HttpServer = require("web.http.Server")
local socket_url = require("socket.url")
local json = require("web.json")

---@alias aqua.openai.SubscriptionAuthStatus
---| "unauthenticated"
---| "logging_in"
---| "authenticated"
---| "error"

---@class aqua.openai.SubscriptionCredentials
---@field access_token string
---@field refresh_token string
---@field expires_at integer
---@field account_id string

---@class aqua.openai.SubscriptionAuthOptions
---@field scheduler web.CosocketScheduler
---@field credentials aqua.openai.SubscriptionCredentials
---@field save_credentials fun()
---@field open_url fun(url: string): boolean
---@field request aqua.openai.RequestFunc
---@field server_factory (fun(handler: fun(req: web.Request, res: web.Response)): web.HttpServer)?
---@field get_time (fun(): integer)?

---@class aqua.openai.SubscriptionAuth
---@operator call: aqua.openai.SubscriptionAuth
---@field request aqua.openai.RequestFunc
---@field credentials aqua.openai.SubscriptionCredentials
---@field save_credentials fun()
---@field open_url fun(url: string): boolean
---@field server_factory fun(handler: fun(req: web.Request, res: web.Response)): web.HttpServer
---@field get_time fun(): integer
---@field observable util.Observable
---@field status aqua.openai.SubscriptionAuthStatus
---@field auth_url string?
---@field error string?
---@field verifier string?
---@field state string?
---@field server web.HttpServer?
local SubscriptionAuth = class()

SubscriptionAuth.client_id = "app_EMoamEEZ73f0CkXaXp7hrann"
SubscriptionAuth.authorize_url = "https://auth.openai.com/oauth/authorize"
SubscriptionAuth.token_url = "https://auth.openai.com/oauth/token"
SubscriptionAuth.redirect_uri = "http://localhost:1455/auth/callback"
SubscriptionAuth.scope = "openid profile email offline_access"
SubscriptionAuth.callback_port = 1455

---@param value string
---@return string
local function base64Url(value)
	return (mime.b64(value):gsub("%s", ""):gsub("+", "-"):gsub("/", "_"):gsub("=+$", ""))
end

---@param value string
---@return string
local function formEscape(value)
	return (socket_url.escape(value):gsub("%%20", "+"))
end

---@param params {[string]: string}
---@return string
local function encodeForm(params)
	local keys = {}
	for key in pairs(params) do table.insert(keys, key) end
	table.sort(keys)
	local output = {}
	for _, key in ipairs(keys) do
		table.insert(output, formEscape(key) .. "=" .. formEscape(params[key]))
	end
	return table.concat(output, "&")
end

---@param value string
---@return string
local function htmlEscape(value)
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

---@param token string
---@return string?
local function getAccountId(token)
	local payload = token:match("^[^.]+%.([^.]+)%.")
	if not payload then return end
	payload = payload:gsub("-", "+"):gsub("_", "/")
	payload = payload .. string.rep("=", (4 - #payload % 4) % 4)
	local decoded = mime.unb64(payload)
	local claims = decoded and json.decode_safe(decoded) or nil
	local auth = type(claims) == "table" and claims["https://api.openai.com/auth"] or nil
	local account_id = type(auth) == "table" and auth.chatgpt_account_id or nil
	if type(account_id) == "string" and account_id ~= "" then return account_id end
end

---@param options aqua.openai.SubscriptionAuthOptions
function SubscriptionAuth:new(options)
	self.request = assert(options.request, "request is required")
	self.credentials = assert(options.credentials, "credentials are required")
	self.save_credentials = assert(options.save_credentials, "save_credentials is required")
	self.open_url = assert(options.open_url, "open_url is required")
	self.server_factory = options.server_factory or function(handler)
		return HttpServer(options.scheduler, handler, {client_timeout = 30})
	end
	self.get_time = options.get_time or os.time
	self.observable = Observable()
	self.status = self:isAuthenticated() and "authenticated" or "unauthenticated"
end

---@return boolean
function SubscriptionAuth:isAuthenticated()
	return self.credentials.access_token ~= "" or self.credentials.refresh_token ~= ""
end

---@param observer function|table
function SubscriptionAuth:onChanged(observer)
	self.observable:add(observer)
end

---@param observer function|table
function SubscriptionAuth:offChanged(observer)
	self.observable:remove(observer)
end

function SubscriptionAuth:emitChanged()
	self.observable:send({type = "ai_auth_changed"})
end

---@param status aqua.openai.SubscriptionAuthStatus
---@param err string?
function SubscriptionAuth:setStatus(status, err)
	self.status = status
	self.error = err
	self:emitChanged()
end

---@return string
function SubscriptionAuth:createAuthorizationUrl()
	self.verifier = base64Url(random.bytes(32))
	self.state = random.hex(32)
	local challenge = base64Url(digest.hash("sha256", self.verifier))
	local query = encodeForm({
		response_type = "code",
		client_id = self.client_id,
		redirect_uri = self.redirect_uri,
		scope = self.scope,
		code_challenge = challenge,
		code_challenge_method = "S256",
		state = self.state,
		id_token_add_organizations = "true",
		codex_cli_simplified_flow = "true",
		originator = "soundsphere",
	})
	return self.authorize_url .. "?" .. query
end

---@param uri string
---@return {[string]: string}
local function parseQuery(uri)
	local query = uri:match("%?(.*)$") or ""
	local params = {}
	for pair in query:gmatch("[^&]+") do
		local key, value = pair:match("^([^=]+)=?(.*)$")
		if key then
			params[socket_url.unescape((key:gsub("%+", " ")))] = socket_url.unescape((value:gsub("%+", " ")))
		end
	end
	return params
end

---@param res web.Response
---@param status integer
---@param title string
---@param message string
local function sendHtml(res, status, title, message)
	local body = ("<!doctype html><meta charset=utf-8><title>%s</title><h1>%s</h1><p>%s</p>")
		:format(htmlEscape(title), htmlEscape(title), htmlEscape(message))
	res.status = status
	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res:set_length(#body)
	res:send(body)
end

---@param params {[string]: string}
---@return table?
---@return string?
function SubscriptionAuth:requestToken(params)
	local res, err = self.request(self.token_url, encodeForm(params), {
		method = "POST",
		headers = {['Content-Type'] = "application/x-www-form-urlencoded"},
	})
	if not res then return nil, err or "token request failed" end
	local decoded, decode_err = json.decode_safe(res.body)
	if res.status < 200 or res.status >= 300 then
		local oauth_error = type(decoded) == "table" and (decoded.error_description or decoded.error) or nil
		return nil, ("OpenAI login returned HTTP %d: %s"):format(res.status, tostring(oauth_error or res.body))
	elseif type(decoded) ~= "table" then
		return nil, "invalid OpenAI token response: " .. tostring(decode_err)
	end
	return decoded
end

---@param tokens table
---@return boolean
---@return string?
function SubscriptionAuth:storeTokens(tokens)
	if type(tokens.access_token) ~= "string" or type(tokens.expires_in) ~= "number" then
		return false, "OpenAI token response is missing access_token or expires_in"
	end
	local refresh_token = tokens.refresh_token or self.credentials.refresh_token
	if type(refresh_token) ~= "string" or refresh_token == "" then
		return false, "OpenAI token response is missing refresh_token"
	end
	local account_id = getAccountId(tokens.access_token)
	if not account_id then return false, "OpenAI access token has no ChatGPT account ID" end
	self.credentials.access_token = tokens.access_token
	self.credentials.refresh_token = refresh_token
	self.credentials.expires_at = self.get_time() + math.floor(tokens.expires_in)
	self.credentials.account_id = account_id
	self.save_credentials()
	self:setStatus("authenticated")
	return true
end

---@param code string
---@return boolean
---@return string?
function SubscriptionAuth:exchangeAuthorizationCode(code)
	local tokens, err = self:requestToken({
		grant_type = "authorization_code",
		client_id = self.client_id,
		code = code,
		code_verifier = assert(self.verifier),
		redirect_uri = self.redirect_uri,
	})
	if not tokens then return false, err end
	return self:storeTokens(tokens)
end

---@return boolean
---@return string?
function SubscriptionAuth:refresh()
	if self.credentials.refresh_token == "" then return false, "OpenAI login is required" end
	local tokens, err = self:requestToken({
		grant_type = "refresh_token",
		refresh_token = self.credentials.refresh_token,
		client_id = self.client_id,
	})
	if not tokens then return false, err end
	return self:storeTokens(tokens)
end

---@return string?
---@return string?
---@return string?
function SubscriptionAuth:getAccess()
	if self.credentials.access_token == "" or self.credentials.expires_at <= self.get_time() + 60 then
		local ok, err = self:refresh()
		if not ok then
			self:setStatus("error", err)
			return nil, nil, err
		end
	end
	return self.credentials.access_token, self.credentials.account_id
end

---@param req web.Request
---@param res web.Response
function SubscriptionAuth:handleCallback(req, res)
	local path = req.uri:match("^[^?]+")
	if req.method ~= "GET" or path ~= "/auth/callback" then
		sendHtml(res, 404, "OpenAI login", "Callback route not found.")
		return
	end
	local params = parseQuery(req.uri)
	if params.state ~= self.state then
		self:setStatus("error", "OpenAI login state mismatch")
		sendHtml(res, 400, "OpenAI login failed", "State mismatch.")
		return
	elseif not params.code or params.code == "" then
		local err = params.error_description or params.error or "Missing authorization code"
		self:setStatus("error", err)
		sendHtml(res, 400, "OpenAI login failed", err)
		return
	end
	local ok, err = self:exchangeAuthorizationCode(params.code)
	if not ok then
		self:setStatus("error", err)
		sendHtml(res, 500, "OpenAI login failed", assert(err))
		return
	end
	sendHtml(res, 200, "OpenAI login complete", "You can close this window and return to the game.")
	self.verifier = nil
	self.state = nil
	if self.server then
		self.server:stop()
		self.server = nil
	end
end

---@return boolean
---@return string?
function SubscriptionAuth:startLogin()
	if self.server then self.server:stop() end
	self.auth_url = self:createAuthorizationUrl()
	self.server = self.server_factory(function(req, res) self:handleCallback(req, res) end)
	local ok, err = self.server:start("127.0.0.1", self.callback_port)
	if not ok then
		self.server = nil
		self:setStatus("error", "failed to start OpenAI login callback: " .. tostring(err))
		return false, self.error
	end
	self:setStatus("logging_in")
	if not self.open_url(self.auth_url) then
		self.server:stop()
		self.server = nil
		self:setStatus("error", "failed to open the OpenAI login URL")
		return false, self.error
	end
	return true
end

function SubscriptionAuth:logout()
	self.credentials.access_token = ""
	self.credentials.refresh_token = ""
	self.credentials.expires_at = 0
	self.credentials.account_id = ""
	self.save_credentials()
	self:setStatus("unauthenticated")
end

function SubscriptionAuth:unload()
	if self.server then
		self.server:stop()
		self.server = nil
	end
end

return SubscriptionAuth
