local openssl_hmac = require("openssl.hmac")
local json = require("json")
local mime = require("mime")

local function hmac_sha256(secret, str)
	local hmac = openssl_hmac.new(secret, "sha256")
	return hmac:final(str)
end

local session_util = {}

function session_util.decode(s, secret)
	if not s then
		return
	end
	local msg, sig = s:match("^(.*)%.(.*)$")
	if not msg then
		return nil, "invalid format"
	end
	sig = mime.unb64(sig)
	if sig ~= hmac_sha256(secret, msg) then
		return nil, "invalid signature"
	end
	msg = mime.unb64(msg)
	return json.decode(msg)
end

function session_util.encode(session, secret)
	local msg = mime.b64(json.encode(session))
	local signature = mime.b64(hmac_sha256(secret, msg))
	return msg .. "." .. signature
end

return session_util
