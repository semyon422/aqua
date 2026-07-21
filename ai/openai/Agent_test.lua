local json = require("web.json")
local Agent = require("ai.openai.Agent")

local test = {}

---@param replies aqua.openai.Message[]
---@return aqua.openai.Client
local function makeClient(replies)
	return {
		complete = function(_, messages, schemas)
			assert(#schemas == 1)
			return table.remove(replies, 1)
		end,
	}
end

---@return aqua.openai.Tool
local function makeTool()
	return {
		name = "lua_eval",
		schema = {
			type = "function",
			["function"] = {name = "lua_eval", parameters = {type = "object"}},
		},
		execute = function(_, args)
			return json.encode({ok = true, result = args.code})
		end,
	}
end

---@param t testing.T
function test.runs_tool_loop_and_preserves_protocol_order(t)
	local replies = {
		{
			role = "assistant",
			tool_calls = {{
				id = "call_1",
				type = "function",
				["function"] = {name = "lua_eval", arguments = [[{"code":"return 1"}]]},
			}},
		},
		{role = "assistant", content = "The result is 1."},
	}
	local events = {}
	local messages = {{role = "user", content = "evaluate"}}
	local agent = Agent(makeClient(replies), {makeTool()}, {
		on_tool_result = function(call, content)
			table.insert(events, {call.id, content})
		end,
	})

	local message = assert(agent:run(messages))
	t:eq(message.content, "The result is 1.")
	t:eq(#messages, 4)
	t:eq(messages[2].tool_calls[1].id, "call_1")
	t:eq(messages[3].role, "tool")
	t:eq(messages[3].tool_call_id, "call_1")
	t:eq(json.decode(messages[3].content).result, "return 1")
	t:eq(events[1][1], "call_1")
end

---@param t testing.T
function test.invalid_arguments_and_unknown_tools_are_results(t)
	local failures = {}
	local agent = Agent(makeClient({}), {makeTool()}, {
		on_tool_failure = function(name, arguments, err)
			table.insert(failures, {name = name, arguments = arguments, err = err})
		end,
	})
	local invalid = agent:executeTool({
		id = "1",
		type = "function",
		["function"] = {name = "lua_eval", arguments = "{"},
	})
	t:eq(json.decode(invalid).ok, false)

	local unknown = agent:executeTool({
		id = "2",
		type = "function",
		["function"] = {name = "missing", arguments = "{}"},
	})
	t:eq(json.decode(unknown).error, "unknown tool: missing")
	t:eq(#failures, 2)
	t:eq(failures[1].name, "lua_eval")
	t:eq(failures[2].name, "missing")
	t:eq(failures[2].err, "unknown tool: missing")
end

---@param t testing.T
function test.reports_explicit_tool_errors(t)
	local tool = makeTool()
	tool.execute = function()
		return "source file not found", true
	end
	local failure
	local agent = Agent(makeClient({}), {tool}, {
		on_tool_failure = function(name, arguments, err)
			failure = {name = name, arguments = arguments, err = err}
		end,
	})
	local result = agent:executeTool({
		id = "1",
		type = "function",
		["function"] = {name = "lua_eval", arguments = [[{"code":"missing"}]]},
	})
	t:eq(result, "source file not found")
	t:eq(failure.name, "lua_eval")
	t:eq(failure.arguments.code, "missing")
	t:eq(failure.err, "source file not found")
end

---@param t testing.T
function test.bounds_tool_rounds(t)
	local call = {
		role = "assistant",
		tool_calls = {{
			id = "call",
			type = "function",
			["function"] = {name = "lua_eval", arguments = [[{"code":"1"}]]},
		}},
	}
	local agent = Agent(makeClient({call, call}), {makeTool()}, {max_tool_rounds = 1})
	local _, err = agent:run({})
	t:eq(err, "tool round limit exceeded")
end

---@param t testing.T
function test.rejects_tool_calls_without_ids(t)
	local call = {
		role = "assistant",
		tool_calls = {{
			type = "function",
			["function"] = {name = "lua_eval", arguments = "{}"},
		}},
	}
	local agent = Agent(makeClient({call}), {makeTool()})
	local _, err = agent:run({})
	t:eq(err, "provider returned a tool call without an id")
end

---@param t testing.T
function test.streams_and_cancels(t)
	local deltas = {}
	local canceled = false
	local client = {
		completeStream = function(_, _, schemas, on_text_delta)
			assert(#schemas == 1)
			on_text_delta("hel")
			on_text_delta("lo")
			return {role = "assistant", content = "hello"}
		end,
		cancel = function()
			canceled = true
			return true
		end,
	}
	local agent = Agent(client, {makeTool()}, {
		streaming = true,
		on_text_delta = function(delta)
			table.insert(deltas, delta)
		end,
	})
	local message = assert(agent:run({}))
	t:eq(message.content, "hello")
	t:eq(table.concat(deltas), "hello")
	t:eq(agent:cancel(), true)
	t:eq(canceled, true)
end

---@param t testing.T
function test.switches_client(t)
	local first = makeClient({{role = "assistant", content = "first"}})
	local second = makeClient({{role = "assistant", content = "second"}})
	local agent = Agent(first, {makeTool()})
	t:eq(assert(agent:run({})).content, "first")
	agent:setClient(second)
	t:eq(assert(agent:run({})).content, "second")
end

return test
