local SseParser = require("ai.openai.SseParser")

local test = {}

---@param t testing.T
function test.parses_fragmented_and_multiline_events(t)
	local events = {}
	local parser = SseParser(function(data)
		table.insert(events, data)
	end)
	parser:feed(": comment\r\nda")
	parser:feed("ta: first\r\ndata: second\r")
	parser:feed("\n\r\ndata: [DONE]\n\n")
	parser:finish()

	t:tdeq(events, {"first\nsecond", "[DONE]"})
end

---@param t testing.T
function test.finish_flushes_final_event(t)
	local event
	local parser = SseParser(function(data) event = data end)
	parser:feed("data: final")
	parser:finish()
	t:eq(event, "final")
end

return test
