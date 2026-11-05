local ChatCompletionsClient = require("ai.openai.ChatCompletionsClient")

-- Keep the public Z.ai names for existing standalone proxy integrations.
---@alias zai.RequestFunc openai.RequestFunc
---@alias zai.OpenStreamFunc openai.OpenStreamFunc
---@alias zai.ProviderError openai.ChatCompletionsError
---@alias zai.ChatErrorBody openai.ChatErrorBody
---@alias zai.ChatProviderResponse openai.ChatCompletionResponse
---@alias zai.ChatProviderChoice openai.ChatCompletionChoice
---@alias zai.ToolCallDeltaFunction openai.ChatFunctionDelta
---@alias zai.ToolCallDelta openai.ChatToolDelta
---@alias zai.MessageDelta openai.ChatCompletionDelta
---@alias zai.ToolCall openai.ChatCompletionToolCall
---@alias zai.Message openai.ChatCompletionMessage

---@class zai.ClientOptions : openai.ChatCompletionsClientOptions
---@field api_key string

-- GLM coding-plan facade: the raw Chat Completions contract is unchanged;
-- request normalization belongs to ai.zai.Protocol, not to the transport.
---@class zai.Client : openai.ChatCompletionsClient
---@operator call: zai.Client
local Client = ChatCompletionsClient + {}

Client.error_label = "Z.ai"

---@param options zai.ClientOptions
function Client:new(options)
	assert(type(options.api_key) == "string" and options.api_key ~= "", "api_key is required")
	ChatCompletionsClient.new(self, options)
end

return Client
