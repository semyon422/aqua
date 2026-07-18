local coext = require("coext")
local socket = require("socket")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local Headers = require("web.http.Headers")
local http_util = require("web.http.util")
local json = require("web.json")
local Server = require("mcp.Server")

local test = {}

local function make_tool()
	return {
		name = "lua_eval",
		description = "Evaluate Lua code",
		input_schema = {
			type = "object",
			properties = {code = {type = "string"}},
			required = {"code"},
			additionalProperties = false,
		},
		annotations = {destructiveHint = true},
		execute = function(_, args)
			return json.encode({ok = true, value = args.code})
		end,
	}
end

---@param t testing.T
---@param options mcp.ServerOptions?
---@return mcp.Server
---@return web.CosocketScheduler
---@return integer
---@return string[]
local function start_server(t, options)
	local scheduler = CosocketScheduler()
	---@type string[]
	local errors = {}
	options = options or {}
	options.port = 0
	options.on_error = function(err)
		table.insert(errors, err)
	end
	local server = Server(scheduler, {make_tool()}, options)
	t:assert(server:start())
	local _, port = server:getAddress()
	return server, scheduler, assert(port), errors
end

---@param t testing.T
---@param scheduler web.CosocketScheduler
---@param port integer
---@param body string?
---@param options web.HttpRequestOptions
---@return mcp.HttpResponse?
---@return string?
local function run_request(t, scheduler, port, body, options)
	local response
	local request_error
	options.scheduler = scheduler
	options.timeout = 1
	local request_thread = coext.detach(coroutine.create(function()
		response, request_error = http_util.request(("http://127.0.0.1:%d/mcp"):format(port), body, options)
	end))
	t:assert(coroutine.resume(request_thread))

	local deadline = socket.gettime() + 2
	while coroutine.status(request_thread) ~= "dead" do
		local ok, err = scheduler:update(0.01)
		if not ok and err then
			error(err)
		end
		t:assert(socket.gettime() < deadline)
	end
	return response, request_error
end

---@param t testing.T
---@param message table
---@param headers {[string]: string}?
---@return mcp.HttpResponse?
---@return string?
---@return string[]
local function request(t, message, headers)
	local server, scheduler, port, errors = start_server(t)
	local request_headers = {
		["Content-Type"] = "application/json",
		Accept = "application/json, text/event-stream",
	}
	for key, value in pairs(headers or {}) do
		request_headers[key] = value
	end
	local response, request_error = run_request(t, scheduler, port, json.encode(message), {
		headers = request_headers,
	})
	server:stop()
	return response, request_error, errors
end

