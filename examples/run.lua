local needle = require("needle")

print("runtime:", needle.version())
print("ffi probe:", needle.probe_add(20, 22))

local model_path = arg[1] or "needle.bin"
local ctx, err = needle.load(model_path)
if err then
  io.stderr:write(("load warning [%s]: %s\n"):format(err.name, err.message))
end

if ctx then
  local info = ctx:info()
  print("loaded:", info.loaded)
  print("tensors:", info.tensor_count)
  print("tensor bytes:", info.tensor_data_bytes)
  print("tokenizer bytes:", info.tokenizer_bytes)

  local result, gen_err = ctx:generate("weather in Paris", "[]", {
    tokenizer_path = "build/tokenizer.ndltok",
    max_new_tokens = 4,
  })
  if not result then
    io.stderr:write(("generate warning [%s]: %s\n"):format(gen_err.name, gen_err.message))
  else
    print(result)
  end
  ctx:close()
end
