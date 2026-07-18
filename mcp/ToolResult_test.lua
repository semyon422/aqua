local ToolResult = require("mcp.ToolResult")

local test = {}

---@param t testing.T
function test.normalizes_legacy_text_result(t)
	local result = assert(ToolResult.normalize("hello", false, {value = "hello"}))
	t:tdeq(result, {
		content = {{type = "text", text = "hello"}},
		structuredContent = {value = "hello"},
		isError = false,
	})
end

---@param t testing.T
function test.normalizes_content_blocks(t)
	local content = {
		{type = "text", text = "hello", annotations = {audience = {"assistant"}, priority = 0.5}},
		{type = "image", data = "aGVsbG8=", mimeType = "image/png"},
		{type = "audio", data = "aGVsbG8=", mimeType = "audio/ogg"},
		{
			type = "resource",
			resource = {uri = "file:///tmp/log.txt", mimeType = "text/plain", text = "log"},
		},
		{
			type = "resource_link",
			name = "runtime log",
			uri = "file:///tmp/log.txt",
			mimeType = "text/plain",
			size = 3,
		},
	}
	local result = assert(ToolResult.normalize({
		content = content,
		structured_content = {count = #content},
		is_error = false,
	}))
	t:eq(result.content, content)
	t:tdeq(result.structuredContent, {count = 5})
	t:eq(result.isError, false)
end

---@param t testing.T
function test.rejects_invalid_content(t)
	local _, image_err = ToolResult.normalize({
		content = {{type = "image", data = "not base64!", mimeType = "image/png"}},
	})
	t:eq(image_err, "content[1].data must be base64")

	local _, resource_err = ToolResult.normalize({
		content = {{type = "resource", resource = {uri = "file:///tmp/a", text = "a", blob = "YQ=="}}},
	})
	t:eq(resource_err, "content[1].resource must contain exactly one of text or blob")

	local _, type_err = ToolResult.normalize({content = {{type = "unknown"}}})
	t:eq(type_err, "content[1] has unknown content type unknown")

	local _, mixed_err = ToolResult.normalize({content = {}}, false)
	t:eq(mixed_err, "tool mixed legacy and structured result forms")
end

return test
