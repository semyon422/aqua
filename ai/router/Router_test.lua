local Catalog = require("ai.router.Catalog")
local Router = require("ai.router.Router")

local test = {}

---@param id integer
---@param name string
---@param models string[]
---@param enabled boolean?
---@return ai.router.ChannelRow
local function subRow(id, name, models, enabled)
	return {id = id, name = name, kind = "openai_compat", enabled = enabled ~= false,
		config = {models = models, base_url = "http://localhost/v1"}, limits = {}, created_at = 0, updated_at = 0}
end

---@param name string
---@param target string
---@return ai.router.ModelRow
local function alias(name, target)
	return {id = 1, name = name, target = target, created_at = 0, updated_at = 0}
end

---@return ai.router.CatalogState
local function defaultState()
	local state, errors = Catalog.fromRows({subRow(2, "pro", {"gpt", "org/model"}),
		subRow(1, "plus", {"gpt"})}, {alias("fast", "pro/gpt")})
	assert(#errors == 0)
	return state
end

---@param t testing.T
function test.catalog_builds_qualified_names_sorted_by_id(t)
	local state = defaultState()
	t:eq(state.channels[1].name, "plus")
	t:eq(state.channels[2].name, "pro")
	t:tdeq(state.public_models, {["plus/gpt"] = true, ["pro/gpt"] = true, ["pro/org/model"] = true, fast = true})
	t:eq(state.concrete_models.gpt, nil)
end

---@param t testing.T
function test.catalog_disabled_models_remain_valid_alias_targets(t)
	local state, errors = Catalog.fromRows({subRow(1, "plus", {"gpt"}, false)}, {alias("fast", "plus/gpt")})
	t:tdeq(errors, {})
	t:eq(state.concrete_models["plus/gpt"], true)
	t:eq(state.public_models["plus/gpt"], nil)
	t:eq(Router({state = state}):resolve("fast"), nil)
end

---@param t testing.T
function test.catalog_rejects_bad_alias_targets(t)
	for _, target in ipairs({"gpt", "missing/gpt", "plus/missing", "other-alias"}) do
		local _, errors = Catalog.fromRows({subRow(1, "plus", {"gpt"})}, {alias("fast", target)})
		t:eq(#errors, 1)
	end
end

---@param t testing.T
function test.catalog_rejects_alias_chains_and_qualified_alias_names(t)
	local _, errors = Catalog.fromRows({subRow(1, "plus", {"gpt"})}, {
		alias("fast", "other"), alias("other", "plus/gpt"),
	})
	t:eq(#errors, 1)
	_, errors = Catalog.fromRows({subRow(1, "plus", {"gpt"})}, {alias("plus/gpt", "plus/gpt")})
	t:eq(#errors, 1)
end

---@param t testing.T
function test.catalog_rejects_bad_channel_names(t)
	for _, name in ipairs({"a/b", "a b", "", "a\n"}) do
		local _, errors = Catalog.fromRows({subRow(1, name, {"gpt"})}, {})
		t:eq(#errors, 1)
	end
end

---@param t testing.T
function test.catalog_rejects_invalid_config_and_removed_thresholds(t)
	for _, config in ipairs({{models = {}}, {models = {"gpt"}},
		{models = {"gpt"}, base_url = "bad"},
		{models = {"gpt"}, base_url = "http://localhost", unknown = true},
		{models = {"gpt"}, base_url = "http://localhost", model_redirects = {other = "gpt"}},
		{models = {"gpt"}, base_url = "http://localhost", model_redirects = {gpt = "gpt"}}}) do
		local row = subRow(1, "plus", {"gpt"})
		row.config = config
		local _, errors = Catalog.fromRows({row}, {})
		t:assert(#errors > 0)
	end
	for _, limits in ipairs({{weekly_threshold = 80}, {usage_source = {five_hour = "bad"}}, {poll_interval = 1}}) do
		local row = subRow(1, "plus", {"gpt"})
		row.limits = limits
		local _, errors = Catalog.fromRows({row}, {})
		t:assert(#errors > 0)
	end
end

---@param t testing.T
function test.router_resolves_aliases_to_exact_channel(t)
	local router = Router({state = defaultState()})
	t:eq(router:resolveModel("fast"), "pro/gpt")
	t:eq(router:resolve("fast").channel.name, "pro")
	t:eq(router:resolve("plus/gpt").channel.name, "plus")
	t:eq(router:resolve("pro/gpt").channel.name, "pro")
end

---@param t testing.T
function test.router_does_not_guess_unqualified_models(t)
	local router = Router({state = defaultState()})
	for _, name in ipairs({"gpt", "missing/gpt", "plus/missing", "pro/", "missing"}) do
		t:eq(router:resolve(name), nil)
	end
end

---@param t testing.T
function test.router_disabled_target_never_uses_another_channel(t)
	local state = defaultState()
	state.channels[2].enabled = false
	local router = Router({state = state})
	t:eq(router:resolve("fast"), nil)
	t:eq(router:resolve("pro/gpt"), nil)
	t:eq(router:resolve("plus/gpt").channel.name, "plus")
end

---@param t testing.T
function test.router_applies_redirect_after_stripping_prefix(t)
	local state = defaultState()
	state.channels[2].model_redirects.gpt = "gpt-upstream"
	local route = Router({state = state}):resolve("fast")
	t:eq(route.model, "gpt")
	t:eq(route.upstream_model, "gpt-upstream")
end

---@param t testing.T
function test.router_preserves_slashes_in_upstream_models(t)
	local route = Router({state = defaultState()}):resolve("pro/org/model")
	t:eq(route.model, "org/model")
	t:eq(route.upstream_model, "org/model")
end

---@param t testing.T
function test.router_channel_rename_changes_public_names(t)
	local row = subRow(1, "old", {"gpt"})
	row.name = "new"
	local state, errors = Catalog.fromRows({row}, {})
	t:tdeq(errors, {})
	local router = Router({state = state})
	t:eq(router:resolve("old/gpt"), nil)
	t:eq(router:resolve("new/gpt").channel.name, "new")
	_, errors = Catalog.fromRows({row}, {alias("fast", "old/gpt")})
	t:eq(#errors, 1)
end

---@param t testing.T
function test.catalog_accepts_maximum_qualified_target_length(t)
	local name, model = ("s"):rep(64), ("m"):rep(128)
	local state, errors = Catalog.fromRows({subRow(1, name, {model})}, {alias("fast", name .. "/" .. model)})
	t:tdeq(errors, {})
	t:eq(Router({state = state}):resolve("fast").model, model)
end

return test
