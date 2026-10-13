local class = require("class")
local json = require("web.json")
local JsonSchema = require("mcp.JsonSchema")

---@class ai.router.McpToolDefinition
---@field name string
---@field method string
---@field description string
---@field input_schema table
---@field output_schema mcp.JsonSchemaObject
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
	self.output_schema = definition.output_schema
	self.mutation = definition.mutation
	self.annotations = definition.annotations
end

---@param args {[string]: any}
---@return string
---@return boolean
---@return ai.router.ManagementResult?
function McpTool:execute(args)
	local ok, result, err = pcall(self.management.execute, self.management, self.method, args, self.mutation)
	if not ok or not result then
		local failure = {error = "Operation failed; inspect router state before retrying.",
			operation = self.mutation and {persistence = "unknown", reload = "not_attempted"} or nil}
		return json.encode(failure), true, failure
	end
	if not JsonSchema.validate(self.output_schema, result) then
		local failure = {error = "Invalid operation result; inspect router state before retrying.", operation = result.operation}
		if not JsonSchema.validate(self.output_schema, failure) then
			failure.operation = self.mutation and {persistence = "unknown", reload = "not_attempted"} or nil
		end
		return json.encode(failure), true, failure
	end
	return json.encode(result), err ~= nil, result
end

return McpTool
