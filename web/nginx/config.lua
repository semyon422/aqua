local path = assert(os.getenv("NGINX_CONFIG_PATH"), "NGINX_CONFIG_PATH is not set")

---@type web.NginxConfig
return dofile(path)
