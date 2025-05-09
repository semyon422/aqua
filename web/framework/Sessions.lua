local class = require("class")
local json = require("web.json")
local mime = require("mime")
local RequestCookie = require("web.http.RequestCookie")
local SetCookieString = require("web.http.SetCookieString")

---@type {new: fun(_: string?, _: string?): {final: fun(_: any, s: string): string}}
local openssl_hmac = require("openssl.hmac")

---@class web.Sessions
---@operator call: web.Sessions
local Sessions = class()

---@param cookie_name string
---@param secret string
---@param secure boolean?
function Sessions:new(cookie_name, secret, secure)
	self.cookie_name = cookie_name
	self.secret = secret
	self.secure = secure
end

---@param s string
---@return string
function Sessions:hmac(s)
	local hmac = openssl_hmac.new(self.secret, "sha256")
	return hmac:final(s)
end

---@param session table
---@return string
function Sessions:encode(session)
	local message = mime.b64(json.encode(session))
	local signature = mime.b64(self:hmac(message))
	return message .. "." .. signature
end

---@param session_string string
---@return table?
---@return string?
function Sessions:decode(session_string)
	local message_b64, signature = session_string:match("^(.*)%.(.*)$")
	if not message_b64 then
		return nil, "invalid format"
	end

	if mime.unb64(signature) ~= self:hmac(message_b64) then
		return nil, "invalid signature"
	end

	local message = mime.unb64(message_b64)
	if not message then
		return nil, "invalid message"
	end

	local ok, session = pcall(json.decode, message)
	if not ok then
		return nil, "invalid json"
	end

	return session
end

---@param headers web.Headers
---@return table?
---@return string?
function Sessions:get(headers)
	local cookie_string = headers:get("Cookie")
	if not cookie_string then
		return nil, "missing cookie"
	end

	local cookie = RequestCookie(cookie_string)

	local session_string = cookie:get(self.cookie_name)
	if not session_string then
		return nil, "missing value"
	end

	return self:decode(session_string)
end

---@param headers web.Headers
---@param session table
function Sessions:set(headers, session)
	local set_cookie = SetCookieString()

	set_cookie.name = self.cookie_name
	set_cookie.value = self:encode(session)
	set_cookie:add("Path", "/")
	set_cookie:add("SameSite", "Lax")
	set_cookie:add("HttpOnly")
	if self.secure then
		set_cookie:add("Secure")
	end

	headers:add("Set-Cookie", tostring(set_cookie))
end

return Sessions
