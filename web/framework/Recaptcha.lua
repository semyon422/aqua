local http_util = require("web.http.util")
local json = require("web.json")
local class = require("class")

---@class web.Recaptcha
---@operator call: web.Recaptcha
local Recaptcha = class()

Recaptcha.url = "https://www.google.com/recaptcha/api/siteverify"

---@param secret_key string
---@param site_key string
---@param required_score number
function Recaptcha:new(secret_key, site_key, required_score)
	self.secret_key = secret_key
	self.site_key = site_key
	self.required_score = required_score
end

---@param ip string
---@param params {["g-recaptcha-response"]: string}
---@param action string
---@return true?
---@return string?
function Recaptcha:verify(ip, params, action)
	local res, err = http_util.request(self.url, {
		secret = self.secret_key,
		response = params["g-recaptcha-response"],
		remoteip = ip
	})

	if not res then
		return nil, err
	elseif res.status ~= 200 then
		return nil, "not_ok"
	end

	local captcha, err = json.decode_safe(res.body)
	if not captcha then
		return nil, err
	end

	if not captcha.success or captcha.score < self.required_score or captcha.action ~= action then
		return nil, res.body
	end

	return true
end

return Recaptcha
