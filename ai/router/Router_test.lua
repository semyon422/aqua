local Catalog = require("ai.router.Catalog")
local Router = require("ai.router.Router")

local test = {}

---@param id integer
---@param name string
---@param priority integer
---@param models string[]
---@param opts {kind: "openai"|"zai"|"openai_compat"?, enabled: boolean?, redirects: {[string]: string}?, limits: table?}?
---@return ai.router.SubscriptionRow
local function subRow(id, name, priority, models, opts)
	opts = opts or {}
	local kind = opts.kind or "zai"
	local config = {
		models = models,
		model_redirects = opts.redirects,
	}
	if kind == "zai" then
		config.base_url = "https://api.z.ai/api/coding/paas/v4"
		config.api_key = "key"
	elseif kind == "openai" then
		config.auth_path = "userdata/x.lua"
	else
		config.base_url = "http://127.0.0.1:8080/v1"
	end
	return {
		id = id,
		name = name,
		kind = kind,
		priority = priority,
		enabled = opts.enabled ~= false,
		config = config,
		limits = opts.limits or {},
		created_at = 0,
		updated_at = 0,
	}
end

---@param name string
---@param chain string[]
---@return ai.router.ModelRow
local function modelRow(name, chain)
	return {
		id = 1,
		name = name,
		chain = chain,
		description = nil,
		created_at = 0,
		updated_at = 0,
	}
end

---@param subs ai.router.SubscriptionRow[]
---@param models ai.router.ModelRow[]
---@return ai.router.CatalogState
---@return string[] errors
local function build(subs, models)
	return Catalog.fromRows(subs, models)
end

