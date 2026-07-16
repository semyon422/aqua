local needle = require("needle")

local fixture = arg[1]
assert(fixture and fixture ~= "", "fixture path required")

collectgarbage("collect")
needle.reset_memory_stats()
local baseline = needle.memory_stats()

local ctx = assert(needle.load(fixture))
assert(ctx:embedding(0))
assert(ctx:encode_tokens({ 0, 1 }))

local encoder = assert(ctx:encode_tokens({ 0, 1 }))
assert(ctx:decode_tokens({ 0, 1 }, encoder, 2))
assert(ctx:generate_tokens({ 0, 1 }, { 1 }, { max_new_tokens = 2 }))
assert(ctx:generate_tokens({ 0, 1 }, { 1 }, { max_new_tokens = 2, use_cache = true }))

local cache = assert(ctx:create_kv_cache(4))
assert(ctx:decode_token_cached_step(cache, 1, encoder, 2))
cache:close()
ctx:close()
collectgarbage("collect")

local after = needle.memory_stats()
assert(after.aligned_alloc_active_count == baseline.aligned_alloc_active_count,
  ("active aligned allocation leak: got %d baseline %d"):format(
    after.aligned_alloc_active_count,
    baseline.aligned_alloc_active_count
  ))
assert(after.aligned_alloc_current_bytes == baseline.aligned_alloc_current_bytes,
  ("current aligned bytes leak: got %d baseline %d"):format(
    after.aligned_alloc_current_bytes,
    baseline.aligned_alloc_current_bytes
  ))
assert(after.aligned_alloc_count > 0, "memory test should exercise aligned allocations")
assert(after.aligned_alloc_total_bytes > 0, "memory test should record allocated bytes")

print("test_memory_stats.lua: ok")
