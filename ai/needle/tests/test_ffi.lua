local needle = require("needle")

assert(needle.version():match("^needle%-luajit%-runtime/"), "unexpected runtime version")
assert(needle.probe_add(20, 22) == 42, "C probe did not return expected result")

local ctx, err = needle.load("missing-model.bin")
assert(ctx ~= nil, "loader should return a context for structured errors")
assert(err and err.code == needle.errors.IO, "expected IO error")
assert(err.message:match("could not open model file"), "expected missing model error")
assert(ctx:last_error_info().name == "IO", "expected named IO error")
ctx:close()

local ok, closed_err = pcall(function()
  return ctx:info()
end)
assert(not ok and tostring(closed_err):match("needle context is closed"), "closed context should fail clearly")

print("test_ffi.lua: ok")
