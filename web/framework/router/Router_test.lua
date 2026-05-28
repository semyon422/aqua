local Router = require("web.framework.router.Router")
local IResource = require("web.framework.IResource")

local test = {}

function test.basic_routing(t)
	local router = Router()

	---@class test.Resource1: web.IResource
	local Resource1 = IResource + {}
	Resource1.routes = {
		{"/hello", {GET = "hello"}},
		{"/users/:id", {GET = "get"}},
	}

	router:route({Resource1})

	local resource, params, methods = router:getResource("/hello")
	t:ne(resource, nil)
	t:ne(methods, nil)
	t:eq(methods.GET, "hello")

	resource, params, methods = router:getResource("/users/42")
	t:ne(resource, nil)
	t:eq(params.id, "42")
end

function test.no_match(t)
	local router = Router()

	---@class test.Resource2: web.IResource
	local Resource2 = IResource + {}
	Resource2.routes = {
		{"/hello", {GET = "hello"}},
	}

	router:route({Resource2})

	local resource = router:getResource("/not-found")
	t:eq(resource, nil)

	local resource = router:getResource("/hello", nil)
	t:ne(resource, nil) -- no host means fallback to unrestricted routes
end

function test.domain_restricted(t)
	local router = Router()

	---@class test.ResourceA: web.IResource
	local ResourceA = IResource + {}
	ResourceA.routes = {
		{"/", {GET = "index"}},
	}
	ResourceA.domains = {"osu.example.com"}

	---@class test.ResourceB: web.IResource
	local ResourceB = IResource + {}
	ResourceB.routes = {
		{"/", {GET = "website"}},
	}

	router:route({ResourceA, ResourceB})

	-- Request from osu.example.com should match ResourceA
	local resource, _params, methods = router:getResource("/", "osu.example.com")
	t:ne(resource, nil)
	t:eq(methods.GET, "index")

	-- Request from other.example.com should fall back to ResourceB
	local resource, _params, methods = router:getResource("/", "other.example.com")
	t:ne(resource, nil)
	t:eq(methods.GET, "website")

	-- No host should fall back to ResourceB
	local resource, _params, methods = router:getResource("/")
	t:ne(resource, nil)
	t:eq(methods.GET, "website")
end

function test.domain_wildcard(t)
	local router = Router()

	---@class test.ResourceC: web.IResource
	local ResourceC = IResource + {}
	ResourceC.routes = {
		{"/", {POST = "bancho"}},
	}
	ResourceC.domains = {"c.*"}

	---@class test.ResourceD: web.IResource
	local ResourceD = IResource + {}
	ResourceD.routes = {
		{"/", {GET = "default"}},
	}

	router:route({ResourceC, ResourceD})

	-- c.example.com should match ResourceC
	local resource, _params, methods = router:getResource("/", "c.example.com")
	t:ne(resource, nil)
	t:eq(methods.POST, "bancho")

	-- c4.example.com should match ResourceC
	local resource, _params, methods = router:getResource("/", "c4.example.com")
	t:ne(resource, nil)
	t:eq(methods.POST, "bancho")

	-- osu.example.com should NOT match ResourceC, fall back to ResourceD
	local resource, _params, methods = router:getResource("/", "osu.example.com")
	t:ne(resource, nil)
	t:eq(methods.GET, "default")
end

function test.domain_priority(t)
	local router = Router()

	---@class test.ResourceExact: web.IResource
	local ResourceExact = IResource + {}
	ResourceExact.routes = {
		{"/api", {GET = "exact"}},
	}
	ResourceExact.domains = {"api.example.com"}

	---@class test.ResourceWildcard: web.IResource
	local ResourceWildcard = IResource + {}
	ResourceWildcard.routes = {
		{"/api", {GET = "wildcard"}},
	}
	ResourceWildcard.domains = {"api.*"}

	---@class test.ResourceDefault: web.IResource
	local ResourceDefault = IResource + {}
	ResourceDefault.routes = {
		{"/api", {GET = "default"}},
	}

	router:route({ResourceExact, ResourceWildcard, ResourceDefault})

	-- Exact match should win
	local resource, _params, methods = router:getResource("/api", "api.example.com")
	t:eq(methods.GET, "exact")

	-- Wildcard match
	local resource, _params, methods = router:getResource("/api", "api.other.com")
	t:eq(methods.GET, "wildcard")

	-- No domain match, fallback
	local resource, _params, methods = router:getResource("/api", "random.com")
	t:eq(methods.GET, "default")
end

function test.domain_match_utility(t)
	local router = Router()

	-- Exact match
	t:aeq(router:domain_match("osu.example.com", {"osu.example.com"}), true)
	t:aeq(router:domain_match("other.example.com", {"osu.example.com"}), false)

	-- Wildcard match
	t:aeq(router:domain_match("c.example.com", {"c.*"}), true)
	t:aeq(router:domain_match("c4.example.com", {"c.*"}), true)
	t:aeq(router:domain_match("c.deep.nested.example.com", {"c.*"}), true)
	t:aeq(router:domain_match("osu.example.com", {"c.*"}), false)

	-- Multiple patterns
	t:aeq(router:domain_match("osu.example.com", {"c.*", "osu.*"}), true)
	t:aeq(router:domain_match("b.example.com", {"c.*", "osu.*"}), false)

	-- Empty patterns
	t:aeq(router:domain_match("anything.com", {}), false)
end

return test
