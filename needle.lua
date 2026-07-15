local ffi = require("ffi")

ffi.cdef[[
typedef struct needle_ctx needle_ctx;
typedef struct needle_kv_cache needle_kv_cache;
typedef struct needle_encoder_state needle_encoder_state;
typedef struct needle_tokenizer needle_tokenizer;
typedef int (*needle_token_callback)(
  int token_id,
  int step,
  const int *tokens,
  int token_count,
  void *user_data
);
typedef int (*needle_token_filter_callback)(
  int step,
  const int *tokens,
  int token_count,
  const float *logits,
  int vocab_size,
  int *allowed_ids,
  int allowed_cap,
  void *user_data
);
typedef struct {
  int vocab_size;
  int d_model;
  int num_heads;
  int num_kv_heads;
  int num_encoder_layers;
  int num_decoder_layers;
  int d_ff;
  int max_seq_len;
  int pad_token_id;
  float rope_theta;
  int num_memory_slots;
  float dropout_rate;
  int contrastive_dim;
  int no_feedforward;
  int enable_speech;
  char dtype[16];
  char activation[16];
} needle_config;

int needle_abi_version(void);
const char *needle_version(void);
int needle_probe_add(int a, int b);
void needle_runtime_reset_memory_stats(void);
unsigned long long needle_runtime_aligned_alloc_count(void);
unsigned long long needle_runtime_aligned_alloc_total_bytes(void);
unsigned long long needle_runtime_aligned_alloc_active_count(void);
unsigned long long needle_runtime_aligned_alloc_current_bytes(void);
unsigned long long needle_runtime_aligned_alloc_peak_bytes(void);
unsigned long long needle_runtime_dense_q8_projection_count(void);
unsigned long long needle_runtime_dense_float_projection_count(void);
unsigned long long needle_runtime_dense_q8_fallback_count(void);
unsigned long long needle_runtime_output_q8_projection_count(void);
unsigned long long needle_runtime_output_float_projection_count(void);
unsigned long long needle_runtime_output_q8_fallback_count(void);

needle_ctx *needle_load(const char *model_path);
void needle_free(needle_ctx *ctx);
const char *needle_last_error(needle_ctx *ctx);
int needle_last_error_code(needle_ctx *ctx);
void needle_clear_error(needle_ctx *ctx);
int needle_is_loaded(needle_ctx *ctx);
unsigned long long needle_tensor_count(needle_ctx *ctx);
unsigned long long needle_tensor_data_bytes(needle_ctx *ctx);
unsigned long long needle_tokenizer_bytes(needle_ctx *ctx);
const char *needle_metadata_json(needle_ctx *ctx);
const needle_config *needle_get_config(needle_ctx *ctx);
const char *needle_tensor_name(needle_ctx *ctx, unsigned long long index);
int needle_tensor_dtype(needle_ctx *ctx, unsigned long long index);
int needle_tensor_ndim(needle_ctx *ctx, unsigned long long index);
unsigned long long needle_tensor_dim(needle_ctx *ctx, unsigned long long index, int dim);
unsigned long long needle_tensor_nbytes(needle_ctx *ctx, unsigned long long index);
long long needle_find_tensor(needle_ctx *ctx, const char *name);
int needle_embedding_lookup(needle_ctx *ctx, int token_id, float *out, int out_cap);
int needle_encoder_self_attention_f32(
  needle_ctx *ctx,
  int layer,
  const float *x,
  int seq_len,
  float *out,
  int out_cap
);
int needle_encoder_block_f32(
  needle_ctx *ctx,
  int layer,
  const float *x,
  int seq_len,
  float *out,
  int out_cap
);
int needle_output_projection_f32(
  needle_ctx *ctx,
  const float *x,
  int seq_len,
  float *out,
  int out_cap
);
int needle_encode_tokens_f32(
  needle_ctx *ctx,
  const int *token_ids,
  int seq_len,
  float *out,
  int out_cap
);
int needle_decoder_self_attention_f32(
  needle_ctx *ctx,
  int layer,
  const float *x,
  int seq_len,
  int causal,
  float *out,
  int out_cap
);
int needle_decoder_self_attention_cached_step_f32(
  needle_ctx *ctx,
  needle_kv_cache *cache,
  int layer,
  const float *x,
  float *out,
  int out_cap
);
int needle_decoder_cross_attention_f32(
  needle_ctx *ctx,
  int layer,
  const float *x,
  int seq_len,
  const float *encoder_out,
  int enc_len,
  float *out,
  int out_cap
);
int needle_decoder_block_f32(
  needle_ctx *ctx,
  int layer,
  const float *x,
  int seq_len,
  const float *encoder_out,
  int enc_len,
  float *out,
  int out_cap
);
int needle_decoder_block_cached_step_f32(
  needle_ctx *ctx,
  needle_kv_cache *cache,
  int layer,
  const float *x,
  const float *encoder_out,
  int enc_len,
  float *out,
  int out_cap
);
int needle_decode_tokens_f32(
  needle_ctx *ctx,
  const int *token_ids,
  int seq_len,
  const float *encoder_out,
  int enc_len,
  float *out,
  int out_cap
);
int needle_decode_token_cached_step_f32(
  needle_ctx *ctx,
  needle_kv_cache *cache,
  int token_id,
  const float *encoder_out,
  int enc_len,
  float *out,
  int out_cap
);
int needle_forward_logits_f32(
  needle_ctx *ctx,
  const int *src_ids,
  int src_len,
  const int *tgt_ids,
  int tgt_len,
  float *out,
  int out_cap
);
needle_encoder_state *needle_encoder_state_create(needle_ctx *ctx, const int *src_ids, int src_len);
void needle_encoder_state_free(needle_encoder_state *state);
int needle_encoder_state_len(needle_encoder_state *state);
int needle_encoder_state_d_model(needle_encoder_state *state);
needle_kv_cache *needle_kv_cache_create(needle_ctx *ctx, int max_tokens);
void needle_kv_cache_free(needle_kv_cache *cache);
int needle_kv_cache_reset(needle_kv_cache *cache);
int needle_kv_cache_set_token_count(needle_kv_cache *cache, int token_count);
int needle_kv_cache_token_count(needle_kv_cache *cache);
int needle_kv_cache_max_tokens(needle_kv_cache *cache);
int needle_kv_cache_layer_count(needle_kv_cache *cache);
int needle_kv_cache_kv_heads(needle_kv_cache *cache);
int needle_kv_cache_head_dim(needle_kv_cache *cache);
unsigned long long needle_kv_cache_bytes(needle_kv_cache *cache);
int needle_generate_tokens_greedy(
  needle_ctx *ctx,
  const int *src_ids,
  int src_len,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  int *out_ids,
  int out_cap
);
int needle_generate_tokens_greedy_filtered(
  needle_ctx *ctx,
  const int *src_ids,
  int src_len,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  needle_token_filter_callback filter,
  void *user_data,
  int *out_ids,
  int out_cap
);
int needle_generate_tokens_greedy_cached(
  needle_ctx *ctx,
  const int *src_ids,
  int src_len,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  int *out_ids,
  int out_cap
);
int needle_generate_tokens_greedy_cached_filtered(
  needle_ctx *ctx,
  const int *src_ids,
  int src_len,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  needle_token_filter_callback filter,
  void *user_data,
  int *out_ids,
  int out_cap
);
int needle_generate_tokens_greedy_cached_from_encoder_filtered(
  needle_ctx *ctx,
  const float *encoder_out,
  int enc_len,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  needle_token_filter_callback filter,
  void *user_data,
  int *out_ids,
  int out_cap
);
int needle_generate_tokens_greedy_cached_from_state_filtered(
  needle_ctx *ctx,
  needle_encoder_state *state,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  needle_token_filter_callback filter,
  void *user_data,
  int *out_ids,
  int out_cap
);
int needle_generate_tokens_greedy_cached_from_state_stream_filtered(
  needle_ctx *ctx,
  needle_encoder_state *state,
  const int *prompt_ids,
  int prompt_len,
  int max_new_tokens,
  int eos_token_id,
  needle_token_filter_callback filter,
  void *filter_user_data,
  needle_token_callback token_callback,
  void *token_user_data,
  int *out_ids,
  int out_cap
);

int needle_generate(
  needle_ctx *ctx,
  const char *query,
  const char *tools_json,
  char *out,
  int out_cap
);

typedef int (*needle_stream_callback)(const char *chunk, int chunk_len, void *user_data);
int needle_generate_stream(
  needle_ctx *ctx,
  const char *query,
  const char *tools_json,
  needle_stream_callback callback,
  void *user_data
);

needle_tokenizer *needle_tokenizer_load(const char *path);
void needle_tokenizer_free(needle_tokenizer *tok);
const char *needle_tokenizer_last_error(needle_tokenizer *tok);
int needle_tokenizer_last_error_code(needle_tokenizer *tok);
unsigned int needle_tokenizer_vocab_size(needle_tokenizer *tok);
int needle_tokenizer_encode(needle_tokenizer *tok, const char *text, int *out_ids, int out_cap);
int needle_tokenizer_decode(needle_tokenizer *tok, const int *ids, int count, char *out, int out_cap);
int needle_tokenizer_token_text(needle_tokenizer *tok, int id, char *out, int out_cap);

int needle_kernel_zcrmsnorm_f32(
  const float *x,
  const float *scale,
  float *out,
  int rows,
  int cols,
  float epsilon
);

int needle_kernel_rope_f32(
  const float *x,
  float *out,
  int num_heads,
  int seq_len,
  int head_dim,
  float theta,
  int rope_keys_only
);

int needle_kernel_matmul_f32(
  const float *a,
  const float *b,
  const float *bias,
  float *out,
  int m,
  int k,
  int n
);

int needle_kernel_softmax_f32(
  const float *x,
  const unsigned char *mask,
  float *out,
  int rows,
  int cols
);

int needle_kernel_attention_f32(
  const float *q,
  const float *k,
  const float *v,
  const unsigned char *mask,
  float *out,
  int q_len,
  int kv_len,
  int head_dim
);
]]