---@param t testing.T
function test.catalog_builds_sorted_state(t)
	local state, errors = build({
		subRow(2, "zai-2", 10, {"glm-5.3"}),
		subRow(1, "zai-1", 5, {"glm-5.3", "glm-5.3-flash"}),
		subRow(3, "local", 20, {"llama-70b"}, {kind = "openai_compat"}),
	}, {
		modelRow("lite", {"glm-5.3-flash", "llama-70b"}),
	})
	t:tdeq(errors, {})
	t:eq(#state.subscriptions, 3)
	t:eq(state.subscriptions[1].name, "zai-1")
	t:eq(state.subscriptions[2].name, "zai-2")
	t:eq(state.subscriptions[3].name, "local")
	t:eq(state.concrete_models["llama-70b"], true)
	t:eq(state.alias_models["lite"][1], "glm-5.3-flash")
	t:eq(state.public_models["lite"], true)
	t:eq(state.subscriptions[1].usage_source.five_hour, "upstream")
	t:eq(state.subscriptions[3].usage_source.five_hour, "local")
end

---@param t testing.T
function test.catalog_disabled_subscriptions_stay_concrete(t)
	local state, errors = build({
		subRow(1, "zai-1", 1, {"glm-5.3"}, {enabled = false}),
	}, {})
	t:tdeq(errors, {})
	t:eq(state.concrete_models["glm-5.3"], true)
	t:eq(state.public_models["glm-5.3"], nil)
	t:eq(state.subscriptions[1].enabled, false)
end

---@param t testing.T
function test.catalog_rejects_bad_chains(t)
	local _, errors = build({subRow(1, "zai-1", 1, {"glm-5.3"})}, {
		modelRow("bad", {"missing-model"}),
	})
	t:eq(#errors, 1)
	t:assert(errors[1]:find("not served by any subscription", 1, true))

	_, errors = build({subRow(1, "zai-1", 1, {"a", "b"})}, {
		modelRow("x", {"y"}),
		modelRow("y", {"a"}),
	})
	t:eq(#errors, 1)
	t:assert(errors[1]:find("must not reference a custom model", 1, true))

	_, errors = build({subRow(1, "zai-1", 1, {"glm-5.3"})}, {
		modelRow("glm-5.3", {"glm-5.3"}),
	})
	t:eq(#errors, 1)
	t:assert(errors[1]:find("must not shadow a concrete model name", 1, true))
end

---@param t testing.T
function test.catalog_rejects_bad_subscriptions(t)
	local _, errors = build({subRow(1, "s", 1, {"a"}, {redirects = {b = "a"}})}, {})
	t:eq(#errors, 1)

	_, errors = build({subRow(1, "s", 1, {"a"}, {redirects = {a = "a"}})}, {})
	t:eq(#errors, 1)

	local row = subRow(1, "s", 1, {"a"})
	row.config.models = {}
	_, errors = build({row}, {})
	t:eq(#errors, 1)

	row = subRow(1, "s", 1, {"a"}, {limits = {weekly_threshold = 150}})
	_, errors = build({row}, {})
	t:eq(#errors, 1)

	row = subRow(1, "s", 1, {"a"})
	row.config.unknown_field = 1
	_, errors = build({row}, {})
	t:eq(#errors, 1)

	row = subRow(1, "s", 1, {"a"})
	row.config = {models = {"a"}}
	_, errors = build({row}, {})
	t:eq(#errors, 1)

	row = subRow(1, "s", 1, {"a"}, {kind = "openai"})
	row.config = {models = {"a"}}
	_, errors = build({row}, {})
	t:eq(#errors, 1)

	row = subRow(1, "s", 1, {"a"}, {limits = {usage_source = {five_hour = "nope"}}})
	_, errors = build({row}, {})
	t:eq(#errors, 1)
end

local function defaultState()
	local state = build({
		subRow(1, "zai-1", 1, {"glm-5.3", "glm-5.3-flash"}, {limits = {five_hour_threshold = 80, weekly_threshold = 90}}),
		subRow(2, "zai-2", 2, {"glm-5.3"}, {limits = {five_hour_threshold = 80}}),
		subRow(3, "openai-1", 3, {"gpt-6-luna"}),
	}, {
		modelRow("lite", {"glm-5.3-flash", "gpt-6-luna"}),
	})
	return state
end

---@param t testing.T
function test.router_resolves_chains(t)
	local router = Router({state = defaultState()})
	t:tdeq(router:resolveChain("lite"), {"glm-5.3-flash", "gpt-6-luna"})
	t:tdeq(router:resolveChain("glm-5.3"), {"glm-5.3"})
	t:eq(router:resolveChain("missing"), nil)

	local chain = router:resolveChain("lite")
	chain[1] = "mutated"
	t:tdeq(router:resolveChain("lite"), {"glm-5.3-flash", "gpt-6-luna"})
end

---@param t testing.T
function test.router_orders_candidates(t)
	local state = defaultState()
	state.subscriptions[1].model_redirects["glm-5.3"] = "glm-5.3-high"
	local router = Router({state = state})

	local candidates = assert(router:candidates("glm-5.3"))
	t:eq(#candidates, 2)
	t:eq(candidates[1].subscription.name, "zai-1")
	t:eq(candidates[1].upstream_model, "glm-5.3-high")
	t:eq(candidates[2].subscription.name, "zai-2")
	t:eq(candidates[2].upstream_model, "glm-5.3")

	candidates = assert(router:candidates("lite"))
	t:eq(#candidates, 2)
	t:eq(candidates[1].subscription.name, "zai-1")
	t:eq(candidates[1].model, "glm-5.3-flash")
	t:eq(candidates[2].subscription.name, "openai-1")
	t:eq(candidates[2].model, "gpt-6-luna")

	local _, err = router:candidates("missing")
	t:eq(err, "unknown model: missing")
end

---@param t testing.T
function test.router_skips_disabled_subscriptions(t)
	local state = defaultState()
	state.subscriptions[1].enabled = false
	local router = Router({state = state})
	local candidates = assert(router:candidates("glm-5.3"))
	t:eq(#candidates, 1)
	t:eq(candidates[1].subscription.name, "zai-2")
end

---@param t testing.T
function test.router_selects_first_available(t)
	local router = Router({state = defaultState()})
	local candidates = assert(router:candidates("lite"))
	local i, candidate, reason = router:select(candidates, 1, {}, nil, 1000)
	t:eq(i, 1)
	t:eq(candidate.subscription.name, "zai-1")
	t:eq(reason, "available")
end

---@param t testing.T
function test.router_skips_depleted(t)
	local router = Router({state = defaultState(), staleness = 120})
	local candidates = assert(router:candidates("glm-5.3"))
	local windows = {
		[1] = {five_hour = {used_percent = 85, updated_at = 950}},
		[2] = {five_hour = {used_percent = 10, updated_at = 950}},
	}
	local i, candidate, reason = router:select(candidates, 1, windows, nil, 1000)
	t:eq(i, 2)
	t:eq(candidate.subscription.name, "zai-2")
	t:eq(reason, "available")

	-- stale data never depletes
	windows[1].five_hour.updated_at = 700
	i, candidate, reason = router:select(candidates, 1, windows, nil, 1000)
	t:eq(i, 1)
	t:eq(reason, "available")

	-- missing used_percent never depletes
	windows[1].five_hour = {used_percent = nil, updated_at = 950}
	i, candidate, reason = router:select(candidates, 1, windows, nil, 1000)
	t:eq(i, 1)
end

---@param t testing.T
function test.router_last_resort_is_least_depleted(t)
	local router = Router({state = defaultState(), staleness = 120})
	local candidates = assert(router:candidates("glm-5.3"))
	local windows = {
		[1] = {
			five_hour = {used_percent = 95, updated_at = 950},
			weekly = {used_percent = 99, updated_at = 950},
		},
		[2] = {five_hour = {used_percent = 82, updated_at = 950}},
		[3] = {five_hour = {used_percent = 90, updated_at = 950}},
	}
	local i, candidate, reason = router:select(candidates, 1, windows, nil, 1000)
	t:eq(i, 2)
	t:eq(candidate.subscription.name, "zai-2")
	t:eq(reason, "depleted")
end

---@param t testing.T
function test.router_cooldowns_block_everything(t)
	local router = Router({state = defaultState(), staleness = 120})
	local candidates = assert(router:candidates("glm-5.3"))
	local cooldowns = {[1] = 1100, [2] = 1100}
	local i, candidate, reason = router:select(candidates, 1, {}, cooldowns, 1000)
	t:eq(i, nil)
	t:eq(candidate, nil)
	t:eq(reason, "unavailable")

	-- cooldowns never serve as last resort even when everything is depleted
	local windows = {
		[1] = {five_hour = {used_percent = 95, updated_at = 950}},
	}
	cooldowns = {[1] = 1100}
	i, candidate, reason = router:select(candidates, 1, windows, cooldowns, 1000)
	t:eq(i, 2)
	t:eq(candidate.subscription.name, "zai-2")
	t:eq(reason, "available")

	-- an expired cooldown is ignored
	cooldowns = {[1] = 999, [2] = 1100}
	i, candidate, reason = router:select(candidates, 1, {}, cooldowns, 1000)
	t:eq(i, 1)
	t:eq(reason, "available")
end

---@param t testing.T
function test.router_failover_start_offset(t)
	local router = Router({state = defaultState(), staleness = 120})
	local candidates = assert(router:candidates("lite"))
	-- first candidate failed with 429: continue after it, even though it is available
	local i, candidate, reason = router:select(candidates, 2, {}, nil, 1000)
	t:eq(i, 2)
	t:eq(candidate.subscription.name, "openai-1")

	i, candidate, reason = router:select(candidates, 3, {}, nil, 1000)
	t:eq(i, nil)
	t:eq(reason, "unavailable")
end

---@param t testing.T
function test.router_max_fill_uses_freshest_windows(t)
	local router = Router({state = defaultState(), staleness = 120})
	local sub = defaultState().subscriptions[1]
	t:eq(router:maxFill(sub, {}, 1000), 0)
	t:eq(router:maxFill(sub, {[1] = {five_hour = {used_percent = 30, updated_at = 950}}}, 1000), 30)
	t:eq(router:maxFill(sub, {[1] = {
		five_hour = {used_percent = 30, updated_at = 950},
		weekly = {used_percent = 70, updated_at = 950},
	}}, 1000), 70)
	t:eq(router:maxFill(sub, {[1] = {
		five_hour = {used_percent = 30, updated_at = 950},
		weekly = {used_percent = 70, updated_at = 500},
	}}, 1000), 30)
end

return test
