local MultipartString = require("web.content.MultipartString")
local ExtendedSocket = require("web.socket.ExtendedSocket")

local test = {}

function test.two_parts(t)
	local boundary = "----WebKitFormBoundary1234567890"
	local body = ("\r\n--%s\r\nContent-Disposition: form-data; name=\"iv\"\r\n\r\ntest_iv\r\n--%s\r\nContent-Disposition: form-data; name=\"score\"\r\n\r\nscoredata\r\n--%s--\r\n"):format(boundary, boundary, boundary)

	local mp = MultipartString(body, boundary)

	t:eq(mp:receive_preamble(), "")

	local headers = assert(mp:receive())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="iv"')
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "test_iv")

	local headers = assert(mp:receive())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="score"')
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "scoredata")

	local headers, err = mp:receive()
	t:assert(not headers)
	t:eq(err, "no parts")

	local epilogue, err = mp:receive_epilogue()
	t:assert(not epilogue)
	t:eq(err, "closed")
end

function test.single_part(t)
	local boundary = "boundary123"
	local body = ("\r\n--%s\r\nContent-Disposition: form-data; name=\"field1\"\r\nContent-Type: text/plain\r\n\r\nhello world\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers = assert(mp:receive())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="field1"')
	t:eq(headers:get("Content-Type"), "text/plain")
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "hello world")

	local headers, err = mp:receive()
	t:assert(not headers)
	t:eq(err, "no parts")
end

function test.empty_body(t)
	local boundary = "boundary123"
	local body = ("\r\n--%s\r\nContent-Disposition: form-data; name=\"empty\"\r\n\r\n\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers = assert(mp:receive())
	t:eq(headers:get("Content-Disposition"), 'form-data; name="empty"')
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "")
end

function test.multiple_parts_with_fields(t)
	local boundary = "----form123"
	local body = ("\r\n--%s\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n--%s\r\nContent-Disposition: form-data; name=\"b\"\r\n\r\n2\r\n--%s\r\nContent-Disposition: form-data; name=\"c\"\r\n\r\n3\r\n--%s--\r\n"):format(boundary, boundary, boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers = assert(mp:receive())
	t:assert(headers:get("Content-Disposition"):match('name="a"'))
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "1")

	headers = assert(mp:receive())
	t:assert(headers:get("Content-Disposition"):match('name="b"'))
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "2")

	headers = assert(mp:receive())
	t:assert(headers:get("Content-Disposition"):match('name="c"'))
	t:eq(ExtendedSocket(mp.bsoc):receive("*a"), "3")

	local headers, err = mp:receive()
	t:assert(not headers)
	t:eq(err, "no parts")
end

function test.no_parts(t)
	local boundary = "boundary123"
	local body = ("\r\n--%s--\r\n"):format(boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()

	local headers, err = mp:receive()
	t:assert(not headers)
	t:eq(err, "no parts")
end

function test.bsoc_size_limit(t)
	local boundary = "boundary123"
	local body = ("\r\n--%s\r\nContent-Disposition: form-data; name=\"data\"\r\n\r\nhello world\r\n--%s--\r\n"):format(boundary, boundary)

	local mp = MultipartString(body, boundary)
	mp:receive_preamble()
	mp:receive()
	t:eq(ExtendedSocket(mp.bsoc):receive(5), "hello")
end

return test
