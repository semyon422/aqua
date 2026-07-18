local ToolResult = {}

---@class mcp.ContentAnnotations
---@field audience ("user"|"assistant")[]?
---@field priority number?
---@field lastModified string?

---@class mcp.TextContent
---@field type "text"
---@field text string
---@field annotations mcp.ContentAnnotations?
---@field _meta {[string]: any}?

---@class mcp.ImageContent
---@field type "image"
---@field data string
---@field mimeType string
---@field annotations mcp.ContentAnnotations?
---@field _meta {[string]: any}?

---@class mcp.AudioContent
---@field type "audio"
---@field data string
---@field mimeType string
---@field annotations mcp.ContentAnnotations?
---@field _meta {[string]: any}?

---@class mcp.ResourceContents
---@field uri string
---@field mimeType string?
---@field text string?
---@field blob string?
---@field _meta {[string]: any}?

---@class mcp.EmbeddedResourceContent
---@field type "resource"
---@field resource mcp.ResourceContents
---@field annotations mcp.ContentAnnotations?
---@field _meta {[string]: any}?

---@class mcp.ResourceLinkContent
---@field type "resource_link"
---@field name string
---@field uri string
---@field title string?
---@field description string?
---@field mimeType string?
---@field size number?
---@field annotations mcp.ContentAnnotations?
---@field _meta {[string]: any}?

---@alias mcp.ContentBlock mcp.TextContent|mcp.ImageContent|mcp.AudioContent|mcp.EmbeddedResourceContent|mcp.ResourceLinkContent

---@class mcp.ToolResult
---@field content mcp.ContentBlock[]
---@field structured_content table?
---@field is_error boolean?

---@class mcp.CallToolResult
---@field content mcp.ContentBlock[]
---@field structuredContent table?
---@field isError boolean

---@param data string
---@return boolean
local function is_base64(data)
	if #data % 4 == 1 or data:find("[^A-Za-z0-9+/=]") then
		return false
	end
	local padding = data:match("=+$") or ""
	return #padding <= 2 and not data:sub(1, #data - #padding):find("=", 1, true)
end

---@param annotations any
---@param path string
---@return true?
---@return string?
local function validate_annotations(annotations, path)
	if annotations == nil then
		return true
	elseif type(annotations) ~= "table" then
		return nil, path .. ".annotations must be an object"
	end
	if annotations.priority ~= nil and (type(annotations.priority) ~= "number" or annotations.priority < 0 or annotations.priority > 1) then
		return nil, path .. ".annotations.priority must be between 0 and 1"
	end
	if annotations.lastModified ~= nil and type(annotations.lastModified) ~= "string" then
		return nil, path .. ".annotations.lastModified must be a string"
	end
	if annotations.audience ~= nil then
		if type(annotations.audience) ~= "table" then
			return nil, path .. ".annotations.audience must be an array"
		end
		for index, audience in ipairs(annotations.audience) do
			if audience ~= "user" and audience ~= "assistant" then
				return nil, ("%s.annotations.audience[%d] is invalid"):format(path, index)
			end
		end
	end
	return true
end

---@param block any
---@param path string
---@return true?
---@return string?
local function validate_block(block, path)
	if type(block) ~= "table" or type(block.type) ~= "string" then
		return nil, path .. " must be a content block"
	end
	local ok, err = validate_annotations(block.annotations, path)
	if not ok then
		return nil, err
	end
	if block._meta ~= nil and type(block._meta) ~= "table" then
		return nil, path .. "._meta must be an object"
	end

	if block.type == "text" then
		if type(block.text) ~= "string" then
			return nil, path .. ".text must be a string"
		end
	elseif block.type == "image" or block.type == "audio" then
		if type(block.data) ~= "string" or not is_base64(block.data) then
			return nil, path .. ".data must be base64"
		elseif type(block.mimeType) ~= "string" then
			return nil, path .. ".mimeType must be a string"
		end
	elseif block.type == "resource" then
		local resource = block.resource
		if type(resource) ~= "table" or type(resource.uri) ~= "string" then
			return nil, path .. ".resource must contain a URI"
		elseif resource.mimeType ~= nil and type(resource.mimeType) ~= "string" then
			return nil, path .. ".resource.mimeType must be a string"
		end
		local has_text = type(resource.text) == "string"
		local has_blob = type(resource.blob) == "string"
		if has_text == has_blob then
			return nil, path .. ".resource must contain exactly one of text or blob"
		elseif has_blob and not is_base64(resource.blob) then
			return nil, path .. ".resource.blob must be base64"
		end
	elseif block.type == "resource_link" then
		if type(block.name) ~= "string" then
			return nil, path .. ".name must be a string"
		elseif type(block.uri) ~= "string" then
			return nil, path .. ".uri must be a string"
		elseif block.mimeType ~= nil and type(block.mimeType) ~= "string" then
			return nil, path .. ".mimeType must be a string"
		elseif block.size ~= nil and type(block.size) ~= "number" then
			return nil, path .. ".size must be a number"
		end
	else
		return nil, path .. " has unknown content type " .. block.type
	end
	return true
end

---@param output any
---@param legacy_is_error any
---@param legacy_structured_content any
---@return mcp.CallToolResult?
---@return string?
function ToolResult.normalize(output, legacy_is_error, legacy_structured_content)
	---@type mcp.ContentBlock[]
	local content
	local structured_content
	local is_error
	if type(output) == "string" then
		content = {{type = "text", text = output}}
		structured_content = legacy_structured_content
		is_error = legacy_is_error == true
	elseif type(output) == "table" then
		if legacy_is_error ~= nil or legacy_structured_content ~= nil then
			return nil, "tool mixed legacy and structured result forms"
		end
		if type(output.content) ~= "table" then
			return nil, "tool result content must be an array"
		end
		if output.is_error ~= nil and type(output.is_error) ~= "boolean" then
			return nil, "tool result is_error must be a boolean"
		end
		content = output.content
		structured_content = output.structured_content
		is_error = output.is_error == true
	else
		return nil, "tool returned an invalid result"
	end

	if structured_content ~= nil and type(structured_content) ~= "table" then
		return nil, "tool returned non-table structured content"
	end
	for index, block in ipairs(content) do
		local ok, err = validate_block(block, ("content[%d]"):format(index))
		if not ok then
			return nil, err
		end
	end
	for key in pairs(content) do
		if type(key) ~= "number" or key < 1 or key > #content or key % 1 ~= 0 then
			return nil, "tool result content must be an array"
		end
	end
	return {
		content = content,
		structuredContent = structured_content,
		isError = is_error,
	}
end

return ToolResult
