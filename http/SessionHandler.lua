local class = require("class")
local cookie_util = require("http.cookie_util")
local session_util = require("http.session_util")

---@class http.SessionHandler
---@operator call: http.SessionHandler
local SessionHandler = class()

function SessionHandler:new(session_config)
	self.session_config = session_config
end

function SessionHandler:decode(params, headers)
	params.cookies = cookie_util.decode(headers["Cookie"])
	params.session = session_util.decode(
		params.cookies[self.session_config.name],
		self.session_config.secret
	) or {}
end

function SessionHandler:encode(params, headers)
	params.cookies = {}
	params.cookies[self.session_config.name] = session_util.encode(
		params.session,
		self.session_config.secret
	)
	headers["Set-Cookie"] = cookie_util.encode(params.cookies)
end

return SessionHandler
