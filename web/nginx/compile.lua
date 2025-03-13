require("aqua.env.openresty")
local nginx_config = require("nginx_config")
local etlua_util = require("web.framework.page.etlua_util")

local path = "aqua/web/nginx/nginx.conf.template"
local f = assert(io.open(path, "rb"))
local conf = f:read("*a")
f:close()

local fn = etlua_util.compile(conf, path)
local data = fn(nginx_config)

f = assert(io.open("nginx.conf", "wb"))
f:write(data)
f:close()
