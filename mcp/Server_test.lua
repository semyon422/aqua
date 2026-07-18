local coext = require("coext")
local socket = require("socket")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
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
---@param message table
---@param headers {[string]: string}?
---@return web.Response?
---@return string?
---@return string[]
local function request(t, message, headers)
	local scheduler = CosocketScheduler()
	---@type string[]
	local errors = {}
	local server = Server(scheduler, {make_tool()}, {
		port = 0,
		on_error = function(err)
			table.insert(errors, err)
		end,
	})
	t:assert(server:start())
	local _, port = server:getAddress()

	local response
	local request_error
	local request_headers = {
		["Content-Type"] = "application/json",
		Accept = "application/json, text/event-stream",
	}
	for key, value in pairs(headers or {}) do
		request_headers[key] = value
	end
	local request_thread = coext.detach(coroutine.create(function()
		response, request_error = http_util.request(("http://127.0.0.1:%d/mcp"):format(port), json.encode(message), {
			scheduler = scheduler,
			timeout = 1,
			headers = request_headers,
		})
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
function test.non_loopback_listener_requires_token(t)
	local server = Server(CosocketScheduler(), {make_tool()}, {host = "0.0.0.0", port = 0})
	local ok, err = server:start()
	t:eq(ok, nil)
	t:eq(err, "MCP authentication token is required for a non-loopback listener")
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
