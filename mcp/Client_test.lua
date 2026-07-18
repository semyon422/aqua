local coext = require("coext")
local socket = require("socket")

local Client = require("mcp.Client")
local Server = require("mcp.Server")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local json = require("web.json")

local test = {}

---@param handler fun(message: table, options: web.HttpRequestOptions): mcp.HttpResponse
---@return fun(url: string, body: string, options: web.HttpRequestOptions): mcp.HttpResponse
---@return table[]
local function fake_request(handler)
	---@type table[]
	local calls = {}
	return function(url, body, options)
		local message = json.decode(body)
		table.insert(calls, {url = url, message = message, options = options})
		return handler(message, options)
	end, calls
end

---@param body table?
---@param status integer?
---@return mcp.HttpResponse
local function response(body, status)
	return {
		status = status or 200,
		headers = {},
		body = body and json.encode(body) or "",
	}
end

---@param t testing.T
---@param scheduler web.CosocketScheduler
---@param thread thread
local function pump(t, scheduler, thread)
	local deadline = socket.gettime() + 2
	while coroutine.status(thread) ~= "dead" do
		local ok, err = scheduler:update(0.01)
		if not ok and err then
			error(err)
		end
		t:assert(socket.gettime() < deadline)
	end
end

---@param t testing.T
function test.initializes_and_sends_protocol_headers(t)
	local request, calls = fake_request(function(message)
		if message.method == "initialize" then
			return response({
				jsonrpc = "2.0",
				id = message.id,
				result = {
					protocolVersion = "2025-06-18",
					capabilities = {tools = {}},
					serverInfo = {name = "test", version = "dev"},
				},
			})
		elseif message.method == "notifications/initialized" then
			return response(nil, 202)
		end
		return response({
			jsonrpc = "2.0",
			id = message.id,
			result = {tools = {}},
		})
	end)
	local client = Client({
		url = "http://127.0.0.1:38679/mcp",
		token = "secret",
		request = request,
	})

	local initialized = assert(client:initialize())
	t:eq(initialized.protocolVersion, "2025-06-18")
	t:eq(client.server_info.name, "test")
	local listed = assert(client:listTools())
	t:tdeq(listed.tools, {})

	t:eq(calls[1].options.headers["MCP-Protocol-Version"], nil)
	t:eq(calls[1].options.headers.Authorization, "Bearer secret")
	t:eq(calls[2].options.headers["MCP-Protocol-Version"], "2025-06-18")
	t:eq(calls[3].options.headers["MCP-Protocol-Version"], "2025-06-18")
end

---@param t testing.T
function test.requires_initialization_and_returns_rpc_errors(t)
	local request = fake_request(function(message)
		return response({
			jsonrpc = "2.0",
			id = message.id,
			error = {code = -32601, message = "missing"},
		})
	end)
	local client = Client({url = "http://127.0.0.1/mcp", request = request})
	local _, init_err = client:listTools()
	t:eq(init_err, "MCP client is not initialized")

	client.protocol_version = "2025-11-25"
	local _, rpc_err = client:listTools()
	t:eq(rpc_err.code, -32601)
	t:eq(rpc_err.message, "missing")
	client:close()
	local _, close_err = client:listTools()
	t:eq(close_err, "MCP client is closed")
end

---@param t testing.T
function test.server_round_trip(t)
	local scheduler = CosocketScheduler()
	local tool = {
		name = "echo",
		description = "Echo text",
		input_schema = {
			type = "object",
			properties = {text = {type = "string"}},
			required = {"text"},
			additionalProperties = false,
		},
		execute = function(_, args)
			return args.text
		end,
	}
	local server = Server(scheduler, {tool}, {port = 0, on_error = function(err) error(err) end})
	t:assert(server:start())
	local _, port = server:getAddress()
	local client = Client({
		url = ("http://127.0.0.1:%d/mcp"):format(port),
		scheduler = scheduler,
		timeout = 1,
		client_info = {name = "test", version = "dev"},
	})

	local result
	local client_error
	local client_thread = coext.detach(coroutine.create(function()
		local initialized
		initialized, client_error = client:initialize()
		if not initialized then
			return
		end
		local listed
		listed, client_error = client:listTools()
		if not listed then
			return
		end
		result, client_error = client:callTool("echo", {text = listed.tools[1].name})
	end))
	t:assert(coroutine.resume(client_thread))

	pump(t, scheduler, client_thread)
	client:close()
	server:stop()

	t:eq(client_error, nil)
	t:eq(result.content[1].text, "echo")
	t:eq(result.isError, false)
end

---@param t testing.T
function test.cancels_in_flight_request(t)
	local scheduler = CosocketScheduler()
	local tool_started = false
	local tool = {
		name = "wait",
		input_schema = {type = "object", additionalProperties = false},
		execute = function()
			tool_started = true
			scheduler:sleep(10)
			return "late"
		end,
	}
	local server = Server(scheduler, {tool}, {port = 0, on_error = function(err) error(err) end})
	t:assert(server:start())
	local _, port = server:getAddress()
	local client = Client({
		url = ("http://127.0.0.1:%d/mcp"):format(port),
		scheduler = scheduler,
		timeout = 20,
	})

	local initialize_error
	local initialize_thread = coext.detach(coroutine.create(function()
		local initialized
		initialized, initialize_error = client:initialize()
	end))
	t:assert(coroutine.resume(initialize_thread))
	pump(t, scheduler, initialize_thread)
	t:eq(initialize_error, nil)

	local call_error
	local call_thread = coext.detach(coroutine.create(function()
		local _
		_, call_error = client:callTool("wait")
	end))
	t:assert(coroutine.resume(call_thread))
	local deadline = socket.gettime() + 2
	while not tool_started do
		local ok, err = scheduler:update(0.01)
		if not ok and err then
			error(err)
		end
		t:assert(socket.gettime() < deadline)
	end

	t:eq(client:cancel("test canceled"), 1)
	pump(t, scheduler, call_thread)
	t:eq(call_error, "test canceled")
	t:eq(client.closed, false)
	t:eq(next(client.active_streams), nil)

	client:close()
	server:stop()
end

return test
