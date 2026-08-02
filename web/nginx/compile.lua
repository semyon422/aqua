require("aqua.env.openresty")
local etlua = require("web.etlua")

local output_path = os.getenv("NGINX_OUTPUT_PATH") or "nginx.conf"
local nginx_config = require("web.nginx.config")
nginx_config.mime_types_path = os.getenv("NGINX_MIME_TYPES_PATH") or nginx_config.mime_types_path
nginx_config.error_log_path = os.getenv("NGINX_ERROR_LOG_PATH") or nginx_config.error_log_path
nginx_config.access_log_path = os.getenv("NGINX_ACCESS_LOG_PATH") or nginx_config.access_log_path
nginx_config.pid_path = os.getenv("NGINX_PID_PATH") or nginx_config.pid_path
nginx_config.temp_path = os.getenv("NGINX_TEMP_PATH") or nginx_config.temp_path

local path = "aqua/web/nginx/nginx.conf.template"
local f = assert(io.open(path, "rb"))
local conf = f:read("*a")
f:close()

local fn = etlua.compile(conf, path)
local data = fn(nginx_config)

f = assert(io.open(output_path, "wb"))
f:write(data)
f:close()
