local Protocol = {}

Protocol.latest_version = "2025-11-25"
Protocol.supported_versions = {
	["2025-03-26"] = true,
	["2025-06-18"] = true,
	["2025-11-25"] = true,
}

---@param version string
---@return boolean
function Protocol.isSupported(version)
	return Protocol.supported_versions[version] == true
end

return Protocol
