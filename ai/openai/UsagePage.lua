local UsagePage = {}

local page_path = "aqua/ai/openai/usage.html"
---@type string?
local cached_page

---@return string
function UsagePage.render()
	if cached_page then return cached_page end
	local file, err = io.open(page_path, "rb")
	assert(file, ("failed to open usage page %s: %s"):format(page_path, tostring(err)))
	local page
	page, err = file:read("*a")
	local close_ok, close_err = file:close()
	assert(page and close_ok, ("failed to read usage page %s: %s"):format(page_path, tostring(err or close_err)))
	cached_page = page
	return page
end

return UsagePage
