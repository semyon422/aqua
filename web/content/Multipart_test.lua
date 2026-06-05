local Multipart = require("web.content.Multipart")
local MultipartString = require("web.content.MultipartString")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Headers = require("web.http.Headers")

local test = {}

---@param t testing.T
function test.basic(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local mp = Multipart(soc, "abcdef")

	mp:send_preamble("preamble")

	mp:send_boundary()
	mp:send_headers(Headers():add("Name", "value1"))
	mp:send("hello")

	mp:send_boundary()
	mp:send_headers(Headers():add("Name", "value2"))
	mp:send("world")

	mp:send_boundary(true)
	mp:send("epilogue")

	soc:close()

	t:eq(str_soc.remainder, ([[
preamble
--abcdef
Name: value1

hello
--abcdef
Name: value2

world
--abcdef--
epilogue]]):gsub("\n", "\r\n"))

	t:tdeq({mp:receive_preamble()}, {"preamble"})

	local headers = assert(mp:receive_headers())
	t:tdeq(headers.headers, {name = {"value1"}})
	t:tdeq({mp:receive("*a")}, {"hello"})

	local headers = assert(mp:receive_headers())
	t:tdeq(headers.headers, {name = {"value2"}})
	t:tdeq({mp:receive("*a")}, {"world"})

	local headers, err = mp:receive_headers()
	t:assert(not headers)
	t:eq(err, "no parts")

	t:tdeq({mp:receive_epilogue()}, {"epilogue"})
end

---@param t testing.T
function test.basic_no_preamble_no_epilogue(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)

	local mp = Multipart(soc, "abcdef")

	mp:send_preamble("")

	mp:send_boundary()
	mp:send_headers(Headers():add("Name", "value1"))
	mp:send("hello")

	mp:send_boundary()
	mp:send_headers(Headers():add("Name", "value2"))
	mp:send("world")

	mp:send_boundary(true)
	mp:send("")

	soc:close()

	t:eq(str_soc.remainder, ([[
--abcdef
Name: value1

hello
--abcdef
Name: value2

world
--abcdef--
]]):gsub("\n", "\r\n"))

	t:tdeq({mp:receive_preamble()}, {""})

	local headers = assert(mp:receive_headers())
	t:tdeq(headers.headers, {name = {"value1"}})
	t:tdeq({mp:receive("*a")}, {"hello"})

	local headers = assert(mp:receive_headers())
	t:tdeq(headers.headers, {name = {"value2"}})
	t:tdeq({mp:receive("*a")}, {"world"})

	local headers, err = mp:receive_headers()
	t:assert(not headers)
	t:eq(err, "no parts")

	t:tdeq({mp:receive_epilogue()}, {nil, "closed", ""})
end

---@param t testing.T
function test.parse_body_starting_with_boundary(t)
	local body = ([[
--abcdef
Name: value1

hello
--abcdef--
]]):gsub("\n", "\r\n")

	local str_soc = StringSocket(body)
	str_soc:close()
	local soc = ExtendedSocket(str_soc)
	local mp = Multipart(soc, "abcdef")

	t:tdeq({mp:receive_preamble()}, {""})

	local headers = assert(mp:receive_headers())
	t:tdeq(headers.headers, {name = {"value1"}})
	t:tdeq({mp:receive("*a")}, {"hello"})

	local next_headers, err = mp:receive_headers()
	t:assert(not next_headers)
	t:eq(err, "no parts")
end

---@param t testing.T
function test.close_empty_multipart(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)
	local mp = Multipart(soc, "abcdef")

	mp:send_boundary(true)
	soc:close()

	t:eq(str_soc.remainder, "--abcdef--\r\n")
end

---@param t testing.T
function test.close_with_preamble(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)
	local mp = Multipart(soc, "abcdef")

	mp:send_preamble("preamble")
	mp:send_boundary(true)
	soc:close()

	t:eq(str_soc.remainder, "preamble\r\n--abcdef--\r\n")
end

---@param t testing.T
function test.send_headers_requires_headers(t)
	local str_soc = StringSocket()
	local soc = ExtendedSocket(str_soc)
	local mp = Multipart(soc, "abcdef")

	t:has_error(function()
		mp:send_headers() ---@diagnostic disable-line
	end)
end

---@param t testing.T
function test.string_two_parts(t)
	local boundary = "----WebKitFormBoundary1234567890"
	local body = ("--%s\r\nContent-Disposition: form-data; name=\"iv\"\r\n\r\ntest_iv\r\n--%s\r\nContent-Disposition: form-data; name=\"score\"\r\n\r\nscoredata\r\n--%s--\r\n"):format(boundary, boundary, boundary)

	local mp = MultipartString(body, boundary)

	t:eq(mp:receive_preamble(), "")

	local headers = assert(mp:receive_headers())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="iv"')
	t:eq(mp:receive("*a"), "test_iv")

	headers = assert(mp:receive_headers())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="score"')
	t:eq(mp:receive("*a"), "scoredata")

	headers = nil
	local err
	headers, err = mp:receive_headers()
	t:assert(not headers)
	t:eq(err, "no parts")

	local epilogue
	epilogue, err = mp:receive_epilogue()
	t:assert(not epilogue)
	t:eq(err, "closed")
end

---@param t testing.T
function test.string_single_part(t)
	local boundary = "boundary123"
	local body = ("--%s\r\nContent-Disposition: form-data; name=\"field1\"\r\nContent-Type: text/plain\r\n\r\nhello world\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers = assert(mp:receive_headers())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="field1"')
	t:eq(headers:get("Content-Type"), "text/plain")
	t:eq(mp:receive("*a"), "hello world")

	headers = nil
	local err
	headers, err = mp:receive_headers()
	t:assert(not headers)
	t:eq(err, "no parts")
end

---@param t testing.T
function test.string_empty_body(t)
	local boundary = "boundary123"
	local body = ("--%s\r\nContent-Disposition: form-data; name=\"empty\"\r\n\r\n\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers = assert(mp:receive_headers())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="empty"')
	t:eq(mp:receive("*a"), "")
end

---@param t testing.T
function test.string_multiple_parts_with_fields(t)
	local boundary = "----form123"
	local body = ("--%s\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n--%s\r\nContent-Disposition: form-data; name=\"b\"\r\n\r\n2\r\n--%s\r\nContent-Disposition: form-data; name=\"c\"\r\n\r\n3\r\n--%s--\r\n"):format(boundary, boundary, boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers = assert(mp:receive_headers())
	t:assert(headers:get("Content-Disposition"):match('name="a"'))
	t:eq(mp:receive("*a"), "1")

	headers = assert(mp:receive_headers())
	t:assert(headers:get("Content-Disposition"):match('name="b"'))
	t:eq(mp:receive("*a"), "2")

	headers = assert(mp:receive_headers())
	t:assert(headers:get("Content-Disposition"):match('name="c"'))
	t:eq(mp:receive("*a"), "3")

	headers = nil
	local err
	headers, err = mp:receive_headers()
	t:assert(not headers)
	t:eq(err, "no parts")
end

---@param t testing.T
function test.string_no_parts(t)
	local boundary = "boundary123"
	local body = ("--%s--\r\n"):format(boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers, err = mp:receive_headers()
	t:assert(not headers)
	t:eq(err, "no parts")
end

---@param t testing.T
function test.string_bsoc_size_limit(t)
	local boundary = "boundary123"
	local body = ("--%s\r\nContent-Disposition: form-data; name=\"data\"\r\n\r\nhello world\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()
	mp:receive_headers()
	t:eq(mp:receive(5), "hello")
end

---@param t testing.T
function test.string_preamble_with_crlf_before_boundary(t)
	local boundary = "boundary123"
	local body = ("preamble text\r\n--%s\r\nContent-Disposition: form-data; name=\"data\"\r\n\r\nhello\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	local preamble = assert(mp:receive_preamble())
	t:eq(preamble, "preamble text")

	local headers = assert(mp:receive_headers())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="data"')
	t:eq(mp:receive("*a"), "hello")
end

return test
