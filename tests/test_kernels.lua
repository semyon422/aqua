local needle = require("needle")

local function approx(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-5)
end

local function assert_vec(actual, expected, eps, label)
  assert(#actual == #expected, label .. " length mismatch")
  for i = 1, #expected do
    assert(approx(actual[i], expected[i], eps), ("%s mismatch at %d: %.9g vs %.9g"):format(label, i, actual[i], expected[i]))
  end
end

local x = {
  1.0, 2.0, 3.0, 4.0,
  -1.0, 0.0, 1.0, 2.0,
}
local scale = { 0.0, 0.5, -0.25, 1.0 }
local out = assert(needle.kernels.zcrmsnorm(x, scale, 2, 4, 1e-6))

for row = 0, 1 do
  local sumsq = 0.0
  for col = 1, 4 do
    local v = x[row * 4 + col]
    sumsq = sumsq + v * v
  end
  local inv_rms = 1.0 / math.sqrt(sumsq / 4.0 + 1e-6)
  for col = 1, 4 do
    local expected = (1.0 + scale[col]) * x[row * 4 + col] * inv_rms
    assert(approx(out[row * 4 + col], expected, 1e-5), "zcrmsnorm mismatch")
  end
end

local rope_in = {
  1.0, 2.0, 3.0, 4.0,
  5.0, 6.0, 7.0, 8.0,
}
local rope = assert(needle.kernels.rope(rope_in, 1, 2, 4, 10000.0))

for i = 1, 4 do
  assert(approx(rope[i], rope_in[i], 1e-6), "rope position 0 should be unchanged")
end

local cos0 = math.cos(1.0)
local sin0 = math.sin(1.0)
local freq1 = 1.0 / math.pow(10000.0, 2.0 / 4.0)
local cos1 = math.cos(freq1)
local sin1 = math.sin(freq1)
local expected = {
  5.0 * cos0 - 7.0 * sin0,
  6.0 * cos1 - 8.0 * sin1,
  7.0 * cos0 + 5.0 * sin0,
  8.0 * cos1 + 6.0 * sin1,
}
for i = 1, 4 do
  assert(approx(rope[4 + i], expected[i], 1e-5), "rope position 1 mismatch")
end

local mm = assert(needle.kernels.matmul(
  {
    1, 2, 3,
    4, 5, 6,
  },
  {
    7, 8,
    9, 10,
    11, 12,
  },
  2, 3, 2,
  { 0.5, -0.5 }
))
assert_vec(mm, {
  58.5, 63.5,
  139.5, 153.5,
}, 1e-5, "matmul")

local sm = assert(needle.kernels.softmax(
  {
    1, 2, 3,
    2, 4, 8,
  },
  2, 3,
  {
    1, 1, 1,
    1, 0, 1,
  }
))
do
  local e1, e2, e3 = math.exp(-2), math.exp(-1), 1
  local z = e1 + e2 + e3
  local y1 = { e1 / z, e2 / z, e3 / z }
  local a, b = math.exp(2 - 8), 1
  local z2 = a + b
  assert_vec(sm, { y1[1], y1[2], y1[3], a / z2, 0, b / z2 }, 1e-5, "softmax")
end

local q = {
  1, 0,
  0, 1,
}
local k = {
  1, 0,
  0, 1,
  1, 1,
}
local v = {
  10, 0,
  0, 20,
  30, 40,
}
local attn = assert(needle.kernels.attention(q, k, v, 2, 3, 2, {
  1, 1, 1,
  1, 0, 1,
}))

local function attention_expected(qrow, mask)
  local scores = {}
  local max_score = -math.huge
  for i = 0, 2 do
    if mask[i + 1] then
      local dot = qrow[1] * k[i * 2 + 1] + qrow[2] * k[i * 2 + 2]
      scores[i + 1] = dot / math.sqrt(2)
      max_score = math.max(max_score, scores[i + 1])
    else
      scores[i + 1] = nil
    end
  end
  local denom = 0
  local weights = {}
  for i = 1, 3 do
    if scores[i] then
      weights[i] = math.exp(scores[i] - max_score)
      denom = denom + weights[i]
    else
      weights[i] = 0
    end
  end
  local out0, out1 = 0, 0
  for i = 0, 2 do
    local w = weights[i + 1] / denom
    out0 = out0 + w * v[i * 2 + 1]
    out1 = out1 + w * v[i * 2 + 2]
  end
  return out0, out1
end

local a0, a1 = attention_expected({ 1, 0 }, { true, true, true })
local b0, b1 = attention_expected({ 0, 1 }, { true, false, true })
assert_vec(attn, { a0, a1, b0, b1 }, 1e-5, "attention")

print("test_kernels.lua: ok")
