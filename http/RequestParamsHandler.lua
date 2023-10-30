local class = require("class")
local cookie_util = require("http.cookie_util")
local session_util = require("http.session_util")

local http_util = require("http_util")
local table_util = require("table_util")
local json = require("cjson")

local RequestParamsHandler = class()

local function parse_body(content, content_type)
	if content_type == "application/json" then
		local ok, err = pcall(json.decode, content)
		if ok then
			return err
		end
	elseif content_type == "application/x-www-form-urlencoded" then
		return http_util.decode_query_string(content)
	elseif content_type:find("^multipart/form-data") then
		local boundary = content_type:match("boundary=(.+)$")
	end
end

local function handle_headers_in(params, headers, session_config)
	params.cookies = cookie_util.decode(headers["Cookie"])
	params.session = session_util.decode(
		params.cookies[session_config.name],
		session_config.secret
	) or {}
end

local function handle_headers_out(params, headers, session_config)
	params.cookies[session_config.name] = session_util.encode(
		params.session,
		session_config.secret
	)
	headers["Set-Cookie"] = cookie_util.encode(params.cookies)
end

function RequestParamsHandler:new(session_config, params_handler)
	self.session_config = session_config
	self.params_handler = params_handler
end

function RequestParamsHandler:handle_route(req, path_params, ...)
	local body_params = parse_body(req:receive(), req.headers["Content-Type"])
	local query_params = http_util.decode_query_string(req.parsed_url.query)

	local params = {}
	table_util.copy(query_params, params)
	table_util.copy(body_params, params)
	table_util.copy(path_params, params)

	handle_headers_in(params, req.headers, self.session_config)
	local code, headers, res_body = self.params_handler:handle_params(params, ...)
	handle_headers_out(params, headers, self.session_config)

	return code, headers, res_body
end

return RequestParamsHandler
