local json_codec = require("ai.router.storage.models.json_codec")

---@type rdb.ModelOptions
local router_subscriptions = {}

router_subscriptions.types = {
	enabled = "boolean",
	config = json_codec,
	limits = json_codec,
}

return router_subscriptions
