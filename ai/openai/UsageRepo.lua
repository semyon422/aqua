local class = require("class")
local json = require("web.json")

---@class openai.ModelPrice
---@field input number? USD per million input tokens
---@field output number? USD per million output tokens
---@field cached_input number? USD per million cached input tokens

---@class openai.UsageRepo
---@operator call: openai.UsageRepo
local UsageRepo = class()

---@param models rdb.Models
---@param prices {[string]: openai.ModelPrice}?
function UsageRepo:new(models, prices)
	self.models = models
	self.prices = prices or {}
	for model, price in pairs(self.prices) do
		assert(type(model) == "string" and model ~= "", "model price requires a model name")
		---@type ("input"|"output"|"cached_input")[]
		local keys = {"input", "output", "cached_input"}
		for _, key in ipairs(keys) do
			---@type number?
			local value = price[key]
			assert(value == nil or (type(value) == "number" and value >= 0 and value < math.huge),
				"model price must be a finite non-negative number")
		end
	end
end

-- Byte-based approximation, not a tokenizer; multimodal costs are unknown.
---@param value any
---@return integer
local function estimate(value)
	if value == nil then return 0 end
	return math.ceil(#json.encode(value) / 4)
end

---@param now number
---@param client string
---@param status integer
---@param request {[string]: any}?
---@param result {[string]: any}?
---@param model string?
function UsageRepo:record(now, client, status, request, result, model)
	local usage = result and result.usage
	local input = usage and usage.input_tokens
	local output = usage and usage.output_tokens
	local estimated = input == nil or output == nil
	if input == nil then
		input = request and estimate({input = request.input, messages = request.messages,
			instructions = request.instructions, tools = request.tools, functions = request.functions}) or 0
	end
	if output == nil then
		output = result and estimate({output = result.output, content = result.content,
			reasoning_content = result.reasoning_content, tool_calls = result.tool_calls}) or 0
	end
	local details = usage and usage.input_tokens_details
	local cached = details and details.cached_tokens or 0
	assert(type(cached) == "number" and cached >= 0 and cached % 1 == 0 and cached <= input,
		"cached token count must be an integer between zero and input tokens")
	model = model or (request and type(request.model) == "string" and request.model or "")
	self.models.proxy_usage_models.orm:query([[INSERT INTO proxy_usage_models
		(bucket, client, model, requests, errors, input_tokens, output_tokens, estimated_requests, cached_input_tokens)
		VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?)
		ON CONFLICT(bucket, client, model) DO UPDATE SET
		requests = requests + 1, errors = errors + excluded.errors,
		input_tokens = input_tokens + excluded.input_tokens,
		output_tokens = output_tokens + excluded.output_tokens,
		estimated_requests = estimated_requests + excluded.estimated_requests,
		cached_input_tokens = cached_input_tokens + excluded.cached_input_tokens]],
		{math.floor(now / 3600) * 3600, client, model, status >= 400 and 1 or 0,
			input, output, estimated and 1 or 0, cached})
end

---@param now number
---@return table
function UsageRepo:history(now)
	local last = math.floor(now / 3600) * 3600
	local first = last - 167 * 3600
	local rows = self.models.proxy_usage_models:select({bucket__gte = first, bucket__lte = last}, {
		order = {"bucket", "client", "model"},
	})
	for _, row in ipairs(rows) do
		local price = self.prices[row.model]
		row.cache_savings_usd = row.cached_input_tokens
			* ((price and price.input or 0) - (price and price.cached_input or 0)) / 1000000
		row.cost_usd = ((row.input_tokens - row.cached_input_tokens) * (price and price.input or 0)
			+ row.cached_input_tokens * (price and price.cached_input or 0)
			+ row.output_tokens * (price and price.output or 0)) / 1000000
	end
	return {bucket_seconds = 3600, first_bucket = first, last_bucket = last,
		generated_at = now, currency = "USD", rows = json.array(rows)}
end

return UsageRepo