local M = {}
M.abi_version = 4
M.errors = {
  OK = 0,
  NULL_CONTEXT = -1,
  INVALID_ARGUMENT = -2,
  NOT_LOADED = -3,
  IO = -4,
  FORMAT = -5,
  UNSUPPORTED = -6,
  OUT_OF_MEMORY = -7,
  NOT_IMPLEMENTED = -8,
}
M.dtypes = {
  F32 = 1,
  F16 = 2,
  BF16 = 3,
  I8 = 4,
  I32 = 5,
  U8 = 6,
}

local dtype_names = {
  [M.dtypes.F32] = "f32",
  [M.dtypes.F16] = "f16",
  [M.dtypes.BF16] = "bf16",
  [M.dtypes.I8] = "i8",
  [M.dtypes.I32] = "i32",
  [M.dtypes.U8] = "u8",
}

local error_names = {}
for name, code in pairs(M.errors) do
  error_names[code] = name
end

local default_lib_name = package.config:sub(1, 1) == "\\" and "needle_runtime" or "./build/libneedle_runtime.so"

local lib

local function load_lib(path)
  if lib then
    return lib
  end
  lib = ffi.load(path or os.getenv("NEEDLE_RUNTIME_LIB") or default_lib_name)
  local abi = tonumber(lib.needle_abi_version())
  if abi ~= M.abi_version then
    error(("needle runtime ABI mismatch: got %d, want %d"):format(abi, M.abi_version), 2)
  end
  return lib
end

function M.reset_memory_stats()
  load_lib().needle_runtime_reset_memory_stats()
end

function M.memory_stats()
  local runtime = load_lib()
  return {
    aligned_alloc_count = tonumber(runtime.needle_runtime_aligned_alloc_count()),
    aligned_alloc_total_bytes = tonumber(runtime.needle_runtime_aligned_alloc_total_bytes()),
    aligned_alloc_active_count = tonumber(runtime.needle_runtime_aligned_alloc_active_count()),
    aligned_alloc_current_bytes = tonumber(runtime.needle_runtime_aligned_alloc_current_bytes()),
    aligned_alloc_peak_bytes = tonumber(runtime.needle_runtime_aligned_alloc_peak_bytes()),
    dense_q8_projection_count = tonumber(runtime.needle_runtime_dense_q8_projection_count()),
    dense_float_projection_count = tonumber(runtime.needle_runtime_dense_float_projection_count()),
    dense_q8_fallback_count = tonumber(runtime.needle_runtime_dense_q8_fallback_count()),
    output_q8_projection_count = tonumber(runtime.needle_runtime_output_q8_projection_count()),
    output_float_projection_count = tonumber(runtime.needle_runtime_output_float_projection_count()),
    output_q8_fallback_count = tonumber(runtime.needle_runtime_output_q8_fallback_count()),
  }
end

local Context = {}
Context.__index = Context

local EncoderState = {}
EncoderState.__index = EncoderState
local ensure_encoder_state_open

local KVCache = {}
KVCache.__index = KVCache
local ensure_cache_open

local Tokenizer = {}
Tokenizer.__index = Tokenizer

local function ensure_open(self)
  if self._ctx == nil then
    error("needle context is closed", 2)
  end
end

local function error_table(code, message)
  return {
    code = tonumber(code),
    name = error_names[tonumber(code)] or "UNKNOWN",
    message = message or "",
  }
end

local function context_error(self, rc)
  local runtime = load_lib()
  local code = rc or runtime.needle_last_error_code(self._ctx)
  local msg = runtime.needle_last_error(self._ctx)
  return error_table(code, msg ~= nil and ffi.string(msg) or nil)
end

function Context:last_error()
  ensure_open(self)
  local msg = load_lib().needle_last_error(self._ctx)
  if msg == nil then
    return nil
  end
  return ffi.string(msg)
end

function Context:last_error_info()
  ensure_open(self)
  return context_error(self)
end

function Context:clear_error()
  ensure_open(self)
  load_lib().needle_clear_error(self._ctx)
end

function Context:generate_stream(query, tools_json, callback, opts)
  ensure_open(self)
  if type(callback) ~= "function" then
    return nil, error_table(M.errors.INVALID_ARGUMENT, "stream callback must be a function"), M.errors.INVALID_ARGUMENT
  end
  opts = opts or {}
  local gen_opts = {}
  for k, v in pairs(opts) do
    gen_opts[k] = v
  end
  gen_opts.on_text = callback
  return self:generate(query, tools_json, gen_opts)
end

function Context:is_loaded()
  ensure_open(self)
  return load_lib().needle_is_loaded(self._ctx) ~= 0
end

function Context:assert_loaded()
  ensure_open(self)
  if not self:is_loaded() then
    local err = self:last_error_info()
    error(("needle model is not loaded: %s"):format(err.message), 2)
  end
  return true
end

function Context:info()
  ensure_open(self)
  local runtime = load_lib()
  local metadata = runtime.needle_metadata_json(self._ctx)
  return {
    loaded = runtime.needle_is_loaded(self._ctx) ~= 0,
    tensor_count = tonumber(runtime.needle_tensor_count(self._ctx)),
    tensor_data_bytes = tonumber(runtime.needle_tensor_data_bytes(self._ctx)),
    tokenizer_bytes = tonumber(runtime.needle_tokenizer_bytes(self._ctx)),
    metadata_json = metadata ~= nil and ffi.string(metadata) or "",
  }
end

function Context:config()
  ensure_open(self)
  local cfg = load_lib().needle_get_config(self._ctx)
  if cfg == nil then
    return nil
  end
  return {
    vocab_size = tonumber(cfg.vocab_size),
    d_model = tonumber(cfg.d_model),
    num_heads = tonumber(cfg.num_heads),
    num_kv_heads = tonumber(cfg.num_kv_heads),
    num_encoder_layers = tonumber(cfg.num_encoder_layers),
    num_decoder_layers = tonumber(cfg.num_decoder_layers),
    d_ff = tonumber(cfg.d_ff),
    max_seq_len = tonumber(cfg.max_seq_len),
    pad_token_id = tonumber(cfg.pad_token_id),
    rope_theta = tonumber(cfg.rope_theta),
    num_memory_slots = tonumber(cfg.num_memory_slots),
    dropout_rate = tonumber(cfg.dropout_rate),
    contrastive_dim = tonumber(cfg.contrastive_dim),
    no_feedforward = cfg.no_feedforward ~= 0,
    enable_speech = cfg.enable_speech ~= 0,
    dtype = ffi.string(cfg.dtype),
    activation = ffi.string(cfg.activation),
  }
end

