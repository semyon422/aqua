local class = require("class")
local BaseResponsesClient = require("ai.openai.BaseResponsesClient")

---@class openai.ResponsesClientOptions : openai.BaseResponsesClientOptions
---@field base_url string
---@field api_key string?

-- Client for any OpenAI-compatible Responses endpoint (including the local
-- standalone proxy): base URL, bearer API key, and a caller-controlled
-- request body without subscription backend constraints.
---@class openai.ResponsesClient : openai.BaseResponsesClient
---@operator call: openai.ResponsesClient
---@field base_url string
---@field api_key string?
local ResponsesClient = BaseResponsesClient + {}

ResponsesClient.error_label = "OpenAI Responses"

---@param options openai.ResponsesClientOptions
function ResponsesClient:new(options)
	assert(options.base_url ~= "", "base_url is required")
	self.base_url = options.base_url:gsub("/$", "")
	self.api_key = options.api_key
	BaseResponsesClient.new(self, options)
	self.responses_url = self.base_url .. "/responses"
end

---@param client_request_id string
---@return {[string]: string}
function ResponsesClient:createHeaders(client_request_id)
	local headers = BaseResponsesClient.createHeaders(self, client_request_id)
	if self.api_key and self.api_key ~= "" then
		headers.Authorization = "Bearer " .. self.api_key
	end
	return headers
end

return ResponsesClient
