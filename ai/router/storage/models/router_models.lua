local json_codec = require("ai.router.storage.models.json_codec")

---@type rdb.ModelOptions
local router_models = {}

router_models.types = {
	chain = json_codec,
}

return router_models