---@param t testing.T
function test.initialize_and_list_tools(t)
	local server = Server(CosocketScheduler(), {make_tool()})
	local initialized = server:dispatch({
		jsonrpc = "2.0",
		id = 1,
		method = "initialize",
		params = {
			protocolVersion = "2025-06-18",
			capabilities = {},
			clientInfo = {name = "test", version = "dev"},
		},
	})

	t:eq(initialized.result.protocolVersion, "2025-06-18")
	t:tdeq(initialized.result.capabilities, {tools = {listChanged = false}})

	local listed = server:dispatch({jsonrpc = "2.0", id = 2, method = "tools/list"})
	t:eq(#listed.result.tools, 1)
	t:eq(listed.result.tools[1].name, "lua_eval")
	t:eq(listed.result.tools[1].inputSchema.properties.code.type, "string")
	t:eq(listed.result.tools[1].annotations.destructiveHint, true)
end

---@param t testing.T
function test.validates_request_parameters(t)
	local server = Server(CosocketScheduler(), {make_tool()})
	local initialize = server:dispatch({
		jsonrpc = "2.0",
		id = 1,
		method = "initialize",
		params = {protocolVersion = "2025-11-25"},
	})
	t:eq(initialize.error.code, -32602)

	local list = server:dispatch({
		jsonrpc = "2.0",
		id = 2,
		method = "tools/list",
		params = {cursor = 1},
	})
	t:eq(list.error.code, -32602)

	local invalid_id = server:dispatch({
		jsonrpc = "2.0",
		id = true,
		method = "ping",
	})
	t:eq(invalid_id.error.code, -32600)
	t:eq(invalid_id.id, nil)
end

---@param t testing.T
function test.call_tool(t)
	local server = Server(CosocketScheduler(), {make_tool()})
	local response = server:dispatch({
		jsonrpc = "2.0",
		id = "call-1",
		method = "tools/call",
		params = {name = "lua_eval", arguments = {code = "game.ui"}},
	})

	t:eq(response.id, "call-1")
	t:eq(response.result.isError, false)
	t:tdeq(json.decode(response.result.content[1].text), {ok = true, value = "game.ui"})

	local missing = server:dispatch({
		jsonrpc = "2.0",
		id = 2,
		method = "tools/call",
		params = {name = "missing"},
	})
	t:eq(missing.error.code, -32602)
end

---@param t testing.T
function test.structured_tool_result(t)
	local tool = make_tool()
	tool.output_schema = {
		type = "object",
		properties = {value = {type = "string"}},
		required = {"value"},
		additionalProperties = false,
	}
	tool.execute = function(_, args)
		return {
			content = {
				{type = "text", text = "result: " .. args.code},
				{type = "image", data = "aGVsbG8=", mimeType = "image/png"},
			},
			structured_content = {value = args.code},
		}
	end
	local server = Server(CosocketScheduler(), {tool})
	local listed = server:dispatch({jsonrpc = "2.0", id = 1, method = "tools/list"})
	t:eq(listed.result.tools[1].outputSchema, tool.output_schema)

	local response = server:dispatch({
		jsonrpc = "2.0",
		id = 2,
		method = "tools/call",
		params = {name = "lua_eval", arguments = {code = "game.ui"}},
	})
	t:eq(response.result.content[1].text, "result: game.ui")
	t:eq(response.result.content[2].type, "image")
	t:eq(response.result.content[2].mimeType, "image/png")
	t:tdeq(response.result.structuredContent, {value = "game.ui"})
	t:eq(response.result.isError, false)
end

---@param t testing.T
function test.rejects_invalid_structured_tool_result(t)
	local tool = make_tool()
	tool.output_schema = {
		type = "object",
		properties = {value = {type = "string"}},
		required = {"value"},
	}
	tool.execute = function()
		return "invalid", false, {value = 1}
	end
	local server = Server(CosocketScheduler(), {tool})
	local response = server:dispatch({
		jsonrpc = "2.0",
		id = 1,
		method = "tools/call",
		params = {name = "lua_eval", arguments = {code = "game.ui"}},
	})
	t:eq(response.result.isError, true)
	t:eq(response.result.content[1].text, "invalid structured tool output: $.value must match type string")
end

---@param t testing.T
function test.tool_execution_error(t)
	local tool = make_tool()
	tool.execute = function()
		return "invalid input", true
	end
	local server = Server(CosocketScheduler(), {tool})
	local response = server:dispatch({
		jsonrpc = "2.0",
		id = 1,
		method = "tools/call",
		params = {name = "lua_eval", arguments = {code = "invalid"}},
	})
	t:eq(response.result.isError, true)
	t:eq(response.result.content[1].text, "invalid input")
end

---@param t testing.T
function test.validates_tool_arguments(t)
	local called = false
	local tool = make_tool()
	tool.execute = function()
		called = true
		return "unexpected"
	end
	local server = Server(CosocketScheduler(), {tool})
	local response = server:dispatch({
		jsonrpc = "2.0",
		id = 1,
		method = "tools/call",
		params = {name = "lua_eval", arguments = {unknown = true}},
	})

	t:eq(called, false)
	t:eq(response.error.code, -32602)
	t:eq(response.error.message, "Invalid tool arguments")
	t:eq(response.error.data, "$.code is required")
end

---@param t testing.T
function test.notification_has_no_response(t)
	local server = Server(CosocketScheduler(), {make_tool()})
	local response = server:dispatch({
		jsonrpc = "2.0",
		method = "notifications/initialized",
	})
	t:eq(response, nil)
end

---@param t testing.T
function test.dispatch_batch(t)
	local server = Server(CosocketScheduler(), {make_tool()})
	local responses = server:dispatchBatch({
		{jsonrpc = "2.0", id = 1, method = "ping"},
		{jsonrpc = "2.0", method = "notifications/initialized"},
		{jsonrpc = "2.0", id = 2, method = "tools/list"},
	})
	t:eq(#responses, 2)
	t:eq(responses[1].id, 1)
	t:eq(responses[2].result.tools[1].name, "lua_eval")

	t:eq(server:dispatchBatch({
		{jsonrpc = "2.0", method = "notifications/initialized"},
	}), nil)
	t:eq(server:dispatchBatch({}).error.code, -32600)
	t:eq(server:dispatchBatch({
		{jsonrpc = "2.0", id = 3, method = "initialize", params = {protocolVersion = "2025-11-25"}},
		{jsonrpc = "2.0", id = 4, method = "ping"},
	}).error.code, -32600)
end

---@param t testing.T
function test.bearer_authorization(t)
	local server = Server(CosocketScheduler(), {make_tool()}, {token = "secret"})
	local headers = Headers()
	local req = {headers = headers}
	t:eq(server:isAuthorized(req --[[@as web.Request]]), false)

	headers:set("Authorization", "Bearer wrong")
	t:eq(server:isAuthorized(req --[[@as web.Request]]), false)
	headers:set("Authorization", "Bearer secret")
	t:eq(server:isAuthorized(req --[[@as web.Request]]), true)
	headers:add("Authorization", "Bearer secret")
	t:eq(server:isAuthorized(req --[[@as web.Request]]), false)
end

---@param t testing.T
function test.non_loopback_listener_requires_token(t)
	local server = Server(CosocketScheduler(), {make_tool()}, {host = "0.0.0.0", port = 0})
	local ok, err = server:start()
	t:eq(ok, nil)
	t:eq(err, "MCP authentication token is required for a non-loopback listener")

	server = Server(CosocketScheduler(), {make_tool()}, {host = "0.0.0.0", port = 0, token = "secret"})
	t:assert(server:start())
	t:eq(server.rate_limit, 120)
	server:stop()
end

---@param t testing.T
function test.persists_session_registry_across_restart(t)
	local stored = {old = true}
	local store = {
		load = function()
			local ids = {}
			for id in pairs(stored) do
				table.insert(ids, id)
			end
			return ids
		end,
		add = function(_, id)
			stored[id] = true
			return true
		end,
		remove = function(_, id)
			stored[id] = nil
			return true
		end,
	}
	local server = Server(CosocketScheduler(), {make_tool()}, {
		port = 0,
		session_id_generator = function() return "new" end,
		session_store = store,
	})
	t:assert(server:start())
	t:assert(server.sessions.old)
	local session = assert(server:createSession())
	t:eq(session.id, "new")
	t:eq(stored.new, true)
	server:stop()
	t:eq(stored.old, true)
	t:eq(stored.new, true)

	server = Server(CosocketScheduler(), {make_tool()}, {
		port = 0,
		session_id_generator = function() return "unused" end,
		session_store = store,
	})
	t:assert(server:start())
	t:assert(server.sessions.old)
	t:assert(server.sessions.new)
	t:assert(server:closeSession(server.sessions.old, nil, true))
	t:eq(stored.old, nil)
	server:stop()
end

---@param t testing.T
function test.rate_limits_requests_by_ip(t)
	local now = 10
	local server = Server(CosocketScheduler(), {make_tool()}, {
		port = 0,
		rate_limit = 2,
		rate_limit_window = 5,
		get_time = function() return now end,
	})
	t:assert(server:start())

	t:eq(server:checkRateLimit("127.0.0.1"), true)
	t:eq(server:checkRateLimit("127.0.0.1"), true)
	local allowed, retry_after = server:checkRateLimit("127.0.0.1")
	t:eq(allowed, false)
	t:eq(retry_after, 5)
	t:eq(server:checkRateLimit("127.0.0.2"), true)

	now = 15
	t:eq(server:checkRateLimit("127.0.0.1"), true)
	server:stop()

	server = Server(CosocketScheduler(), {make_tool()}, {port = 0, rate_limit = 0})
	t:assert(server:start())
	t:eq(server:checkRateLimit("127.0.0.1"), true)
	server:stop()
end

---@param t testing.T
function test.streamable_http_round_trip(t)
	local response, request_error, errors = request(t, {
		jsonrpc = "2.0",
		id = 1,
		method = "tools/list",
	}, {['MCP-Protocol-Version'] = "2025-06-18"})

	t:eq(request_error, nil)
	t:eq(#errors, 0)
	t:eq(response.status, 200)
	t:eq(response.headers:get("Content-Type"), "application/json")
	t:eq(response.headers:get("MCP-Protocol-Version"), "2025-06-18")
	local decoded = json.decode(response.body)
	t:eq(decoded.result.tools[1].name, "lua_eval")
end

---@param t testing.T
function test.streamable_http_validation(t)
	local message = {jsonrpc = "2.0", id = 1, method = "tools/list"}
	local function headers()
		return {
			["Content-Type"] = "application/json",
			Accept = "application/json, text/event-stream",
		}
	end

	local server, scheduler, port = start_server(t, {token = "secret"})
	local response = assert(run_request(t, scheduler, port, json.encode(message), {headers = headers()}))
	t:eq(response.status, 401)
	t:eq(response.headers:get("WWW-Authenticate"), "Bearer")
	local request_headers = headers()
	request_headers.Authorization = "Bearer wrong"
	response = assert(run_request(t, scheduler, port, json.encode(message), {headers = request_headers}))
	t:eq(response.status, 401)
	request_headers.Authorization = "Bearer secret"
	response = assert(run_request(t, scheduler, port, json.encode(message), {headers = request_headers}))
	t:eq(response.status, 200)
	server:stop()

	server, scheduler, port = start_server(t)
	request_headers = headers()
	request_headers.Origin = "https://example.com"
	response = assert(run_request(t, scheduler, port, json.encode(message), {headers = request_headers}))
	t:eq(response.status, 403)
	request_headers = headers()
	request_headers.Accept = "application/json"
	response = assert(run_request(t, scheduler, port, json.encode(message), {headers = request_headers}))
	t:eq(response.status, 406)
	request_headers = headers()
	request_headers["Content-Type"] = "text/plain"
	response = assert(run_request(t, scheduler, port, json.encode(message), {headers = request_headers}))
	t:eq(response.status, 415)
	response = assert(run_request(t, scheduler, port, "{", {headers = headers()}))
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, -32700)
	local missing_length_headers = Headers()
	missing_length_headers:set("Content-Type", "application/json")
	missing_length_headers:set("Accept", "application/json, text/event-stream")
	local req = {
		method = "POST",
		uri = "/mcp",
		headers = missing_length_headers,
	}
	local res = {
		headers = Headers(),
		set_length = function(self, length) self.length = length end,
		send = function(self, body) self.body = body return #body end,
	}
	server:handleHttp(req --[[@as web.Request]], res --[[@as web.Response]], "127.0.0.1", 1234)
	t:eq(res.status, 411)
	t:eq(res.body, "Content-Length required")
	server:stop()

	server, scheduler, port = start_server(t, {max_body_size = 4})
	response = assert(run_request(t, scheduler, port, json.encode(message), {headers = headers()}))
	t:eq(response.status, 413)
	server:stop()
end

---@param t testing.T
function test.streamable_http_notifications_batches_and_rate_limit(t)
	local request_headers = {
		["Content-Type"] = "application/json",
		Accept = "application/json, text/event-stream",
	}
	local server, scheduler, port = start_server(t, {rate_limit = 3})
	local response = assert(run_request(t, scheduler, port, json.encode({
		jsonrpc = "2.0",
		method = "notifications/initialized",
	}), {headers = request_headers}))
	t:eq(response.status, 202)
	t:eq(response.body, "")

	response = assert(run_request(t, scheduler, port, json.encode({
		{jsonrpc = "2.0", id = 1, method = "ping"},
		{jsonrpc = "2.0", method = "notifications/initialized"},
		{jsonrpc = "2.0", id = 2, method = "tools/list"},
	}), {headers = request_headers}))
	t:eq(response.status, 200)
	local batch = json.decode(response.body)
	t:eq(#batch, 2)
	t:eq(batch[1].id, 1)
	t:eq(batch[2].id, 2)

	response = assert(run_request(t, scheduler, port, json.encode({jsonrpc = "2.0", id = 3, method = "ping"}), {
		headers = request_headers,
	}))
	t:eq(response.status, 200)
	response = assert(run_request(t, scheduler, port, json.encode({jsonrpc = "2.0", id = 4, method = "ping"}), {
		headers = request_headers,
	}))
	t:eq(response.status, 429)
	t:eq(response.headers:get("Retry-After"), "60")
	t:eq(json.decode(response.body).error.code, -32000)
	server:stop()
end

---@param t testing.T
function test.initialize_negotiates_unknown_protocol_version(t)
	local response, request_error, errors = request(t, {
		jsonrpc = "2.0",
		id = 1,
		method = "initialize",
		params = {
			protocolVersion = "unknown",
			capabilities = {},
			clientInfo = {name = "test", version = "dev"},
		},
	}, {['MCP-Protocol-Version'] = "unknown"})

	t:eq(request_error, nil)
	t:eq(#errors, 0)
	t:eq(response.status, 200)
	t:eq(response.headers:get("MCP-Protocol-Version"), Server.protocol_version)
	t:eq(json.decode(response.body).result.protocolVersion, Server.protocol_version)
end

---@param t testing.T
function test.rejects_unsupported_protocol_version(t)
	local response, request_error, errors = request(t, {
		jsonrpc = "2.0",
		id = 1,
		method = "tools/list",
	}, {['MCP-Protocol-Version'] = "invalid"})

	t:eq(request_error, nil)
	t:eq(#errors, 0)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, -32000)
end

return test
