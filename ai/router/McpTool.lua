local class = require("class")
local json = require("web.json")

---@class ai.router.McpToolDefinition
---@field name string
---@field method string
---@field description string
---@field input_schema table
---@field mutation boolean
---@field annotations mcp.ToolAnnotations

---@class ai.router.McpTool: mcp.Tool
---@operator call: ai.router.McpTool
---@field management ai.router.Management
---@field method string
---@field mutation boolean
local McpTool = class()

---@param management ai.router.Management
---@param definition ai.router.McpToolDefinition
function McpTool:new(management, definition)
	self.management = management
	self.name = definition.name
	self.method = definition.method
	self.description = definition.description
	self.input_schema = definition.input_schema
	self.mutation = definition.mutation
	self.annotations = definition.annotations
end

---@param args {[string]: any}
---@return string
---@return boolean
---@return table?
function McpTool:execute(args)
	local ok, result, err = pcall(self.management.execute, self.management, self.method, args, self.mutation)
	if not ok then return "Operation failed; inspect router state before retrying.", true end
	if not result then return assert(err), true end
	return json.encode(result), err ~= nil, result
end

return McpTool
