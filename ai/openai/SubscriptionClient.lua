local class = require("class")
local BaseResponsesClient = require("ai.openai.BaseResponsesClient")

---@class openai.ISubscriptionAuth
---@field getAccess fun(self: openai.ISubscriptionAuth): string?, string?, string?

---@class openai.SubscriptionClientOptions : openai.BaseResponsesClientOptions
---@field auth openai.ISubscriptionAuth

-- Client for the ChatGPT Codex Responses subscription backend: OAuth
-- authorization headers, Codex endpoint, and its transport constraints
-- (`store = false`, encrypted reasoning inclusion, `max_output_tokens` omission).
---@class openai.SubscriptionClient : openai.BaseResponsesClient
---@operator call: openai.SubscriptionClient
---@field auth openai.ISubscriptionAuth
local SubscriptionClient = BaseResponsesClient + {}

SubscriptionClient.responses_url = "https://chatgpt.com/backend-api/codex/responses"
SubscriptionClient.error_label = "OpenAI subscription"

---@param options openai.SubscriptionClientOptions
function SubscriptionClient:new(options)
	self.auth = assert(options.auth, "auth is required")
	BaseResponsesClient.new(self, options)
end

---@return true?
---@return string?
function SubscriptionClient:authorize()
	local access_token, account_id, err = self.auth:getAccess()
	if not access_token then return nil, err or "OpenAI login is required" end
	if not account_id or account_id == "" then return nil, "OpenAI login has no account ID" end
	self.access_token = access_token
	self.account_id = account_id
	return true
end

-- The subscription endpoint authenticates per request through the shared
-- OAuth credential object and identifies the ChatGPT workspace.
---@param client_request_id string
---@return {[string]: string}
function SubscriptionClient:createHeaders(client_request_id)
	local headers = BaseResponsesClient.createHeaders(self, client_request_id)
	headers.Authorization = "Bearer " .. self.access_token
	headers["ChatGPT-Account-Id"] = self.account_id
	headers.session_id = self.session_id or client_request_id
	headers["OpenAI-Beta"] = "responses=experimental"
	headers.Originator = "openai-proxy"
	headers["User-Agent"] = "openai-proxy"
	return headers
end

-- The ChatGPT Codex subscription endpoint rejects the public Responses
-- max_output_tokens field. The upstream model limit still applies, so omit
-- it while preserving the rest of the caller's stateless Responses request.
-- It also requires encrypted reasoning for stateless tool rounds and forces
-- stateless storage.
---@param body {[string]: any}
---@param request {[string]: any}
function SubscriptionClient:adaptNativeBody(body, request)
	body.store = false
	body.max_output_tokens = nil
	local include = body.include
	---@type any[]
	local request_include = type(include) == "table" and include or {}
	local has_encrypted_reasoning = false
	for _, value in ipairs(request_include) do
		if value == "reasoning.encrypted_content" then has_encrypted_reasoning = true end
	end
	if not has_encrypted_reasoning then
		---@type any[]
		local output = {}
		for _, value in ipairs(request_include) do
			table.insert(output, value)
		end
		table.insert(output, "reasoning.encrypted_content")
		body.include = output
	end
end

return SubscriptionClient
