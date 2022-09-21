local boundary = "------------------------d67fe448c18233b3"

return function(files)
	local body = {}
	for _, file in ipairs(files) do
		table.insert(body, "--" .. boundary)
		table.insert(body, ('Content-Disposition: form-data; name=%q; filename=%q'):format(
			file.name, file.filename or file.name
		))
		table.insert(body, "Content-Type: application/octet-stream")
		table.insert(body, "")
		table.insert(body, file[1])
	end
	table.insert(body, "--" .. boundary .. "--")
	table.insert(body, "")

	body = table.concat(body, "\r\n")

	local headers = {
		["Content-Length"] = #body,
		["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
	}

	return body, headers
end