function Context:tensor(index)
  ensure_open(self)
  local runtime = load_lib()
  local zero_index = index - 1
  local name = runtime.needle_tensor_name(self._ctx, zero_index)
  if name == nil or ffi.string(name) == "" then
    return nil
  end
  local ndim = tonumber(runtime.needle_tensor_ndim(self._ctx, zero_index))
  local shape = {}
  for dim = 0, ndim - 1 do
    shape[#shape + 1] = tonumber(runtime.needle_tensor_dim(self._ctx, zero_index, dim))
  end
  local dtype = tonumber(runtime.needle_tensor_dtype(self._ctx, zero_index))
  return {
    index = index,
    name = ffi.string(name),
    dtype = dtype,
    dtype_name = dtype_names[dtype] or "unknown",
    shape = shape,
    nbytes = tonumber(runtime.needle_tensor_nbytes(self._ctx, zero_index)),
  }
end

function Context:find_tensor(name)
  ensure_open(self)
  local index = tonumber(load_lib().needle_find_tensor(self._ctx, name or ""))
  if index < 0 then
    return nil
  end
  return index + 1
end

function Context:embedding(token_id, opts)
  ensure_open(self)
  opts = opts or {}
  local cap = opts.cap or 8192
  local out = ffi.new("float[?]", cap)
  local n = load_lib().needle_embedding_lookup(self._ctx, token_id, out, cap)
  if n < 0 then
    return nil, context_error(self, n), n
  end
  local values = {}
  for i = 0, n - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:encoder_self_attention(layer, x, seq_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local n = seq_len * d_model
  local cx = ffi.new("float[?]", n)
  local out = ffi.new("float[?]", n)
  for i = 1, n do
    cx[i - 1] = x[i] or 0
  end
  local rc = load_lib().needle_encoder_self_attention_f32(self._ctx, layer or 0, cx, seq_len, out, n)
  if rc ~= 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, n - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:encoder_block(layer, x, seq_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local n = seq_len * d_model
  local cx = ffi.new("float[?]", n)
  local out = ffi.new("float[?]", n)
  for i = 1, n do
    cx[i - 1] = x[i] or 0
  end
  local rc = load_lib().needle_encoder_block_f32(self._ctx, layer or 0, cx, seq_len, out, n)
  if rc ~= 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, n - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:output_projection(x, seq_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local vocab_size = opts.vocab_size or cfg.vocab_size
  local in_n = seq_len * d_model
  local out_n = seq_len * vocab_size
  local cx = ffi.new("float[?]", in_n)
  local out = ffi.new("float[?]", out_n)
  for i = 1, in_n do
    cx[i - 1] = x[i] or 0
  end
  local rc = load_lib().needle_output_projection_f32(self._ctx, cx, seq_len, out, out_n)
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, out_n - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:encode_tokens(token_ids, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local seq_len = #token_ids
  local d_model = opts.d_model or cfg.d_model
  local ids = ffi.new("int[?]", seq_len)
  local out = ffi.new("float[?]", seq_len * d_model)
  for i = 1, seq_len do
    ids[i - 1] = token_ids[i]
  end
  local rc = load_lib().needle_encode_tokens_f32(self._ctx, ids, seq_len, out, seq_len * d_model)
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, seq_len * d_model - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:decoder_self_attention(layer, x, seq_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local n = seq_len * d_model
  local cx = ffi.new("float[?]", n)
  local out = ffi.new("float[?]", n)
  for i = 1, n do
    cx[i - 1] = x[i] or 0
  end
  local causal = opts.causal == false and 0 or 1
  local rc = load_lib().needle_decoder_self_attention_f32(self._ctx, layer or 0, cx, seq_len, causal, out, n)
  if rc ~= 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, n - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:decoder_self_attention_cached_step(cache, layer, x, opts)
  ensure_open(self)
  ensure_cache_open(cache)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local cx = ffi.new("float[?]", d_model)
  local out = ffi.new("float[?]", d_model)
  for i = 1, d_model do
    cx[i - 1] = x[i] or 0
  end
  local rc = load_lib().needle_decoder_self_attention_cached_step_f32(self._ctx, cache._cache, layer or 0, cx, out, d_model)
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, rc - 1 do
    values[#values + 1] = tonumber(out[i])
  end
  return values
end

function Context:decoder_cross_attention(layer, x, seq_len, encoder_out, enc_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local n = seq_len * d_model
  local enc_n = enc_len * d_model
  local cx = ffi.new("float[?]", n)
  local cenc = ffi.new("float[?]", enc_n)
  local out = ffi.new("float[?]", n)
  for i = 1, n do cx[i - 1] = x[i] or 0 end
  for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
  local rc = load_lib().needle_decoder_cross_attention_f32(self._ctx, layer or 0, cx, seq_len, cenc, enc_len, out, n)
  if rc ~= 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, n - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function Context:decoder_block(layer, x, seq_len, encoder_out, enc_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local n = seq_len * d_model
  local enc_n = enc_len * d_model
  local cx = ffi.new("float[?]", n)
  local cenc = ffi.new("float[?]", enc_n)
  local out = ffi.new("float[?]", n)
  for i = 1, n do cx[i - 1] = x[i] or 0 end
  for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
  local rc = load_lib().needle_decoder_block_f32(self._ctx, layer or 0, cx, seq_len, cenc, enc_len, out, n)
  if rc ~= 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, n - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function Context:decoder_block_cached_step(cache, layer, x, encoder_out, enc_len, opts)
  ensure_open(self)
  ensure_cache_open(cache)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local enc_n = enc_len * d_model
  local cx = ffi.new("float[?]", d_model)
  local cenc = ffi.new("float[?]", enc_n)
  local out = ffi.new("float[?]", d_model)
  for i = 1, d_model do cx[i - 1] = x[i] or 0 end
  for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
  local rc = load_lib().needle_decoder_block_cached_step_f32(
    self._ctx, cache._cache, layer or 0, cx, cenc, enc_len, out, d_model
  )
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, rc - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function Context:decode_tokens(token_ids, encoder_out, enc_len, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local seq_len = #token_ids
  local d_model = opts.d_model or cfg.d_model
  local ids = ffi.new("int[?]", seq_len)
  local enc_n = enc_len * d_model
  local cenc = ffi.new("float[?]", enc_n)
  local out = ffi.new("float[?]", seq_len * d_model)
  for i = 1, seq_len do ids[i - 1] = token_ids[i] end
  for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
  local rc = load_lib().needle_decode_tokens_f32(self._ctx, ids, seq_len, cenc, enc_len, out, seq_len * d_model)
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, seq_len * d_model - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function Context:decode_token_cached_step(cache, token_id, encoder_out, enc_len, opts)
  ensure_open(self)
  ensure_cache_open(cache)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = opts.d_model or cfg.d_model
  local enc_n = enc_len * d_model
  local cenc = ffi.new("float[?]", enc_n)
  local out = ffi.new("float[?]", d_model)
  for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
  local rc = load_lib().needle_decode_token_cached_step_f32(self._ctx, cache._cache, token_id, cenc, enc_len, out, d_model)
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, rc - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function Context:forward_logits(src_ids, tgt_ids, opts)
  ensure_open(self)
  opts = opts or {}
  local cfg = assert(self:config(), "model config is unavailable")
  local src_len = #src_ids
  local tgt_len = #tgt_ids
  local vocab_size = opts.vocab_size or cfg.vocab_size
  local csrc = ffi.new("int[?]", src_len)
  local ctgt = ffi.new("int[?]", tgt_len)
  local out = ffi.new("float[?]", tgt_len * vocab_size)
  for i = 1, src_len do csrc[i - 1] = src_ids[i] end
  for i = 1, tgt_len do ctgt[i - 1] = tgt_ids[i] end
  local rc = load_lib().needle_forward_logits_f32(self._ctx, csrc, src_len, ctgt, tgt_len, out, tgt_len * vocab_size)
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  local values = {}
  for i = 0, tgt_len * vocab_size - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function ensure_encoder_state_open(self)
  if self._state == nil then
    error("needle encoder state is closed", 2)
  end
end

function Context:encode_tokens_state(token_ids)
  ensure_open(self)
  local seq_len = #token_ids
  local ids = ffi.new("int[?]", seq_len)
  for i = 1, seq_len do ids[i - 1] = token_ids[i] end
  local state = load_lib().needle_encoder_state_create(self._ctx, ids, seq_len)
  if state == nil then
    return nil, context_error(self)
  end
  return setmetatable({ _state = state }, EncoderState)
end

function EncoderState:info()
  ensure_encoder_state_open(self)
  local runtime = load_lib()
  local enc_len = tonumber(runtime.needle_encoder_state_len(self._state))
  local d_model = tonumber(runtime.needle_encoder_state_d_model(self._state))
  return {
    enc_len = enc_len,
    d_model = d_model,
    values = enc_len * d_model,
    bytes = enc_len * d_model * 4,
  }
end

function EncoderState:close()
  if self._state ~= nil then
    load_lib().needle_encoder_state_free(self._state)
    self._state = nil
  end
end

function EncoderState:__gc()
  self:close()
end

function ensure_cache_open(self)
  if self._cache == nil then
    error("needle KV cache is closed", 2)
  end
end

function Context:create_kv_cache(max_tokens)
  ensure_open(self)
  max_tokens = max_tokens or (self:config() and self:config().max_seq_len) or 0
  local cache = load_lib().needle_kv_cache_create(self._ctx, max_tokens)
  if cache == nil then
    return nil, context_error(self)
  end
  return setmetatable({ _cache = cache }, KVCache)
end

function KVCache:info()
  ensure_cache_open(self)
  local runtime = load_lib()
  return {
    token_count = tonumber(runtime.needle_kv_cache_token_count(self._cache)),
    max_tokens = tonumber(runtime.needle_kv_cache_max_tokens(self._cache)),
    layers = tonumber(runtime.needle_kv_cache_layer_count(self._cache)),
    kv_heads = tonumber(runtime.needle_kv_cache_kv_heads(self._cache)),
    head_dim = tonumber(runtime.needle_kv_cache_head_dim(self._cache)),
    bytes = tonumber(runtime.needle_kv_cache_bytes(self._cache)),
  }
end

function KVCache:reset()
  ensure_cache_open(self)
  local rc = load_lib().needle_kv_cache_reset(self._cache)
  if rc ~= 0 then
    return nil, error_table(rc, "KV cache reset failed"), rc
  end
  return true
end

function KVCache:set_token_count(token_count)
  ensure_cache_open(self)
  local rc = load_lib().needle_kv_cache_set_token_count(self._cache, token_count)
  if rc ~= 0 then
    return nil, error_table(rc, "invalid KV cache token count"), rc
  end
  return true
end

function KVCache:close()
  if self._cache ~= nil then
    load_lib().needle_kv_cache_free(self._cache)
    self._cache = nil
  end
end

function KVCache:__gc()
  self:close()
end

local function make_token_filter_callback(opts)
  if opts.allowed_token_ids_by_step == nil and opts.token_filter == nil and opts.token_filter_raw == nil then
    return nil
  end
  return ffi.cast("needle_token_filter_callback", function(step, tokens, token_count, logits, vocab_size, allowed_ids, allowed_cap, _)
    local step_index = tonumber(step) + 1
    local allowed = opts.allowed_token_ids_by_step and opts.allowed_token_ids_by_step[step_index] or nil
    if opts.token_filter_raw ~= nil then
      local ok, filtered = pcall(opts.token_filter_raw, step_index, tokens, tonumber(token_count), logits, tonumber(vocab_size))
      if not ok then
        return -1
      end
      if filtered ~= nil then
        allowed = filtered
      end
    end
    if opts.token_filter ~= nil then
      local lua_tokens = {}
      for i = 0, tonumber(token_count) - 1 do
        lua_tokens[#lua_tokens + 1] = tonumber(tokens[i])
      end
      local ok, filtered = pcall(opts.token_filter, step_index, lua_tokens, logits, tonumber(vocab_size))
      if not ok then
        return -1
      end
      if filtered ~= nil then
        allowed = filtered
      end
    end
    if allowed == nil then
      return 0
    end
    local n = #allowed
    if n <= 0 or n > tonumber(allowed_cap) then
      return -1
    end
    for i = 1, n do
      allowed_ids[i - 1] = allowed[i]
    end
    return n
  end)
end

local function read_int_output(out, n)
  local values = {}
  for i = 0, n - 1 do values[#values + 1] = tonumber(out[i]) end
  return values
end

function Context:generate_tokens(src_ids, prompt_ids, opts)
  ensure_open(self)
  opts = opts or {}
  local max_new_tokens = opts.max_new_tokens or 16
  local eos_token_id = opts.eos_token_id or 1
  local src_len = #src_ids
  local prompt_len = #prompt_ids
  local csrc = ffi.new("int[?]", src_len)
  local cprompt = ffi.new("int[?]", prompt_len)
  local out_cap = prompt_len + max_new_tokens
  local out = ffi.new("int[?]", out_cap)
  for i = 1, src_len do csrc[i - 1] = src_ids[i] end
  for i = 1, prompt_len do cprompt[i - 1] = prompt_ids[i] end
  local runtime = load_lib()
  local cb = make_token_filter_callback(opts)
  local rc
  if cb ~= nil then
    if opts.use_cache then
      rc = runtime.needle_generate_tokens_greedy_cached_filtered(
        self._ctx, csrc, src_len, cprompt, prompt_len, max_new_tokens, eos_token_id, cb, nil, out, out_cap
      )
    else
      rc = runtime.needle_generate_tokens_greedy_filtered(
        self._ctx, csrc, src_len, cprompt, prompt_len, max_new_tokens, eos_token_id, cb, nil, out, out_cap
      )
    end
    cb:free()
  else
    if opts.use_cache then
      rc = runtime.needle_generate_tokens_greedy_cached(
        self._ctx, csrc, src_len, cprompt, prompt_len, max_new_tokens, eos_token_id, out, out_cap
      )
    else
      rc = runtime.needle_generate_tokens_greedy(
        self._ctx, csrc, src_len, cprompt, prompt_len, max_new_tokens, eos_token_id, out, out_cap
      )
    end
  end
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  return read_int_output(out, rc)
end

function Context:generate_tokens_from_encoder(encoder_out, enc_len, prompt_ids, opts)
  ensure_open(self)
  opts = opts or {}
  local max_new_tokens = opts.max_new_tokens or 16
  local eos_token_id = opts.eos_token_id or 1
  local cfg = assert(self:config(), "model config is unavailable")
  local d_model = cfg.d_model
  enc_len = enc_len or (#encoder_out / d_model)
  if enc_len ~= math.floor(enc_len) then
    return nil, error_table(M.errors.INVALID_ARGUMENT, "invalid encoder length"), M.errors.INVALID_ARGUMENT
  end
  local prompt_len = #prompt_ids
  local enc_n = enc_len * d_model
  local cenc = ffi.new("float[?]", enc_n)
  local cprompt = ffi.new("int[?]", prompt_len)
  local out_cap = prompt_len + max_new_tokens
  local out = ffi.new("int[?]", out_cap)
  for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
  for i = 1, prompt_len do cprompt[i - 1] = prompt_ids[i] end
  local cb = make_token_filter_callback(opts)
  local rc = load_lib().needle_generate_tokens_greedy_cached_from_encoder_filtered(
    self._ctx, cenc, enc_len, cprompt, prompt_len, max_new_tokens, eos_token_id, cb, nil, out, out_cap
  )
  if cb ~= nil then cb:free() end
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  return read_int_output(out, rc)
end

function Context:generate_tokens_from_state(state, prompt_ids, opts)
  ensure_open(self)
  ensure_encoder_state_open(state)
  opts = opts or {}
  local max_new_tokens = opts.max_new_tokens or 16
  local eos_token_id = opts.eos_token_id or 1
  local prompt_len = #prompt_ids
  local cprompt = ffi.new("int[?]", prompt_len)
  local out_cap = prompt_len + max_new_tokens
  local out = ffi.new("int[?]", out_cap)
  for i = 1, prompt_len do cprompt[i - 1] = prompt_ids[i] end
  local cb = make_token_filter_callback(opts)
  local token_cb = nil
  if opts.on_token ~= nil then
    if type(opts.on_token) ~= "function" then
      if cb ~= nil then cb:free() end
      return nil, error_table(M.errors.INVALID_ARGUMENT, "on_token must be a function"), M.errors.INVALID_ARGUMENT
    end
    token_cb = ffi.cast("needle_token_callback", function(token_id, step, tokens, token_count, _)
      local ok, keep_going = pcall(opts.on_token, tonumber(token_id), tonumber(step) + 1, tokens, tonumber(token_count))
      if not ok or keep_going == false then
        return -1
      end
      return 0
    end)
  end
  local runtime = load_lib()
  local rc
  if token_cb ~= nil then
    rc = runtime.needle_generate_tokens_greedy_cached_from_state_stream_filtered(
      self._ctx, state._state, cprompt, prompt_len, max_new_tokens, eos_token_id, cb, nil, token_cb, nil, out, out_cap
    )
  else
    rc = runtime.needle_generate_tokens_greedy_cached_from_state_filtered(
      self._ctx, state._state, cprompt, prompt_len, max_new_tokens, eos_token_id, cb, nil, out, out_cap
    )
  end
  if cb ~= nil then cb:free() end
  if token_cb ~= nil then token_cb:free() end
  if rc < 0 then
    return nil, context_error(self, rc), rc
  end
  return read_int_output(out, rc)
end

local function append_all(dst, src)
  for i = 1, #src do
    dst[#dst + 1] = src[i]
  end
end

local function compact_json(text)
  text = text or "[]"
  local out = {}
  local in_string = false
  local escaped = false
  for i = 1, #text do
    local ch = text:sub(i, i)
    if in_string then
      out[#out + 1] = ch
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    elseif ch == '"' then
      in_string = true
      out[#out + 1] = ch
    elseif ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
      out[#out + 1] = ch
    end
  end
  return table.concat(out)
end

local function trie_new()
  return { children = {}, terminal = false }
end

local function trie_insert(root, word)
  local node = root
  for i = 1, #word do
    local ch = word:sub(i, i)
    local child = node.children[ch]
    if child == nil then
      child = trie_new()
      node.children[ch] = child
    end
    node = child
  end
  node.terminal = true
end

local function trie_get(root, prefix)
  local node = root
  for i = 1, #prefix do
    node = node.children[prefix:sub(i, i)]
    if node == nil then
      return nil
    end
  end
  return node
end

local function json_skip_ws(text, pos)
  while pos <= #text do
    local ch = text:sub(pos, pos)
    if ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
      break
    end
    pos = pos + 1
  end
  return pos
end

local function json_read_string(text, pos)
  if text:sub(pos, pos) ~= '"' then
    return nil, pos
  end
  local out = {}
  local i = pos + 1
  while i <= #text do
    local ch = text:sub(i, i)
    if ch == '"' then
      return table.concat(out), i + 1
    end
    if ch == "\\" then
      local next_ch = text:sub(i + 1, i + 1)
      if next_ch == '"' or next_ch == "\\" or next_ch == "/" then
        out[#out + 1] = next_ch
        i = i + 2
      elseif next_ch == "b" then
        out[#out + 1] = "\b"
        i = i + 2
      elseif next_ch == "f" then
        out[#out + 1] = "\f"
        i = i + 2
      elseif next_ch == "n" then
        out[#out + 1] = "\n"
        i = i + 2
      elseif next_ch == "r" then
        out[#out + 1] = "\r"
        i = i + 2
      elseif next_ch == "t" then
        out[#out + 1] = "\t"
        i = i + 2
      else
        out[#out + 1] = next_ch
        i = i + 2
      end
    else
      out[#out + 1] = ch
      i = i + 1
    end
  end
  return nil, pos
end

local function json_find_key(text, key, start_pos)
  local needle = '"' .. key .. '"'
  local pos = start_pos or 1
  while true do
    local s, e = text:find(needle, pos, true)
    if s == nil then
      return nil
    end
    local p = json_skip_ws(text, e + 1)
    if text:sub(p, p) == ":" then
      return p + 1
    end
    pos = e + 1
  end
end

local function json_find_matching(text, open_pos)
  local open_ch = text:sub(open_pos, open_pos)
  local close_ch = open_ch == "{" and "}" or "]"
  local depth = 0
  local in_string = false
  local escaped = false
  for i = open_pos, #text do
    local ch = text:sub(i, i)
    if in_string then
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    elseif ch == '"' then
      in_string = true
    elseif ch == open_ch then
      depth = depth + 1
    elseif ch == close_ch then
      depth = depth - 1
      if depth == 0 then
        return i
      end
    end
  end
  return nil
end

local function json_object_keys(text, open_pos, close_pos)
  local keys = {}
  local pos = open_pos + 1
  while pos < close_pos do
    pos = json_skip_ws(text, pos)
    if text:sub(pos, pos) == "," then
      pos = pos + 1
      pos = json_skip_ws(text, pos)
    end
    if text:sub(pos, pos) ~= '"' then
      break
    end
    local key, next_pos = json_read_string(text, pos)
    if key == nil then
      break
    end
    pos = json_skip_ws(text, next_pos)
    if text:sub(pos, pos) == ":" then
      keys[#keys + 1] = key
      pos = pos + 1
      pos = json_skip_ws(text, pos)
      local ch = text:sub(pos, pos)
      if ch == "{" or ch == "[" then
        local end_pos = json_find_matching(text, pos)
        if end_pos == nil then break end
        pos = end_pos + 1
      elseif ch == '"' then
        _, pos = json_read_string(text, pos)
      else
        local comma = text:find(",", pos, true) or close_pos
        pos = comma
      end
    else
      break
    end
  end
  return keys
end

local function json_object_value_span(text, open_pos, close_pos, key)
  local pos = open_pos + 1
  while pos < close_pos do
    pos = json_skip_ws(text, pos)
    if text:sub(pos, pos) == "," then
      pos = json_skip_ws(text, pos + 1)
    end
    if text:sub(pos, pos) ~= '"' then
      break
    end
    local cur_key, next_pos = json_read_string(text, pos)
    if cur_key == nil then
      break
    end
    pos = json_skip_ws(text, next_pos)
    if text:sub(pos, pos) ~= ":" then
      break
    end
    local value_start = json_skip_ws(text, pos + 1)
    local ch = text:sub(value_start, value_start)
    local value_end = value_start
    if ch == "{" or ch == "[" then
      value_end = json_find_matching(text, value_start)
      if value_end == nil then
        break
      end
    elseif ch == '"' then
      _, value_end = json_read_string(text, value_start)
      value_end = value_end - 1
    else
      local comma = text:find(",", value_start, true) or close_pos
      value_end = comma - 1
      while value_end > value_start and text:sub(value_end, value_end):match("%s") do
        value_end = value_end - 1
      end
    end
    if cur_key == key then
      return value_start, value_end
    end
    pos = value_end + 1
  end
  return nil
end

local function json_string_field(text, open_pos, close_pos, key)
  local value_start = json_object_value_span(text, open_pos, close_pos, key)
  if value_start == nil then
    return nil
  end
  value_start = json_skip_ws(text, value_start)
  return json_read_string(text, value_start)
end

local function json_string_array(text, open_pos, close_pos)
  local values = {}
  local pos = open_pos + 1
  while pos < close_pos do
    pos = json_skip_ws(text, pos)
    if text:sub(pos, pos) == "," then
      pos = json_skip_ws(text, pos + 1)
    end
    if text:sub(pos, pos) ~= '"' then
      break
    end
    local value, next_pos = json_read_string(text, pos)
    if value == nil then
      break
    end
    values[#values + 1] = value
    pos = next_pos
  end
  return values
end

local function parse_property_schema(text, open_pos, close_pos)
  local schema = {}
  schema.type = json_string_field(text, open_pos, close_pos, "type")
  local enum_start, enum_end = json_object_value_span(text, open_pos, close_pos, "enum")
  if enum_start ~= nil and text:sub(enum_start, enum_start) == "[" then
    local values = json_string_array(text, enum_start, enum_end)
    if #values > 0 then
      schema.enum = values
      schema.enum_trie = trie_new()
      for _, value in ipairs(values) do
        trie_insert(schema.enum_trie, value)
      end
    end
  end
  return schema
end

local function parse_property_schemas(text, props_open, props_close)
  local schemas = {}
  for _, key in ipairs(json_object_keys(text, props_open, props_close)) do
    local value_start, value_end = json_object_value_span(text, props_open, props_close, key)
    if value_start ~= nil and text:sub(value_start, value_start) == "{" then
      schemas[key] = parse_property_schema(text, value_start, value_end)
    else
      schemas[key] = {}
    end
  end
  return schemas
end

local function parse_tool_constraints(tools_json)
  local name_trie = trie_new()
  local param_tries = {}
  local schemas_by_tool = {}
  local pos = 1
  while true do
    local value_pos = json_find_key(tools_json or "[]", "name", pos)
    if value_pos == nil then
      break
    end
    value_pos = json_skip_ws(tools_json, value_pos)
    local name, after_name = json_read_string(tools_json, value_pos)
    if name == nil or name == "" then
      pos = value_pos + 1
    else
      trie_insert(name_trie, name)
      local param_trie = trie_new()
      local param_schemas = {}
      local params_value = json_find_key(tools_json, "parameters", after_name)
      if params_value ~= nil then
        params_value = json_skip_ws(tools_json, params_value)
        if tools_json:sub(params_value, params_value) == "{" then
          local params_end = json_find_matching(tools_json, params_value)
          if params_end ~= nil then
            local props_value = json_find_key(tools_json:sub(params_value, params_end), "properties", 1)
            if props_value ~= nil then
              props_value = params_value + props_value - 1
              props_value = json_skip_ws(tools_json, props_value)
              if tools_json:sub(props_value, props_value) == "{" then
                local props_end = json_find_matching(tools_json, props_value)
                if props_end ~= nil then
                  for _, key in ipairs(json_object_keys(tools_json, props_value, props_end)) do
                    trie_insert(param_trie, key)
                  end
                  param_schemas = parse_property_schemas(tools_json, props_value, props_end)
                end
              end
            else
              for _, key in ipairs(json_object_keys(tools_json, params_value, params_end)) do
                trie_insert(param_trie, key)
              end
              param_schemas = parse_property_schemas(tools_json, params_value, params_end)
            end
          end
        end
      end
      param_tries[name] = param_trie
      schemas_by_tool[name] = param_schemas
      pos = after_name
    end
  end
  return name_trie, param_tries, schemas_by_tool
end

local ToolCallConstraints = {}
ToolCallConstraints.__index = ToolCallConstraints

local function token_valid_for_node(token_text, node)
  local cur = node
  for i = 1, #token_text do
    local ch = token_text:sub(i, i)
    if ch == '"' then
      return cur.terminal
    end
    cur = cur.children[ch]
    if cur == nil then
      return false
    end
  end
  return true
end

local function state_new()
  return {
    state = "free",
    buffer = "",
    constrained_buf = "",
    current_function = "",
    current_arg_key = "",
    started = false,
    completed = false,
    in_arguments = false,
    arguments_depth = 0,
    nesting_depth = 0,
    in_string = false,
    prev_char_escape = false,
  }
end

local function state_is_value_quote(st)
  for i = #st.buffer - 1, 1, -1 do
    local ch = st.buffer:sub(i, i)
    if ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
      return ch == ":"
    end
  end
  return false
end

local function state_feed_char(st, ch, schemas_by_tool)
  if st.completed then
    st.buffer = st.buffer .. ch
    if #st.buffer > 128 then
      st.buffer = st.buffer:sub(#st.buffer - 127)
    end
    return
  end

  if st.state == "name" or st.state == "arg_key" or st.state == "arg_value_string" then
    if ch == '"' then
      if st.state == "name" then
        st.current_function = st.constrained_buf
      elseif st.state == "arg_key" then
        st.current_arg_key = st.constrained_buf
      end
      st.constrained_buf = ""
      st.state = "free"
    else
      st.constrained_buf = st.constrained_buf .. ch
    end
    st.buffer = st.buffer .. ch
    return
  end

  st.buffer = st.buffer .. ch
  if #st.buffer > 128 then
    st.buffer = st.buffer:sub(#st.buffer - 127)
  end

  if st.in_string then
    if st.prev_char_escape then
      st.prev_char_escape = false
      return
    end
    if ch == "\\" then
      st.prev_char_escape = true
      return
    end
    if ch == '"' then
      st.in_string = false
    end
    return
  end

  if ch == "{" or ch == "[" then
    if ch == "[" and st.nesting_depth == 0 then
      st.started = true
    end
    st.nesting_depth = st.nesting_depth + 1
  elseif ch == "}" or ch == "]" then
    st.nesting_depth = math.max(0, st.nesting_depth - 1)
    if ch == "}" and st.in_arguments and st.nesting_depth < st.arguments_depth then
      st.in_arguments = false
    end
    if ch == "]" and st.started and st.nesting_depth == 0 then
      st.completed = true
    end
    return
  end

  if st.buffer:sub(-8) == '"name":"' and not st.in_arguments then
    st.state = "name"
    st.constrained_buf = ""
    return
  end

  if st.buffer:sub(-13) == '"arguments":{' then
    st.in_arguments = true
    st.arguments_depth = st.nesting_depth
    return
  end

  if st.in_arguments and st.nesting_depth == st.arguments_depth then
    local tail = st.buffer:sub(-2)
    if tail == '{"' or tail == ',"' then
      st.state = "arg_key"
      st.constrained_buf = ""
      return
    end
  end

  if ch == '"' and state_is_value_quote(st) then
    local schema = schemas_by_tool
      and schemas_by_tool[st.current_function]
      and schemas_by_tool[st.current_function][st.current_arg_key]
      or nil
    if schema ~= nil and schema.enum_trie ~= nil then
      st.state = "arg_value_string"
      st.constrained_buf = ""
    else
      st.in_string = true
    end
  end
end

local function state_feed(st, text, schemas_by_tool)
  for i = 1, #text do
    state_feed_char(st, text:sub(i, i), schemas_by_tool)
  end
end

local function build_token_data(tokenizer)
  if tokenizer._token_strings ~= nil then
    return tokenizer._token_strings, tokenizer._token_index
  end
  local strings = {}
  local index = {}
  for id = 0, tokenizer:vocab_size() - 1 do
    local text = assert(tokenizer:token_text(id))
    strings[id] = text
    if text ~= "" then
      local first = text:sub(1, 1)
      local bucket = index[first]
      if bucket == nil then
        bucket = {}
        index[first] = bucket
      end
      bucket[#bucket + 1] = id
    end
  end
  tokenizer._token_strings = strings
  tokenizer._token_index = index
  return strings, index
end

function M.build_tool_call_constraints(tools_json, tokenizer, opts)
  if tokenizer == nil then
    return nil, error_table(M.errors.INVALID_ARGUMENT, "tool-call constraints require a tokenizer"), M.errors.INVALID_ARGUMENT
  end
  opts = opts or {}
  local token_strings, token_index = build_token_data(tokenizer)
  local name_trie, param_tries, schemas_by_tool = parse_tool_constraints(tools_json or "[]")
  return setmetatable({
    _state = state_new(),
    _seen = 0,
    _token_strings = token_strings,
    _token_index = token_index,
    _name_trie = name_trie,
    _param_tries = param_tries,
    _schemas_by_tool = schemas_by_tool,
    _eos_token_id = opts.eos_token_id or 1,
  }, ToolCallConstraints)
end

function ToolCallConstraints:feed_token(id)
  state_feed(self._state, self._token_strings[id] or "", self._schemas_by_tool)
end

function ToolCallConstraints:sync(tokens)
  for i = self._seen + 1, #tokens do
    self:feed_token(tokens[i])
  end
  self._seen = #tokens
end

function ToolCallConstraints:sync_c(tokens, token_count)
  for i = self._seen, token_count - 1 do
    self:feed_token(tonumber(tokens[i]))
  end
  self._seen = token_count
end

function ToolCallConstraints:allowed_token_ids()
  local st = self._state
  if st.completed then
    return { self._eos_token_id }
  end
  local trie
  if st.state == "name" then
    trie = self._name_trie
  elseif st.state == "arg_key" then
    trie = self._param_tries[st.current_function]
  elseif st.state == "arg_value_string" then
    local schema = self._schemas_by_tool
      and self._schemas_by_tool[st.current_function]
      and self._schemas_by_tool[st.current_function][st.current_arg_key]
      or nil
    trie = schema and schema.enum_trie or nil
  else
    return nil
  end
  if trie == nil then
    return { self._eos_token_id }
  end
  local node = trie_get(trie, st.constrained_buf)
  if node == nil then
    return { self._eos_token_id }
  end

  local allowed = {}
  for ch, _ in pairs(node.children) do
    local bucket = self._token_index[ch]
    if bucket ~= nil then
      for _, id in ipairs(bucket) do
        if token_valid_for_node(self._token_strings[id], node) then
          allowed[#allowed + 1] = id
        end
      end
    end
  end
  if node.terminal then
    local bucket = self._token_index['"']
    if bucket ~= nil then
      for _, id in ipairs(bucket) do
        if token_valid_for_node(self._token_strings[id], node) then
          allowed[#allowed + 1] = id
        end
      end
    end
  end
  if #allowed == 0 then
    return { self._eos_token_id }
  end
  return allowed
end

function ToolCallConstraints:token_filter()
  return function(_, tokens)
    self:sync(tokens)
    return self:allowed_token_ids()
  end
end

function ToolCallConstraints:token_filter_raw()
  return function(_, tokens, token_count)
    self:sync_c(tokens, tonumber(token_count))
    return self:allowed_token_ids()
  end
end

function Context:build_encoder_input(tokenizer, query, tools_json, opts)
  ensure_open(self)
  opts = opts or {}
  local max_enc_len = opts.max_enc_len or 1024
  local tools_token_id = opts.tools_token_id or 5
  if opts.compact_tools_json ~= false then
    tools_json = compact_json(tools_json or "[]")
  end
  local q_ids = assert(tokenizer:encode(query or ""))
  local tool_ids = assert(tokenizer:encode(tools_json or "[]"))

  local max_query = max_enc_len - 2
  if #q_ids > max_query then
    local trimmed = {}
    for i = 1, max_query do trimmed[i] = q_ids[i] end
    q_ids = trimmed
  end

  local remaining = max_enc_len - #q_ids - 1
  local input = {}
  append_all(input, q_ids)
  input[#input + 1] = tools_token_id
  for i = 1, math.min(#tool_ids, remaining) do
    input[#input + 1] = tool_ids[i]
  end
  return input
end

function Context:generate(query, tools_json, opts)
  ensure_open(self)
  opts = opts or {}
  if opts.compact_tools_json ~= false then
    tools_json = compact_json(tools_json or "[]")
  end

  local tokenizer = opts.tokenizer
  local owns_tokenizer = false
  if tokenizer == nil and opts.tokenizer_path then
    local tok, tok_err = M.load_tokenizer(opts.tokenizer_path, { lib = opts.lib })
    if not tok then
      return nil, tok_err, tok_err and tok_err.code or M.errors.INVALID_ARGUMENT
    end
    tokenizer = tok
    owns_tokenizer = true
  end
  if tokenizer == nil then
    return nil, error_table(M.errors.INVALID_ARGUMENT, "generate requires opts.tokenizer or opts.tokenizer_path"), M.errors.INVALID_ARGUMENT
  end

  local src_ids = self:build_encoder_input(tokenizer, query, tools_json, opts)
  local prompt_ids = opts.prompt_ids or { opts.eos_token_id or 1 }
  local max_new_tokens = opts.max_new_tokens or 64
  local eos_token_id = opts.eos_token_id or 1
  local token_filter = opts.token_filter
  local token_filter_raw = opts.token_filter_raw
  if opts.constrained then
    local constraints, constraint_err, constraint_rc = M.build_tool_call_constraints(tools_json or "[]", tokenizer, {
      eos_token_id = eos_token_id,
    })
    if not constraints then
      if owns_tokenizer then tokenizer:close() end
      return nil, constraint_err, constraint_rc
    end
    if token_filter ~= nil then
      local constraint_filter = constraints:token_filter()
      local user_filter = token_filter
      token_filter = function(step, tokens, logits, vocab_size)
        local a = constraint_filter(step, tokens, logits, vocab_size)
        local b = user_filter(step, tokens, logits, vocab_size)
        if a == nil then return b end
        if b == nil then return a end
        local seen = {}
        for _, id in ipairs(a) do seen[id] = true end
        local both = {}
        for _, id in ipairs(b) do
          if seen[id] then both[#both + 1] = id end
        end
        return #both > 0 and both or nil
      end
    elseif token_filter_raw ~= nil then
      local constraint_filter_raw = constraints:token_filter_raw()
      local user_filter_raw = token_filter_raw
      token_filter_raw = function(step, tokens, token_count, logits, vocab_size)
        local a = constraint_filter_raw(step, tokens, token_count, logits, vocab_size)
        local b = user_filter_raw(step, tokens, token_count, logits, vocab_size)
        if a == nil then return b end
        if b == nil then return a end
        local seen = {}
        for _, id in ipairs(a) do seen[id] = true end
        local both = {}
        for _, id in ipairs(b) do
          if seen[id] then both[#both + 1] = id end
        end
        return #both > 0 and both or nil
      end
    else
      token_filter_raw = constraints:token_filter_raw()
    end
  end
  local stream_requested = opts.on_token ~= nil or opts.on_text ~= nil
  if stream_requested then
    if opts.on_token ~= nil and type(opts.on_token) ~= "function" then
      if owns_tokenizer then tokenizer:close() end
      return nil, error_table(M.errors.INVALID_ARGUMENT, "on_token must be a function"), M.errors.INVALID_ARGUMENT
    end
    if opts.on_text ~= nil and type(opts.on_text) ~= "function" then
      if owns_tokenizer then tokenizer:close() end
      return nil, error_table(M.errors.INVALID_ARGUMENT, "on_text must be a function"), M.errors.INVALID_ARGUMENT
    end

    local encoder_state, enc_err, enc_rc = self:encode_tokens_state(src_ids)
    if not encoder_state then
      if owns_tokenizer then tokenizer:close() end
      return nil, enc_err, enc_rc
    end

    local result_ids = {}
    local emitted_prefix = opts.strip_tool_call == false
    local pending_text = ""
    local prefix = "<tool_call>"
    local trim_after_prefix = false
    local stream_error = nil
    local stream_error_code = nil

    local function emit_text(chunk)
      if chunk == "" or opts.on_text == nil then
        return true
      end
      local ok, keep_going = pcall(opts.on_text, chunk)
      if not ok then
        stream_error = error_table(M.errors.INVALID_ARGUMENT, tostring(keep_going))
        stream_error_code = M.errors.INVALID_ARGUMENT
        return false
      end
      if keep_going == false then
        stream_error = error_table(M.errors.INVALID_ARGUMENT, "on_text aborted generation")
        stream_error_code = M.errors.INVALID_ARGUMENT
        return false
      end
      return true
    end

    local function on_generated_token(token_id, step, tokens, token_count)
      if opts.on_token ~= nil then
        local ok, keep_going = pcall(opts.on_token, token_id, step, tokens, token_count)
        if not ok then
          stream_error = error_table(M.errors.INVALID_ARGUMENT, tostring(keep_going))
          stream_error_code = M.errors.INVALID_ARGUMENT
          return false
        end
        if keep_going == false then
          stream_error = error_table(M.errors.INVALID_ARGUMENT, "on_token aborted generation")
          stream_error_code = M.errors.INVALID_ARGUMENT
          return false
        end
      end
      if token_id == eos_token_id then
        return true
      end
      result_ids[#result_ids + 1] = token_id
      if opts.on_text == nil then
        return true
      end
      local chunk, chunk_err, chunk_rc = tokenizer:token_text(token_id, { out_cap = opts.token_text_cap or 256 })
      if not chunk then
        stream_error = chunk_err
        stream_error_code = chunk_rc
        return false
      end
      if emitted_prefix then
        if trim_after_prefix then
          chunk = chunk:gsub("^%s+", "")
          if chunk == "" then
            return true
          end
          trim_after_prefix = false
        end
        return emit_text(chunk)
      end
      pending_text = pending_text .. chunk
      if #pending_text < #prefix and prefix:sub(1, #pending_text) == pending_text then
        return true
      end
      if pending_text:sub(1, #prefix) == prefix then
        pending_text = pending_text:sub(#prefix + 1):gsub("^%s+", "")
        trim_after_prefix = pending_text == ""
      end
      emitted_prefix = true
      local to_emit = pending_text
      pending_text = ""
      if to_emit ~= "" then
        trim_after_prefix = false
      end
      return emit_text(to_emit)
    end

    local generated, gen_err, rc = self:generate_tokens_from_state(encoder_state, prompt_ids, {
      max_new_tokens = max_new_tokens,
      eos_token_id = eos_token_id,
      token_filter = token_filter,
      token_filter_raw = token_filter_raw,
      on_token = on_generated_token,
    })
    encoder_state:close()
    if not generated then
      if owns_tokenizer then tokenizer:close() end
      return nil, stream_error or gen_err, stream_error_code or rc
    end
    local text, dec_err, dec_rc = tokenizer:decode(result_ids, { out_cap = opts.out_cap or 8192 })
    if owns_tokenizer then tokenizer:close() end
    if not text then
      return nil, dec_err, dec_rc
    end
    if opts.strip_tool_call ~= false and text:sub(1, 11) == "<tool_call>" then
      text = text:sub(12)
      text = text:gsub("^%s+", "")
    end
    if opts.return_tokens then
      return text, nil, nil, generated, src_ids
    end
    return text
  end
  local generated, gen_err, rc = self:generate_tokens(src_ids, prompt_ids, {
    max_new_tokens = max_new_tokens,
    eos_token_id = eos_token_id,
    token_filter = token_filter,
    token_filter_raw = token_filter_raw,
    use_cache = opts.use_cache,
  })
  if not generated then
    if owns_tokenizer then tokenizer:close() end
    return nil, gen_err, rc
  end

  local result_ids = {}
  for i = #prompt_ids + 1, #generated do
    local id = generated[i]
    if id == eos_token_id then
      break
    end
    result_ids[#result_ids + 1] = id
  end
  local text, dec_err, dec_rc = tokenizer:decode(result_ids, { out_cap = opts.out_cap or 8192 })
  if owns_tokenizer then tokenizer:close() end
  if not text then
    return nil, dec_err, dec_rc
  end
  if opts.strip_tool_call ~= false and text:sub(1, 11) == "<tool_call>" then
    text = text:sub(12)
    text = text:gsub("^%s+", "")
  end
  if opts.return_tokens then
    return text, nil, nil, generated, src_ids
  end
  return text
end

function Context:close()
  if self._ctx ~= nil then
    load_lib().needle_free(self._ctx)
    self._ctx = nil
  end
end

function Context:__gc()
  self:close()
end

function M.load(model_path, opts)
  opts = opts or {}
  local runtime = load_lib(opts.lib)
  local ctx = runtime.needle_load(model_path or "")
  if ctx == nil then
    return nil, error_table(M.errors.NULL_CONTEXT, "needle_load returned null")
  end

  local self = setmetatable({ _ctx = ctx }, Context)
  local err = self:last_error_info()
  if err.code ~= M.errors.OK or err.message ~= "" then
    return self, err
  end
  return self
end

function M.version(opts)
  local runtime = load_lib(opts and opts.lib or nil)
  return ffi.string(runtime.needle_version())
end

function M.probe_add(a, b, opts)
  local runtime = load_lib(opts and opts.lib or nil)
  return tonumber(runtime.needle_probe_add(a, b))
end

local function ensure_tokenizer_open(self)
  if self._tok == nil then
    error("needle tokenizer is closed", 2)
  end
end

local function tokenizer_error(self, rc)
  local runtime = load_lib()
  local code = rc or runtime.needle_tokenizer_last_error_code(self._tok)
  local msg = runtime.needle_tokenizer_last_error(self._tok)
  return error_table(code, msg ~= nil and ffi.string(msg) or nil)
end

function Tokenizer:last_error_info()
  ensure_tokenizer_open(self)
  return tokenizer_error(self)
end

function Tokenizer:vocab_size()
  ensure_tokenizer_open(self)
  return tonumber(load_lib().needle_tokenizer_vocab_size(self._tok))
end

function Tokenizer:encode(text, opts)
  ensure_tokenizer_open(self)
  opts = opts or {}
  local cap = opts.cap or 2048
  local ids = ffi.new("int[?]", cap)
  local n = load_lib().needle_tokenizer_encode(self._tok, text or "", ids, cap)
  if n < 0 then
    return nil, tokenizer_error(self, n), n
  end
  local out = {}
  for i = 0, n - 1 do
    out[#out + 1] = tonumber(ids[i])
  end
  return out
end

function Tokenizer:decode(ids, opts)
  ensure_tokenizer_open(self)
  opts = opts or {}
  local out_cap = opts.out_cap or 4096
  local c_ids = ffi.new("int[?]", #ids)
  for i = 1, #ids do
    c_ids[i - 1] = ids[i]
  end
  local out = ffi.new("char[?]", out_cap)
  local n = load_lib().needle_tokenizer_decode(self._tok, c_ids, #ids, out, out_cap)
  if n < 0 then
    return nil, tokenizer_error(self, n), n
  end
  return ffi.string(out, n)
end

function Tokenizer:token_text(id, opts)
  ensure_tokenizer_open(self)
  opts = opts or {}
  local out_cap = opts.out_cap or 256
  local out = ffi.new("char[?]", out_cap)
  local n = load_lib().needle_tokenizer_token_text(self._tok, id, out, out_cap)
  if n < 0 then
    return nil, tokenizer_error(self, n), n
  end
  return ffi.string(out, n)
end

function Tokenizer:close()
  if self._tok ~= nil then
    load_lib().needle_tokenizer_free(self._tok)
    self._tok = nil
  end
end

function Tokenizer:__gc()
  self:close()
end

function M.load_tokenizer(path, opts)
  opts = opts or {}
  local runtime = load_lib(opts.lib)
  local tok = runtime.needle_tokenizer_load(path or "")
  if tok == nil then
    return nil, error_table(M.errors.NULL_CONTEXT, "needle_tokenizer_load returned null")
  end
  local self = setmetatable({ _tok = tok }, Tokenizer)
  local err = self:last_error_info()
  if err.code ~= M.errors.OK or err.message ~= "" then
    return self, err
  end
  return self
end

M.kernels = {}

local function float_array(values, n)
  local arr = ffi.new("float[?]", n)
  for i = 1, n do arr[i - 1] = values[i] or 0 end
  return arr
end

local function mask_array(mask, n)
  if not mask then return nil end
  local arr = ffi.new("unsigned char[?]", n)
  for i = 1, n do
    local v = mask[i]
    arr[i - 1] = (v == true or v == 1) and 1 or 0
  end
  return arr
end

local function table_from_float_array(arr, n)
  local result = {}
  for i = 0, n - 1 do result[#result + 1] = tonumber(arr[i]) end
  return result
end

function M.kernels.zcrmsnorm(x, scale, rows, cols, epsilon)
  local runtime = load_lib()
  local n = rows * cols
  local cx = float_array(x, n)
  local cscale = float_array(scale, cols)
  local out = ffi.new("float[?]", n)
  local rc = runtime.needle_kernel_zcrmsnorm_f32(cx, cscale, out, rows, cols, epsilon or 1e-6)
  if rc ~= 0 then
    return nil, error_table(rc, "zcrmsnorm failed"), rc
  end
  return table_from_float_array(out, n)
end

function M.kernels.rope(x, num_heads, seq_len, head_dim, theta)
  local runtime = load_lib()
  local n = num_heads * seq_len * head_dim
  local cx = float_array(x, n)
  local out = ffi.new("float[?]", n)
  local rc = runtime.needle_kernel_rope_f32(cx, out, num_heads, seq_len, head_dim, theta or 10000.0, 0)
  if rc ~= 0 then
    return nil, error_table(rc, "rope failed"), rc
  end
  return table_from_float_array(out, n)
end

function M.kernels.matmul(a, b, m, k, n, bias)
  local runtime = load_lib()
  local ca = float_array(a, m * k)
  local cb = float_array(b, k * n)
  local cbias = bias and float_array(bias, n) or nil
  local out = ffi.new("float[?]", m * n)
  local rc = runtime.needle_kernel_matmul_f32(ca, cb, cbias, out, m, k, n)
  if rc ~= 0 then
    return nil, error_table(rc, "matmul failed"), rc
  end
  return table_from_float_array(out, m * n)
end

function M.kernels.softmax(x, rows, cols, mask)
  local runtime = load_lib()
  local n = rows * cols
  local cx = float_array(x, n)
  local cmask = mask_array(mask, n)
  local out = ffi.new("float[?]", n)
  local rc = runtime.needle_kernel_softmax_f32(cx, cmask, out, rows, cols)
  if rc ~= 0 then
    return nil, error_table(rc, "softmax failed"), rc
  end
  return table_from_float_array(out, n)
end

function M.kernels.attention(q, k_values, v, q_len, kv_len, head_dim, mask)
  local runtime = load_lib()
  local qn = q_len * head_dim
  local kvn = kv_len * head_dim
  local cq = float_array(q, qn)
  local ck = float_array(k_values, kvn)
  local cv = float_array(v, kvn)
  local cmask = mask_array(mask, q_len * kv_len)
  local out = ffi.new("float[?]", qn)
  local rc = runtime.needle_kernel_attention_f32(cq, ck, cv, cmask, out, q_len, kv_len, head_dim)
  if rc ~= 0 then
    return nil, error_table(rc, "attention failed"), rc
  end
  return table_from_float_array(out, qn)
end

return M
