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
function test.initialize_and_list_tools(t)
	local server = Server(CosocketScheduler(), {make_tool()})
	local initialized = server:dispatch({
		jsonrpc = "2.0",
		id = 1,
		method = "initialize",
		params = {protocolVersion = "2025-06-18"},
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
		params = {name = "lua_eval", arguments = {}},
	})
	t:eq(response.result.isError, true)
	t:eq(response.result.content[1].text, "invalid input")
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
function test.streamable_http_round_trip(t)
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
	local body = json.encode({jsonrpc = "2.0", id = 1, method = "tools/list"})
	local request_thread = coext.detach(coroutine.create(function()
		response, request_error = http_util.request(("http://127.0.0.1:%d/mcp"):format(port), body, {
			scheduler = scheduler,
			timeout = 1,
			headers = {
				["Content-Type"] = "application/json",
				Accept = "application/json, text/event-stream",
			},
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

	t:eq(request_error, nil)
	t:eq(#errors, 0)
	t:eq(response.status, 200)
	t:eq(response.headers:get("Content-Type"), "application/json")
	local decoded = json.decode(response.body)
	t:eq(decoded.result.tools[1].name, "lua_eval")
end

return test
