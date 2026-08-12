local ffi = require("ffi")

ffi.cdef [[
typedef struct needle_ctx needle_ctx;
typedef struct needle_kv_cache needle_kv_cache;
typedef struct needle_encoder_state needle_encoder_state;
typedef struct needle_tokenizer needle_tokenizer;
typedef int (*needle_progress_callback)(int completed, int total, void *user_data);
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
void needle_runtime_set_profile_enabled(int enabled);
int needle_runtime_profile_enabled(void);
void needle_runtime_reset_profile_stats(void);
unsigned long long needle_runtime_profile_counter_ns(int counter);

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
const unsigned char *needle_tensor_data(needle_ctx *ctx, unsigned long long index);
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
needle_encoder_state *needle_encoder_state_create_cancellable(
  needle_ctx *ctx,
  const int *src_ids,
  int src_len,
  needle_progress_callback callback,
  void *user_data);
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
needle_tokenizer *needle_tokenizer_from_context(needle_ctx *ctx);
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

---@alias needle.CString string|ffi.cdata*

---@class needle.IntBuffer: ffi.cdata*
---@field [integer] integer

---@class needle.FloatBuffer: ffi.cdata*
---@field [integer] number

---@class needle.ByteBuffer: ffi.cdata*
---@field [integer] integer

---@class needle.CharBuffer: ffi.cdata*

---@class needle.NativeLibrary
---@field needle_abi_version fun(): integer
---@field needle_version fun(): ffi.cdata*
---@field needle_probe_add fun(a: integer, b: integer): integer
---@field needle_runtime_reset_memory_stats fun()
---@field needle_runtime_aligned_alloc_count fun(): integer
---@field needle_runtime_aligned_alloc_total_bytes fun(): integer
---@field needle_runtime_aligned_alloc_active_count fun(): integer
---@field needle_runtime_aligned_alloc_current_bytes fun(): integer
---@field needle_runtime_aligned_alloc_peak_bytes fun(): integer
---@field needle_runtime_dense_q8_projection_count fun(): integer
---@field needle_runtime_dense_float_projection_count fun(): integer
---@field needle_runtime_dense_q8_fallback_count fun(): integer
---@field needle_runtime_output_q8_projection_count fun(): integer
---@field needle_runtime_output_float_projection_count fun(): integer
---@field needle_runtime_output_q8_fallback_count fun(): integer
---@field needle_runtime_set_profile_enabled fun(enabled: integer)
---@field needle_runtime_profile_enabled fun(): integer
---@field needle_runtime_reset_profile_stats fun()
---@field needle_runtime_profile_counter_ns fun(counter: integer): integer
---@field needle_load fun(model_path: needle.CString): ffi.cdata*
---@field needle_free fun(ctx: ffi.cdata*?)
---@field needle_last_error fun(ctx: ffi.cdata*?): ffi.cdata*
---@field needle_last_error_code fun(ctx: ffi.cdata*?): integer
---@field needle_clear_error fun(ctx: ffi.cdata*?)
---@field needle_is_loaded fun(ctx: ffi.cdata*?): integer
---@field needle_tensor_count fun(ctx: ffi.cdata*?): integer
---@field needle_tensor_data_bytes fun(ctx: ffi.cdata*?): integer
---@field needle_tokenizer_bytes fun(ctx: ffi.cdata*?): integer
---@field needle_metadata_json fun(ctx: ffi.cdata*?): ffi.cdata*
---@field needle_get_config fun(ctx: ffi.cdata*?): needle.NativeConfig?
---@field needle_tensor_name fun(ctx: ffi.cdata*?, index: integer): ffi.cdata*
---@field needle_tensor_dtype fun(ctx: ffi.cdata*?, index: integer): integer
---@field needle_tensor_ndim fun(ctx: ffi.cdata*?, index: integer): integer
---@field needle_tensor_dim fun(ctx: ffi.cdata*?, index: integer, dim: integer): integer
---@field needle_tensor_nbytes fun(ctx: ffi.cdata*?, index: integer): integer
---@field needle_tensor_data fun(ctx: ffi.cdata*?, index: integer): ffi.cdata*
---@field needle_find_tensor fun(ctx: ffi.cdata*?, name: needle.CString): integer
---@field needle_embedding_lookup fun(ctx: ffi.cdata*?, token_id: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_encoder_self_attention_f32 fun(ctx: ffi.cdata*?, layer: integer, x: ffi.cdata*?, seq_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_encoder_block_f32 fun(ctx: ffi.cdata*?, layer: integer, x: ffi.cdata*?, seq_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_output_projection_f32 fun(ctx: ffi.cdata*?, x: ffi.cdata*?, seq_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_encode_tokens_f32 fun(ctx: ffi.cdata*?, token_ids: ffi.cdata*?, seq_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decoder_self_attention_f32 fun(ctx: ffi.cdata*?, layer: integer, x: ffi.cdata*?, seq_len: integer, causal: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decoder_self_attention_cached_step_f32 fun(ctx: ffi.cdata*?, cache: ffi.cdata*?, layer: integer, x: ffi.cdata*?, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decoder_cross_attention_f32 fun(ctx: ffi.cdata*?, layer: integer, x: ffi.cdata*?, seq_len: integer, encoder_out: ffi.cdata*?, enc_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decoder_block_f32 fun(ctx: ffi.cdata*?, layer: integer, x: ffi.cdata*?, seq_len: integer, encoder_out: ffi.cdata*?, enc_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decoder_block_cached_step_f32 fun(ctx: ffi.cdata*?, cache: ffi.cdata*?, layer: integer, x: ffi.cdata*?, encoder_out: ffi.cdata*?, enc_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decode_tokens_f32 fun(ctx: ffi.cdata*?, token_ids: ffi.cdata*?, seq_len: integer, encoder_out: ffi.cdata*?, enc_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_decode_token_cached_step_f32 fun(ctx: ffi.cdata*?, cache: ffi.cdata*?, token_id: integer, encoder_out: ffi.cdata*?, enc_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_forward_logits_f32 fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer, tgt_ids: ffi.cdata*?, tgt_len: integer, out: ffi.cdata*?, out_cap: integer): integer
---@field needle_encoder_state_create fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer): ffi.cdata*
---@field needle_encoder_state_create_cancellable fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer, callback: ffi.cdata*?, user_data: ffi.cdata*?): ffi.cdata*
---@field needle_encoder_state_free fun(state: ffi.cdata*?)
---@field needle_encoder_state_len fun(state: ffi.cdata*?): integer
---@field needle_encoder_state_d_model fun(state: ffi.cdata*?): integer
---@field needle_kv_cache_create fun(ctx: ffi.cdata*?, max_tokens: integer): ffi.cdata*
---@field needle_kv_cache_free fun(cache: ffi.cdata*?)
---@field needle_kv_cache_reset fun(cache: ffi.cdata*?): integer
---@field needle_kv_cache_set_token_count fun(cache: ffi.cdata*?, token_count: integer): integer
---@field needle_kv_cache_token_count fun(cache: ffi.cdata*?): integer
---@field needle_kv_cache_max_tokens fun(cache: ffi.cdata*?): integer
---@field needle_kv_cache_layer_count fun(cache: ffi.cdata*?): integer
---@field needle_kv_cache_kv_heads fun(cache: ffi.cdata*?): integer
---@field needle_kv_cache_head_dim fun(cache: ffi.cdata*?): integer
---@field needle_kv_cache_bytes fun(cache: ffi.cdata*?): integer
---@field needle_generate_tokens_greedy fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate_tokens_greedy_filtered fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, filter: ffi.cdata*?, user_data: ffi.cdata*?, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate_tokens_greedy_cached fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate_tokens_greedy_cached_filtered fun(ctx: ffi.cdata*?, src_ids: ffi.cdata*?, src_len: integer, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, filter: ffi.cdata*?, user_data: ffi.cdata*?, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate_tokens_greedy_cached_from_encoder_filtered fun(ctx: ffi.cdata*?, encoder_out: ffi.cdata*?, enc_len: integer, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, filter: ffi.cdata*?, user_data: ffi.cdata*?, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate_tokens_greedy_cached_from_state_filtered fun(ctx: ffi.cdata*?, state: ffi.cdata*?, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, filter: ffi.cdata*?, user_data: ffi.cdata*?, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate_tokens_greedy_cached_from_state_stream_filtered fun(ctx: ffi.cdata*?, state: ffi.cdata*?, prompt_ids: ffi.cdata*?, prompt_len: integer, max_new_tokens: integer, eos_token_id: integer, filter: ffi.cdata*?, filter_user_data: ffi.cdata*?, token_callback: ffi.cdata*?, token_user_data: ffi.cdata*?, out_ids: ffi.cdata*?, out_cap: integer): integer
---@field needle_generate fun(ctx: ffi.cdata*?, query: needle.CString, tools_json: needle.CString, out: needle.CharBuffer, out_cap: integer): integer
---@field needle_generate_stream fun(ctx: ffi.cdata*?, query: needle.CString, tools_json: needle.CString, callback: ffi.cdata*?, user_data: ffi.cdata*?): integer
---@field needle_tokenizer_load fun(path: needle.CString): ffi.cdata*
---@field needle_tokenizer_from_context fun(ctx: ffi.cdata*?): ffi.cdata*
---@field needle_tokenizer_free fun(tok: ffi.cdata*?)
---@field needle_tokenizer_last_error fun(tok: ffi.cdata*?): ffi.cdata*
---@field needle_tokenizer_last_error_code fun(tok: ffi.cdata*?): integer
---@field needle_tokenizer_vocab_size fun(tok: ffi.cdata*?): integer
---@field needle_tokenizer_encode fun(tok: ffi.cdata*?, text: needle.CString, out_ids: needle.IntBuffer, out_cap: integer): integer
---@field needle_tokenizer_decode fun(tok: ffi.cdata*?, ids: needle.IntBuffer, count: integer, out: needle.CharBuffer, out_cap: integer): integer
---@field needle_tokenizer_token_text fun(tok: ffi.cdata*?, id: integer, out: needle.CharBuffer, out_cap: integer): integer
---@field needle_kernel_zcrmsnorm_f32 fun(x: ffi.cdata*?, scale: ffi.cdata*?, out: ffi.cdata*?, rows: integer, cols: integer, epsilon: number): integer
---@field needle_kernel_rope_f32 fun(x: ffi.cdata*?, out: ffi.cdata*?, num_heads: integer, seq_len: integer, head_dim: integer, theta: number, rope_keys_only: integer): integer
---@field needle_kernel_matmul_f32 fun(a: ffi.cdata*?, b: ffi.cdata*?, bias: ffi.cdata*?, out: ffi.cdata*?, m: integer, k: integer, n: integer): integer
---@field needle_kernel_softmax_f32 fun(x: ffi.cdata*?, mask: ffi.cdata*?, out: ffi.cdata*?, rows: integer, cols: integer): integer
---@field needle_kernel_attention_f32 fun(q: ffi.cdata*?, k: ffi.cdata*?, v: ffi.cdata*?, mask: ffi.cdata*?, out: ffi.cdata*?, q_len: integer, kv_len: integer, head_dim: integer): integer


---@class needle.NativeCallback: ffi.cdata*
---@field free fun(self: needle.NativeCallback)

---@class needle.NativeConfig: ffi.cdata*
---@field vocab_size integer
---@field d_model integer
---@field num_heads integer
---@field num_kv_heads integer
---@field num_encoder_layers integer
---@field num_decoder_layers integer
---@field d_ff integer
---@field max_seq_len integer
---@field pad_token_id integer
---@field rope_theta number
---@field num_memory_slots integer
---@field dropout_rate number
---@field contrastive_dim integer
---@field no_feedforward integer
---@field enable_speech integer
---@field dtype ffi.cdata*
---@field activation ffi.cdata*

---@class needle.Error
---@field code integer
---@field name string
---@field message string

---@class needle.Config
---@field vocab_size integer
---@field d_model integer
---@field num_heads integer
---@field num_kv_heads integer
---@field num_encoder_layers integer
---@field num_decoder_layers integer
---@field d_ff integer
---@field max_seq_len integer
---@field pad_token_id integer
---@field rope_theta number
---@field num_memory_slots integer
---@field dropout_rate number
---@field contrastive_dim integer
---@field no_feedforward boolean
---@field enable_speech boolean
---@field dtype string
---@field activation string

---@class needle.Options
---@field lib string?
---@field cap integer?
---@field out_cap integer?
---@field d_model integer?
---@field vocab_size integer?
---@field causal boolean?
---@field max_new_tokens integer?
---@field eos_token_id integer?
---@field use_cache boolean?
---@field max_enc_len integer?
---@field tools_token_id integer?
---@field compact_tools_json boolean?
---@field constrained boolean?
---@field tokenizer needle.Tokenizer?
---@field tokenizer_path string?
---@field prompt_ids integer[]?
---@field return_tokens boolean?
---@field strip_tool_call boolean?
---@field token_text_cap integer?
---@field allowed_token_ids_by_step {[integer]: integer[]}?
---@field token_filter (fun(step: integer, tokens: integer[], logits: ffi.cdata*, vocab_size: integer): integer[]?)?
---@field token_filter_raw (fun(step: integer, tokens: ffi.cdata*, token_count: integer, logits: ffi.cdata*, vocab_size: integer): integer[]?)?
---@field on_progress (fun(completed: integer, total: integer): boolean?)?
---@field on_prefill_progress (fun(completed: integer, total: integer): boolean?)?
---@field on_token (fun(token_id: integer, step: integer, tokens: ffi.cdata*, token_count: integer): boolean?)?
---@field on_text (fun(text: string))?

---@class needle.TrieNode
---@field children {[string]: needle.TrieNode}
---@field terminal boolean

---@class needle.PropertySchema
---@field type string?
---@field required boolean?
---@field enum string[]?
---@field enum_trie needle.TrieNode?

---@alias needle.PropertySchemas {[string]: needle.PropertySchema}

---@class needle.ConstraintState
---@field state "free"|"name"|"arg_key"|"arg_value_string"|"arg_after_value"
---@field buffer string
---@field constrained_buf string
---@field current_function string
---@field current_arg_key string
---@field value_string_key string
---@field primitive_value_key string
---@field seen_arg_keys {[string]: true}
---@field started boolean
---@field completed boolean
---@field in_arguments boolean
---@field arguments_depth integer
---@field nesting_depth integer
---@field in_string boolean
---@field prev_char_escape boolean

---@class needle.ToolCallConstraints
---@field _state needle.ConstraintState
---@field _seen integer
---@field _token_strings {[integer]: string}
---@field _token_index {[string]: integer[]}
---@field _name_trie needle.TrieNode
---@field _param_tries {[string]: needle.TrieNode}
---@field _param_keys_by_tool {[string]: string[]}
---@field _schemas_by_tool {[string]: needle.PropertySchemas}
---@field _required_by_tool {[string]: {[string]: true}}
---@field _eos_token_id integer

---@class needle.Context
---@field _ctx ffi.cdata*?

---@class needle.EncoderState
---@field _state ffi.cdata*?

---@class needle.KVCache
---@field _cache ffi.cdata*?

---@class needle.Tokenizer
---@field _tok ffi.cdata*?
---@field _token_strings {[integer]: string}?
---@field _token_index {[string]: integer[]}?

local M = {}
M.abi_version = 8
---@type {[string]: integer}
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
	CANCELLED = -9,
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

---@type {[integer]: string}
local error_names = {}
for name, code in pairs(M.errors) do
	error_names[code] = name
end

local default_lib_name = "needle_runtime"

---@type needle.NativeLibrary?
local lib

---@param path string?
---@return needle.NativeLibrary
local function load_lib(path)
	if lib then
		return lib
	end
	lib = ffi.load(path or os.getenv("NEEDLE_RUNTIME_LIB") or default_lib_name) --[[@as needle.NativeLibrary]]
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

local profile_counter_names = {
	"encoder_embedding",
	"encoder_block_norm",
	"encoder_q_proj",
	"encoder_k_proj",
	"encoder_v_proj",
	"encoder_qk_norm_rope",
	"encoder_attention_scores",
	"encoder_attention_values",
	"encoder_out_proj",
	"encoder_block_residual",
	"encoder_final_norm",
}

function M.set_profile_enabled(enabled)
	load_lib().needle_runtime_set_profile_enabled(enabled and 1 or 0)
end

function M.reset_profile_stats()
	load_lib().needle_runtime_reset_profile_stats()
end

function M.profile_stats()
	local runtime = load_lib()
	---@type {[string]: number|boolean}
	local stats = {enabled = runtime.needle_runtime_profile_enabled() ~= 0}
	for index, name in ipairs(profile_counter_names) do
		stats[name .. "_seconds"] = tonumber(runtime.needle_runtime_profile_counter_ns(index - 1)) / 1e9
	end
	return stats
end

---@class needle.Context
local Context = {}
Context.__index = Context

---@class needle.EncoderState
local EncoderState = {}
EncoderState.__index = EncoderState
---@type fun(self: needle.EncoderState)
local ensure_encoder_state_open

---@class needle.KVCache
local KVCache = {}
KVCache.__index = KVCache
---@type fun(self: needle.KVCache)
local ensure_cache_open

---@class needle.Tokenizer
local Tokenizer = {}
Tokenizer.__index = Tokenizer

---@param self needle.Context
local function ensure_open(self)
	if self._ctx == nil then
		error("needle context is closed", 2)
	end
end

---@param code integer
---@param message string?
---@return needle.Error
local function error_table(code, message)
	return {
		code = tonumber(code),
		name = error_names[tonumber(code)] or "UNKNOWN",
		message = message or "",
	}
end

---@param self needle.Context
---@param rc integer?
---@return needle.Error
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

---@param query string
---@param tools_json string
---@param callback fun(text: string)
---@param opts needle.Options?
function Context:generate_stream(query, tools_json, callback, opts)
	ensure_open(self)
	if type(callback) ~= "function" then
		return nil, error_table(M.errors.INVALID_ARGUMENT, "stream callback must be a function"), M.errors.INVALID_ARGUMENT
	end
	opts = opts or {}
	---@type needle.Options
	local gen_opts = {}
	-- LuaLS 3.19 does not propagate record fields through pairs().
	---@diagnostic disable-next-line: no-unknown
	for k, v in pairs(opts) do
		---@diagnostic disable-next-line: no-unknown
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

---@return needle.Config?
function Context:config()
	ensure_open(self)
	---@type needle.NativeConfig?
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

---@param index integer
function Context:tensor(index)
	ensure_open(self)
	local runtime = load_lib()
	local zero_index = index - 1
	local name = runtime.needle_tensor_name(self._ctx, zero_index)
	if name == nil or ffi.string(name) == "" then
		return nil
	end
	local ndim = tonumber(runtime.needle_tensor_ndim(self._ctx, zero_index))
	---@type integer[]
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

---@param index integer
---@return ffi.cdata*? pointer
---@return integer? nbytes
function Context:tensor_data(index)
	ensure_open(self)
	local zero_index = index - 1
	local pointer = load_lib().needle_tensor_data(self._ctx, zero_index)
	if pointer == nil then
		return nil
	end
	return pointer, tonumber(load_lib().needle_tensor_nbytes(self._ctx, zero_index))
end

---@param token_id integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:embedding(token_id, opts)
	ensure_open(self)
	opts = opts or {}
	local cap = opts.cap or 8192
	local out = ffi.new("float[?]", cap) --[[@as needle.FloatBuffer]]
	local n = load_lib().needle_embedding_lookup(self._ctx, token_id, out, cap)
	if n < 0 then
		return nil, context_error(self, n), n
	end
	---@type number[]
	local values = {}
	for i = 0, n - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param layer integer
---@param x number[]
---@param seq_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:encoder_self_attention(layer, x, seq_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local n = seq_len * d_model
	local cx = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	for i = 1, n do
		cx[i - 1] = x[i] or 0
	end
	local rc = load_lib().needle_encoder_self_attention_f32(self._ctx, layer or 0, cx, seq_len, out, n)
	if rc ~= 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, n - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param layer integer
---@param x number[]
---@param seq_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:encoder_block(layer, x, seq_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local n = seq_len * d_model
	local cx = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	for i = 1, n do
		cx[i - 1] = x[i] or 0
	end
	local rc = load_lib().needle_encoder_block_f32(self._ctx, layer or 0, cx, seq_len, out, n)
	if rc ~= 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, n - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param x number[]
---@param seq_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:output_projection(x, seq_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local vocab_size = opts.vocab_size or cfg.vocab_size
	local in_n = seq_len * d_model
	local out_n = seq_len * vocab_size
	local cx = ffi.new("float[?]", in_n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", out_n) --[[@as needle.FloatBuffer]]
	for i = 1, in_n do
		cx[i - 1] = x[i] or 0
	end
	local rc = load_lib().needle_output_projection_f32(self._ctx, cx, seq_len, out, out_n)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, out_n - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param token_ids integer[]
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:encode_tokens(token_ids, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local seq_len = #token_ids
	local d_model = opts.d_model or cfg.d_model
	local ids = ffi.new("int[?]", seq_len) --[[@as needle.IntBuffer]]
	local out = ffi.new("float[?]", seq_len * d_model) --[[@as needle.FloatBuffer]]
	for i = 1, seq_len do
		ids[i - 1] = token_ids[i]
	end
	local rc = load_lib().needle_encode_tokens_f32(self._ctx, ids, seq_len, out, seq_len * d_model)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, seq_len * d_model - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param layer integer
---@param x number[]
---@param seq_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decoder_self_attention(layer, x, seq_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local n = seq_len * d_model
	local cx = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	for i = 1, n do
		cx[i - 1] = x[i] or 0
	end
	local causal = opts.causal == false and 0 or 1
	local rc = load_lib().needle_decoder_self_attention_f32(self._ctx, layer or 0, cx, seq_len, causal, out, n)
	if rc ~= 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, n - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param cache needle.KVCache
---@param layer integer
---@param x number[]
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decoder_self_attention_cached_step(cache, layer, x, opts)
	ensure_open(self)
	ensure_cache_open(cache)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local cx = ffi.new("float[?]", d_model) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", d_model) --[[@as needle.FloatBuffer]]
	for i = 1, d_model do
		cx[i - 1] = x[i] or 0
	end
	local rc = load_lib().needle_decoder_self_attention_cached_step_f32(self._ctx, cache._cache, layer or 0, cx, out, d_model)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, rc - 1 do
		values[#values + 1] = tonumber(out[i])
	end
	return values
end

---@param layer integer
---@param x number[]
---@param seq_len integer
---@param encoder_out number[]
---@param enc_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decoder_cross_attention(layer, x, seq_len, encoder_out, enc_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local n = seq_len * d_model
	local enc_n = enc_len * d_model
	local cx = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local cenc = ffi.new("float[?]", enc_n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	for i = 1, n do cx[i - 1] = x[i] or 0 end
	for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
	local rc = load_lib().needle_decoder_cross_attention_f32(self._ctx, layer or 0, cx, seq_len, cenc, enc_len, out, n)
	if rc ~= 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, n - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

---@param layer integer
---@param x number[]
---@param seq_len integer
---@param encoder_out number[]
---@param enc_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decoder_block(layer, x, seq_len, encoder_out, enc_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local n = seq_len * d_model
	local enc_n = enc_len * d_model
	local cx = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local cenc = ffi.new("float[?]", enc_n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	for i = 1, n do cx[i - 1] = x[i] or 0 end
	for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
	local rc = load_lib().needle_decoder_block_f32(self._ctx, layer or 0, cx, seq_len, cenc, enc_len, out, n)
	if rc ~= 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, n - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

---@param cache needle.KVCache
---@param layer integer
---@param x number[]
---@param encoder_out number[]
---@param enc_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decoder_block_cached_step(cache, layer, x, encoder_out, enc_len, opts)
	ensure_open(self)
	ensure_cache_open(cache)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local enc_n = enc_len * d_model
	local cx = ffi.new("float[?]", d_model) --[[@as needle.FloatBuffer]]
	local cenc = ffi.new("float[?]", enc_n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", d_model) --[[@as needle.FloatBuffer]]
	for i = 1, d_model do cx[i - 1] = x[i] or 0 end
	for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
	local rc = load_lib().needle_decoder_block_cached_step_f32(
		self._ctx, cache._cache, layer or 0, cx, cenc, enc_len, out, d_model
	)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, rc - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

---@param token_ids integer[]
---@param encoder_out number[]
---@param enc_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decode_tokens(token_ids, encoder_out, enc_len, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local seq_len = #token_ids
	local d_model = opts.d_model or cfg.d_model
	local ids = ffi.new("int[?]", seq_len) --[[@as needle.IntBuffer]]
	local enc_n = enc_len * d_model
	local cenc = ffi.new("float[?]", enc_n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", seq_len * d_model) --[[@as needle.FloatBuffer]]
	for i = 1, seq_len do ids[i - 1] = token_ids[i] end
	for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
	local rc = load_lib().needle_decode_tokens_f32(self._ctx, ids, seq_len, cenc, enc_len, out, seq_len * d_model)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, seq_len * d_model - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

---@param cache needle.KVCache
---@param token_id integer
---@param encoder_out number[]
---@param enc_len integer
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:decode_token_cached_step(cache, token_id, encoder_out, enc_len, opts)
	ensure_open(self)
	ensure_cache_open(cache)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local d_model = opts.d_model or cfg.d_model
	local enc_n = enc_len * d_model
	local cenc = ffi.new("float[?]", enc_n) --[[@as needle.FloatBuffer]]
	local out = ffi.new("float[?]", d_model) --[[@as needle.FloatBuffer]]
	for i = 1, enc_n do cenc[i - 1] = encoder_out[i] or 0 end
	local rc = load_lib().needle_decode_token_cached_step_f32(self._ctx, cache._cache, token_id, cenc, enc_len, out, d_model)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, rc - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

---@param src_ids integer[]
---@param tgt_ids integer[]
---@param opts needle.Options?
---@return number[]?, needle.Error?, integer?
function Context:forward_logits(src_ids, tgt_ids, opts)
	ensure_open(self)
	opts = opts or {}
	local cfg = assert(self:config(), "model config is unavailable")
	local src_len = #src_ids
	local tgt_len = #tgt_ids
	local vocab_size = opts.vocab_size or cfg.vocab_size
	local csrc = ffi.new("int[?]", src_len) --[[@as needle.IntBuffer]]
	local ctgt = ffi.new("int[?]", tgt_len) --[[@as needle.IntBuffer]]
	local out = ffi.new("float[?]", tgt_len * vocab_size) --[[@as needle.FloatBuffer]]
	for i = 1, src_len do csrc[i - 1] = src_ids[i] end
	for i = 1, tgt_len do ctgt[i - 1] = tgt_ids[i] end
	local rc = load_lib().needle_forward_logits_f32(self._ctx, csrc, src_len, ctgt, tgt_len, out, tgt_len * vocab_size)
	if rc < 0 then
		return nil, context_error(self, rc), rc
	end
	---@type number[]
	local values = {}
	for i = 0, tgt_len * vocab_size - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

function ensure_encoder_state_open(self)
	if self._state == nil then
		error("needle encoder state is closed", 2)
	end
end

---@param token_ids integer[]
---@param opts needle.Options?
---@return needle.EncoderState?, needle.Error?, integer?
function Context:encode_tokens_state(token_ids, opts)
	ensure_open(self)
	opts = opts or {}
	if opts.on_progress ~= nil and type(opts.on_progress) ~= "function" then
		return nil, error_table(M.errors.INVALID_ARGUMENT, "on_progress must be a function"), M.errors.INVALID_ARGUMENT
	end
	local seq_len = #token_ids
	local ids = ffi.new("int[?]", seq_len) --[[@as needle.IntBuffer]]
	for i = 1, seq_len do ids[i - 1] = token_ids[i] end
	---@type string?
	local callback_error
	---@type needle.NativeCallback?
	local callback
	if opts.on_progress ~= nil then
		callback = ffi.cast("needle_progress_callback", function(completed, total)
			local ok, keep_going = pcall(opts.on_progress, tonumber(completed), tonumber(total))
			if not ok then
				callback_error = tostring(keep_going)
				return 0
			end
			return keep_going == false and 0 or 1
		end) --[[@as needle.NativeCallback]]
	end
	---@type ffi.cdata*?
	local state
	if callback ~= nil then
		state = load_lib().needle_encoder_state_create_cancellable(self._ctx, ids, seq_len, callback, nil)
		callback:free()
	else
		state = load_lib().needle_encoder_state_create(self._ctx, ids, seq_len)
	end
	if state == nil then
		if callback_error then
			return nil, error_table(M.errors.INVALID_ARGUMENT, callback_error), M.errors.INVALID_ARGUMENT
		end
		local err = context_error(self)
		return nil, err, err.code
	end
	local encoder_state = setmetatable({_state = state}, EncoderState) --[[@as needle.EncoderState]]
	return encoder_state
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

---@param max_tokens integer?
---@return needle.KVCache?, needle.Error?
function Context:create_kv_cache(max_tokens)
	ensure_open(self)
	max_tokens = max_tokens or (self:config() and self:config().max_seq_len) or 0
	local cache = load_lib().needle_kv_cache_create(self._ctx, max_tokens)
	if cache == nil then
		return nil, context_error(self)
	end
	local kv_cache = setmetatable({_cache = cache}, KVCache) --[[@as needle.KVCache]]
	return kv_cache
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

---@param token_count integer
---@return boolean?, needle.Error?, integer?
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

---@param opts needle.Options
---@return needle.NativeCallback?
local function make_token_filter_callback(opts)
	if opts.allowed_token_ids_by_step == nil and opts.token_filter == nil and opts.token_filter_raw == nil then
		return nil
	end
	return ffi.cast("needle_token_filter_callback", function(step, tokens, token_count, logits, vocab_size, allowed_ids, allowed_cap, _)
		local step_index = tonumber(step) + 1
		---@type integer[]?
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
			---@type integer[]
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
		local output_ids = allowed_ids --[[@as needle.IntBuffer]]
		for i = 1, n do
			output_ids[i - 1] = allowed[i]
		end
		return n
	end) --[[@as needle.NativeCallback]]
end

---@param out needle.IntBuffer
---@param n integer
---@return integer[]
local function read_int_output(out, n)
	---@type integer[]
	---@type number[]
	local values = {}
	for i = 0, n - 1 do values[#values + 1] = tonumber(out[i]) end
	return values
end

---@param src_ids integer[]
---@param prompt_ids integer[]
---@param opts needle.Options?
---@return integer[]?, needle.Error?, integer?
function Context:generate_tokens(src_ids, prompt_ids, opts)
	ensure_open(self)
	opts = opts or {}
	local max_new_tokens = opts.max_new_tokens or 16
	local eos_token_id = opts.eos_token_id or 1
	local src_len = #src_ids
	local prompt_len = #prompt_ids
	local csrc = ffi.new("int[?]", src_len) --[[@as needle.IntBuffer]]
	local cprompt = ffi.new("int[?]", prompt_len) --[[@as needle.IntBuffer]]
	local out_cap = prompt_len + max_new_tokens
	local out = ffi.new("int[?]", out_cap) --[[@as needle.IntBuffer]]
	for i = 1, src_len do csrc[i - 1] = src_ids[i] end
	for i = 1, prompt_len do cprompt[i - 1] = prompt_ids[i] end
	local runtime = load_lib()
	local cb = make_token_filter_callback(opts)
	---@type integer
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

---@param encoder_out number[]
---@param enc_len integer?
---@param prompt_ids integer[]
---@param opts needle.Options?
---@return integer[]?, needle.Error?, integer?
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
	local cenc = ffi.new("float[?]", enc_n) --[[@as needle.FloatBuffer]]
	local cprompt = ffi.new("int[?]", prompt_len) --[[@as needle.IntBuffer]]
	local out_cap = prompt_len + max_new_tokens
	local out = ffi.new("int[?]", out_cap) --[[@as needle.IntBuffer]]
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

---@param state needle.EncoderState
---@param prompt_ids integer[]
---@param opts needle.Options?
---@return integer[]?, needle.Error?, integer?
function Context:generate_tokens_from_state(state, prompt_ids, opts)
	ensure_open(self)
	ensure_encoder_state_open(state)
	opts = opts or {}
	local max_new_tokens = opts.max_new_tokens or 16
	local eos_token_id = opts.eos_token_id or 1
	local prompt_len = #prompt_ids
	local cprompt = ffi.new("int[?]", prompt_len) --[[@as needle.IntBuffer]]
	local out_cap = prompt_len + max_new_tokens
	local out = ffi.new("int[?]", out_cap) --[[@as needle.IntBuffer]]
	for i = 1, prompt_len do cprompt[i - 1] = prompt_ids[i] end
	local cb = make_token_filter_callback(opts)
	---@type needle.NativeCallback?
	local token_cb
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
		end) --[[@as needle.NativeCallback]]
	end
	local runtime = load_lib()
	---@type integer
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

---@generic T
---@param dst T[]
---@param src T[]
local function append_all(dst, src)
	for i = 1, #src do
		dst[#dst + 1] = src[i]
	end
end

---@param text string?
---@return string
local function compact_json(text)
	text = text or "[]"
	---@type string[]
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

---@return needle.TrieNode
local function trie_new()
	return {children = {}, terminal = false}
end

---@param root needle.TrieNode
---@param word string
local function trie_insert(root, word)
	local node = root
	for i = 1, #word do
		local ch = word:sub(i, i)
		---@type needle.TrieNode?
		local child = node.children[ch]
		if child == nil then
			child = trie_new()
			node.children[ch] = child
		end
		node = child
	end
	node.terminal = true
end

---@param root needle.TrieNode
---@param prefix string
---@return needle.TrieNode?
local function trie_get(root, prefix)
	local node = root
	for i = 1, #prefix do
		---@type needle.TrieNode?
		local child = node.children[prefix:sub(i, i)]
		if child == nil then
			return nil
		end
		node = child
	end
	return node
end

---@param text string
---@param pos integer
---@return integer
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

---@param text string
---@param pos integer
---@return string?, integer
local function json_read_string(text, pos)
	if text:sub(pos, pos) ~= '"' then
		return nil, pos
	end
	---@type string[]
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

---@param text string
---@param key string
---@param start_pos integer?
---@return integer?
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

---@param text string
---@param open_pos integer
---@return integer?
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

---@param text string
---@param open_pos integer
---@param close_pos integer
---@return string[]
local function json_object_keys(text, open_pos, close_pos)
	---@type string[]
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

---@param text string
---@param open_pos integer
---@param close_pos integer
---@param key string
---@return integer?, integer?
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
		---@type integer?
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

---@param text string
---@param open_pos integer
---@param close_pos integer
---@param key string
---@return string?
local function json_string_field(text, open_pos, close_pos, key)
	local value_start = json_object_value_span(text, open_pos, close_pos, key)
	if value_start == nil then
		return nil
	end
	value_start = json_skip_ws(text, value_start)
	local value = json_read_string(text, value_start)
	return value
end

---@param text string
---@param open_pos integer
---@param close_pos integer
---@param key string
---@return boolean?
local function json_bool_field(text, open_pos, close_pos, key)
	local value_start, value_end = json_object_value_span(text, open_pos, close_pos, key)
	if value_start == nil then
		return nil
	end
	local raw = text:sub(value_start, value_end)
	raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
	if raw == "true" then
		return true
	end
	if raw == "false" then
		return false
	end
	return nil
end

---@param text string
---@param open_pos integer
---@param close_pos integer
---@return string[]
local function json_string_array(text, open_pos, close_pos)
	---@type string[]
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

---@param text string
---@param open_pos integer
---@param close_pos integer
---@return needle.PropertySchema
local function parse_property_schema(text, open_pos, close_pos)
	local schema = {}
	schema.type = json_string_field(text, open_pos, close_pos, "type")
	schema.required = json_bool_field(text, open_pos, close_pos, "required")
	local enum_start, enum_end = json_object_value_span(text, open_pos, close_pos, "enum")
	if enum_start ~= nil and enum_end ~= nil and text:sub(enum_start, enum_start) == "[" then
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

---@param text string
---@param props_open integer
---@param props_close integer
---@return needle.PropertySchemas
local function parse_property_schemas(text, props_open, props_close)
	---@type needle.PropertySchemas
	local schemas = {}
	for _, key in ipairs(json_object_keys(text, props_open, props_close)) do
		local value_start, value_end = json_object_value_span(text, props_open, props_close, key)
		if value_start ~= nil and value_end ~= nil and text:sub(value_start, value_start) == "{" then
			schemas[key] = parse_property_schema(text, value_start, value_end)
		else
			schemas[key] = {}
		end
	end
	return schemas
end

---@param tools_json string?
---@return needle.TrieNode name_trie
---@return {[string]: needle.TrieNode} param_tries
---@return {[string]: string[]} param_keys_by_tool
---@return {[string]: needle.PropertySchemas} schemas_by_tool
---@return {[string]: {[string]: true}} required_by_tool
local function parse_tool_constraints(tools_json)
	local name_trie = trie_new()
	---@type {[string]: needle.TrieNode}
	local param_tries = {}
	---@type {[string]: string[]}
	local param_keys_by_tool = {}
	---@type {[string]: needle.PropertySchemas}
	local schemas_by_tool = {}
	---@type {[string]: {[string]: true}}
	local required_by_tool = {}
	tools_json = tools_json or "[]"
	local pos = json_skip_ws(tools_json, 1)
	if tools_json:sub(pos, pos) == "[" then
		pos = pos + 1
	end
	while pos <= #tools_json do
		pos = json_skip_ws(tools_json, pos)
		if tools_json:sub(pos, pos) == "," then
			pos = json_skip_ws(tools_json, pos + 1)
		end
		if tools_json:sub(pos, pos) ~= "{" then
			break
		end
		local tool_end = json_find_matching(tools_json, pos)
		if tool_end == nil then
			break
		end
		local name = json_string_field(tools_json, pos, tool_end, "name")
		if name ~= nil and name ~= "" then
			trie_insert(name_trie, name)
			local param_trie = trie_new()
			---@type needle.PropertySchemas
			local param_schemas = {}
			---@type {[string]: true}
			local required_set = {}
			local params_value, params_end = json_object_value_span(tools_json, pos, tool_end, "parameters")
			if params_value ~= nil and params_end ~= nil then
				params_value = json_skip_ws(tools_json, params_value)
				if tools_json:sub(params_value, params_value) == "{" then
					local required_start, required_end = json_object_value_span(tools_json, params_value, params_end, "required")
					if required_start ~= nil and required_end ~= nil and tools_json:sub(required_start, required_start) == "[" then
						for _, key in ipairs(json_string_array(tools_json, required_start, required_end)) do
							required_set[key] = true
						end
					end
					local props_value, props_end = json_object_value_span(tools_json, params_value, params_end, "properties")
					if props_value ~= nil and props_end ~= nil then
						props_value = json_skip_ws(tools_json, props_value)
						if tools_json:sub(props_value, props_value) == "{" then
							for _, key in ipairs(json_object_keys(tools_json, props_value, props_end)) do
								trie_insert(param_trie, key)
							end
							param_schemas = parse_property_schemas(tools_json, props_value, props_end)
						end
					else
						for _, key in ipairs(json_object_keys(tools_json, params_value, params_end)) do
							trie_insert(param_trie, key)
						end
						param_schemas = parse_property_schemas(tools_json, params_value, params_end)
					end
				end
			end
			for key, schema in pairs(param_schemas) do
				if schema.required then
					required_set[key] = true
				end
			end
			param_tries[name] = param_trie
			---@type string[]
			local param_keys = {}
			for key, _ in pairs(param_schemas) do
				param_keys[#param_keys + 1] = key
			end
			param_keys_by_tool[name] = param_keys
			schemas_by_tool[name] = param_schemas
			required_by_tool[name] = required_set
		end
		pos = tool_end + 1
	end
	return name_trie, param_tries, param_keys_by_tool, schemas_by_tool, required_by_tool
end

---@class needle.ToolCallConstraints
local ToolCallConstraints = {}
ToolCallConstraints.__index = ToolCallConstraints

---@param token_text string
---@param node needle.TrieNode
---@return boolean
local function token_valid_for_node(token_text, node)
	local cur = node
	for i = 1, #token_text do
		local ch = token_text:sub(i, i)
		if ch == '"' then
			return cur.terminal
		end
		---@type needle.TrieNode?
		local child = cur.children[ch]
		if child == nil then
			return false
		end
		cur = child
	end
	return true
end

---@return needle.ConstraintState
local function state_new()
	return {
		state = "free",
		buffer = "",
		constrained_buf = "",
		current_function = "",
		current_arg_key = "",
		value_string_key = "",
		primitive_value_key = "",
		seen_arg_keys = {},
		started = false,
		completed = false,
		in_arguments = false,
		arguments_depth = 0,
		nesting_depth = 0,
		in_string = false,
		prev_char_escape = false,
	}
end

---@param st needle.ConstraintState
---@param key string?
local function state_mark_arg_seen(st, key)
	key = key or st.current_arg_key
	if key ~= nil and key ~= "" and st.in_arguments then
		st.seen_arg_keys[key] = true
	end
	st.current_arg_key = ""
	st.value_string_key = ""
	st.primitive_value_key = ""
	if st.in_arguments then
		st.state = "arg_after_value"
	end
end

---@param st needle.ConstraintState
---@return boolean
local function state_is_value_quote(st)
	for i = #st.buffer - 1, 1, -1 do
		local ch = st.buffer:sub(i, i)
		if ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
			return ch == ":"
		end
	end
	return false
end

---@param st needle.ConstraintState
---@param ch string
---@return boolean
local function state_is_primitive_value_start(st, ch)
	if not st.in_arguments or st.current_arg_key == "" or st.state ~= "free" then
		return false
	end
	if ch == '"' or ch == "{" or ch == "[" then
		return false
	end
	if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
		return false
	end
	return state_is_value_quote(st)
end

---@param st needle.ConstraintState
---@param ch string
---@param schemas_by_tool {[string]: needle.PropertySchemas}
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
			elseif st.state == "arg_value_string" then
				state_mark_arg_seen(st, st.current_arg_key)
			end
			if st.state ~= "arg_after_value" then
				st.state = "free"
			end
			st.constrained_buf = ""
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
			if st.value_string_key ~= "" then
				state_mark_arg_seen(st, st.value_string_key)
			end
		end
		return
	end

	if st.primitive_value_key ~= "" and (ch == "," or ch == "}") then
		state_mark_arg_seen(st, st.primitive_value_key)
	end

	if state_is_primitive_value_start(st, ch) then
		st.primitive_value_key = st.current_arg_key
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
			st.seen_arg_keys = {}
			st.current_arg_key = ""
			st.value_string_key = ""
			st.primitive_value_key = ""
			if st.state == "arg_after_value" then
				st.state = "free"
			end
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
		st.seen_arg_keys = {}
		st.current_arg_key = ""
		st.value_string_key = ""
		st.primitive_value_key = ""
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
			st.value_string_key = st.current_arg_key
		end
	end
end

---@param st needle.ConstraintState
---@param text string
---@param schemas_by_tool {[string]: needle.PropertySchemas}
local function state_feed(st, text, schemas_by_tool)
	for i = 1, #text do
		state_feed_char(st, text:sub(i, i), schemas_by_tool)
	end
end

---@param tokenizer needle.Tokenizer
---@return {[integer]: string}
---@return {[string]: integer[]}
local function build_token_data(tokenizer)
	if tokenizer._token_strings ~= nil then
		return tokenizer._token_strings, tokenizer._token_index
	end
	---@type {[integer]: string}
	local strings = {}
	---@type {[string]: integer[]}
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

---@param keys string[]?
---@param seen {[string]: true}?
---@return needle.TrieNode
---@return integer
local function trie_from_keys(keys, seen)
	local trie = trie_new()
	local count = 0
	for _, key in ipairs(keys or {}) do
		if not (seen and seen[key]) then
			trie_insert(trie, key)
			count = count + 1
		end
	end
	return trie, count
end

---@param required {[string]: true}?
---@param seen {[string]: true}?
---@return boolean
local function required_satisfied(required, seen)
	for key, needed in pairs(required or {}) do
		if needed and not (seen and seen[key]) then
			return false
		end
	end
	return true
end

---@param keys string[]?
---@param seen {[string]: true}?
---@return boolean
local function has_unseen_key(keys, seen)
	for _, key in ipairs(keys or {}) do
		if not (seen and seen[key]) then
			return true
		end
	end
	return false
end

---@param token_text string
---@param allowed_first {[string]: true}
---@return boolean
local function token_starts_with_any(token_text, allowed_first)
	local first = token_text:sub(1, 1)
	return allowed_first[first] == true
end

---@param tools_json string
---@param tokenizer needle.Tokenizer?
---@param opts needle.Options?
---@return needle.ToolCallConstraints?, needle.Error?, integer?
function M.build_tool_call_constraints(tools_json, tokenizer, opts)
	if tokenizer == nil then
		return nil, error_table(M.errors.INVALID_ARGUMENT, "tool-call constraints require a tokenizer"), M.errors.INVALID_ARGUMENT
	end
	opts = opts or {}
	local token_strings, token_index = build_token_data(tokenizer)
	local name_trie, param_tries, param_keys_by_tool, schemas_by_tool, required_by_tool = parse_tool_constraints(tools_json or "[]")
	local constraints = setmetatable({
		_state = state_new(),
		_seen = 0,
		_token_strings = token_strings,
		_token_index = token_index,
		_name_trie = name_trie,
		_param_tries = param_tries,
		_param_keys_by_tool = param_keys_by_tool,
		_schemas_by_tool = schemas_by_tool,
		_required_by_tool = required_by_tool,
		_eos_token_id = opts.eos_token_id or 1,
	}, ToolCallConstraints) --[[@as needle.ToolCallConstraints]]
	return constraints
end

---@param id integer
function ToolCallConstraints:feed_token(id)
	state_feed(self._state, self._token_strings[id] or "", self._schemas_by_tool)
end

---@param tokens integer[]
function ToolCallConstraints:sync(tokens)
	for i = self._seen + 1, #tokens do
		self:feed_token(tokens[i])
	end
	self._seen = #tokens
end

---@param tokens ffi.cdata*
---@param token_count integer
function ToolCallConstraints:sync_c(tokens, token_count)
	for i = self._seen, token_count - 1 do
		self:feed_token(assert(tonumber(tokens[i])))
	end
	self._seen = token_count
end

---@return integer[]?
function ToolCallConstraints:allowed_token_ids()
	local st = self._state
	if st.completed then
		return {self._eos_token_id}
	end
	---@type needle.TrieNode?
	local trie
	if st.state == "name" then
		trie = self._name_trie
	elseif st.state == "arg_key" then
		local keys = self._param_keys_by_tool[st.current_function]
		if keys ~= nil then
			local count
			trie, count = trie_from_keys(keys, st.seen_arg_keys)
			if count == 0 then
				return {self._eos_token_id}
			end
		else
			trie = self._param_tries[st.current_function]
		end
	elseif st.state == "arg_value_string" then
		local schema = self._schemas_by_tool
			and self._schemas_by_tool[st.current_function]
			and self._schemas_by_tool[st.current_function][st.current_arg_key]
			or nil
		trie = schema and schema.enum_trie or nil
	elseif st.state == "arg_after_value" then
		local keys = self._param_keys_by_tool[st.current_function] or {}
		local required = self._required_by_tool[st.current_function] or {}
		---@type {[string]: true}
		local allowed_first = {}
		if has_unseen_key(keys, st.seen_arg_keys) then
			allowed_first[","] = true
		end
		if required_satisfied(required, st.seen_arg_keys) then
			allowed_first["}"] = true
		end
		---@type integer[]
		local allowed = {}
		for first, _ in pairs(allowed_first) do
			local bucket = self._token_index[first]
			if bucket ~= nil then
				for _, id in ipairs(bucket) do
					if token_starts_with_any(self._token_strings[id], allowed_first) then
						allowed[#allowed + 1] = id
					end
				end
			end
		end
		if #allowed == 0 then
			return {self._eos_token_id}
		end
		return allowed
	else
		return nil
	end
	if trie == nil then
		return {self._eos_token_id}
	end
	local node = trie_get(trie, st.constrained_buf)
	if node == nil then
		return {self._eos_token_id}
	end

	---@type integer[]
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
		return {self._eos_token_id}
	end
	return allowed
end

---@return fun(step: integer, tokens: integer[], logits: ffi.cdata*, vocab_size: integer): integer[]?
function ToolCallConstraints:token_filter()
	return function(_, tokens)
		self:sync(tokens)
		return self:allowed_token_ids()
	end
end

---@return fun(step: integer, tokens: ffi.cdata*, token_count: integer, logits: ffi.cdata*, vocab_size: integer): integer[]?
function ToolCallConstraints:token_filter_raw()
	return function(_, tokens, token_count)
		self:sync_c(tokens, assert(tonumber(token_count)))
		return self:allowed_token_ids()
	end
end

---@param tokenizer needle.Tokenizer
---@param query string
---@param tools_json string
---@param opts needle.Options?
---@return integer[]
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
		---@type integer[]
		local trimmed = {}
		for i = 1, max_query do trimmed[i] = q_ids[i] end
		q_ids = trimmed
	end

	local remaining = max_enc_len - #q_ids - 1
	---@type integer[]
	local input = {}
	append_all(input, q_ids)
	input[#input + 1] = tools_token_id
	for i = 1, math.min(#tool_ids, remaining) do
		input[#input + 1] = tool_ids[i]
	end
	return input
end

---@param text string
---@return string
local function trim_leading_whitespace(text)
	return (text:gsub("^%s+", ""))
end

---@param query string
---@param tools_json string
---@param opts needle.Options?
function Context:generate(query, tools_json, opts)
	ensure_open(self)
	opts = opts or {}
	if opts.compact_tools_json ~= false then
		tools_json = compact_json(tools_json or "[]")
	end

	local tokenizer = opts.tokenizer
	local owns_tokenizer = false
	if tokenizer == nil and opts.tokenizer_path then
		local tok, tok_err = M.load_tokenizer(opts.tokenizer_path, {lib = opts.lib})
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
	local prompt_ids = opts.prompt_ids or {opts.eos_token_id or 1}
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
				---@type {[integer]: true}
				local seen = {}
				for _, id in ipairs(a) do seen[id] = true end
				---@type integer[]
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
				---@type {[integer]: true}
				local seen = {}
				for _, id in ipairs(a) do seen[id] = true end
				---@type integer[]
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

		local encoder_state, enc_err, enc_rc = self:encode_tokens_state(src_ids, {
			on_progress = opts.on_prefill_progress,
		})
		if not encoder_state then
			if owns_tokenizer then tokenizer:close() end
			return nil, enc_err, enc_rc
		end

		---@type integer[]
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
			local chunk, chunk_err, chunk_rc = tokenizer:token_text(token_id, {out_cap = opts.token_text_cap or 256})
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
		local text, dec_err, dec_rc = tokenizer:decode(result_ids, {out_cap = opts.out_cap or 8192})
		if owns_tokenizer then tokenizer:close() end
		if not text then
			return nil, dec_err, dec_rc
		end
		if opts.strip_tool_call ~= false and text:sub(1, 11) == "<tool_call>" then
			text = text:sub(12)
			text = trim_leading_whitespace(text)
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

	---@type integer[]
	local result_ids = {}
	for i = #prompt_ids + 1, #generated do
		local id = generated[i]
		if id == eos_token_id then
			break
		end
		result_ids[#result_ids + 1] = id
	end
	local text, dec_err, dec_rc = tokenizer:decode(result_ids, {out_cap = opts.out_cap or 8192})
	if owns_tokenizer then tokenizer:close() end
	if not text then
		return nil, dec_err, dec_rc
	end
	if opts.strip_tool_call ~= false and text:sub(1, 11) == "<tool_call>" then
		text = text:sub(12)
		text = trim_leading_whitespace(text)
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

function Context:createTokenizer()
	ensure_open(self)
	local tok = load_lib().needle_tokenizer_from_context(self._ctx)
	if tok == nil then
		return nil, context_error(self)
	end
	local tokenizer = setmetatable({_tok = tok}, Tokenizer)
	local err = tokenizer:last_error_info()
	if err.code ~= M.errors.OK or err.message ~= "" then
		return tokenizer, err
	end
	return tokenizer
end

function Context:__gc()
	self:close()
end

---@param model_path string
---@param opts needle.Options?
---@return needle.Context?, needle.Error?
function M.load(model_path, opts)
	opts = opts or {}
	local runtime = load_lib(opts.lib)
	local ctx = runtime.needle_load(model_path or "")
	if ctx == nil then
		return nil, error_table(M.errors.NULL_CONTEXT, "needle_load returned null")
	end

	local self = setmetatable({_ctx = ctx}, Context)
	local err = self:last_error_info()
	if err.code ~= M.errors.OK or err.message ~= "" then
		return self, err
	end
	return self
end

---@param opts needle.Options?
---@return string
function M.version(opts)
	local runtime = load_lib(opts and opts.lib or nil)
	return ffi.string(runtime.needle_version())
end

---@param a integer
---@param b integer
---@param opts needle.Options?
---@return integer
function M.probe_add(a, b, opts)
	local runtime = load_lib(opts and opts.lib or nil)
	return assert(tonumber(runtime.needle_probe_add(a, b)))
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

---@param text string
---@param opts needle.Options?
---@return integer[]?, needle.Error?, integer?
function Tokenizer:encode(text, opts)
	ensure_tokenizer_open(self)
	opts = opts or {}
	local cap = opts.cap or 2048
	local ids = ffi.new("int[?]", cap) --[[@as needle.IntBuffer]]
	local n = load_lib().needle_tokenizer_encode(self._tok, text or "", ids, cap)
	if n < 0 then
		return nil, tokenizer_error(self, n), n
	end
	---@type integer[]
	local out = {}
	for i = 0, n - 1 do
		out[#out + 1] = tonumber(ids[i])
	end
	return out
end

---@param ids integer[]
---@param opts needle.Options?
---@return string?, needle.Error?, integer?
function Tokenizer:decode(ids, opts)
	ensure_tokenizer_open(self)
	opts = opts or {}
	local out_cap = opts.out_cap or 4096
	local c_ids = ffi.new("int[?]", #ids) --[[@as needle.IntBuffer]]
	for i = 1, #ids do
		c_ids[i - 1] = ids[i]
	end
	local out = ffi.new("char[?]", out_cap) --[[@as needle.CharBuffer]]
	local n = load_lib().needle_tokenizer_decode(self._tok, c_ids, #ids, out, out_cap)
	if n < 0 then
		return nil, tokenizer_error(self, n), n
	end
	return ffi.string(out, n)
end

---@param id integer
---@param opts needle.Options?
---@return string?, needle.Error?, integer?
function Tokenizer:token_text(id, opts)
	ensure_tokenizer_open(self)
	opts = opts or {}
	local out_cap = opts.out_cap or 256
	local out = ffi.new("char[?]", out_cap) --[[@as needle.CharBuffer]]
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

---@param path string
---@param opts needle.Options?
---@return needle.Tokenizer?, needle.Error?
function M.load_tokenizer(path, opts)
	opts = opts or {}
	local runtime = load_lib(opts.lib)
	local tok = runtime.needle_tokenizer_load(path or "")
	if tok == nil then
		return nil, error_table(M.errors.NULL_CONTEXT, "needle_tokenizer_load returned null")
	end
	local self = setmetatable({_tok = tok}, Tokenizer)
	local err = self:last_error_info()
	if err.code ~= M.errors.OK or err.message ~= "" then
		return self, err
	end
	return self
end

M.kernels = {}

---@param values number[]
---@param n integer
---@return needle.FloatBuffer
local function float_array(values, n)
	local arr = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	for i = 1, n do arr[i - 1] = values[i] or 0 end
	return arr
end

---@param mask (boolean|integer)[]?
---@param n integer
---@return needle.ByteBuffer?
local function mask_array(mask, n)
	if not mask then return nil end
	local arr = ffi.new("unsigned char[?]", n) --[[@as needle.ByteBuffer]]
	for i = 1, n do
		local v = mask[i]
		arr[i - 1] = (v == true or v == 1) and 1 or 0
	end
	return arr
end

---@param arr needle.FloatBuffer
---@param n integer
---@return number[]
local function table_from_float_array(arr, n)
	---@type number[]
	local result = {}
	for i = 0, n - 1 do result[#result + 1] = tonumber(arr[i]) end
	return result
end

---@param x number[]
---@param scale number[]
---@param rows integer
---@param cols integer
---@param epsilon number?
---@return number[]?, needle.Error?, integer?
function M.kernels.zcrmsnorm(x, scale, rows, cols, epsilon)
	local runtime = load_lib()
	local n = rows * cols
	local cx = float_array(x, n)
	local cscale = float_array(scale, cols)
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local rc = runtime.needle_kernel_zcrmsnorm_f32(cx, cscale, out, rows, cols, epsilon or 1e-6)
	if rc ~= 0 then
		return nil, error_table(rc, "zcrmsnorm failed"), rc
	end
	return table_from_float_array(out, n)
end

---@param x number[]
---@param num_heads integer
---@param seq_len integer
---@param head_dim integer
---@param theta number?
---@return number[]?, needle.Error?, integer?
function M.kernels.rope(x, num_heads, seq_len, head_dim, theta)
	local runtime = load_lib()
	local n = num_heads * seq_len * head_dim
	local cx = float_array(x, n)
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local rc = runtime.needle_kernel_rope_f32(cx, out, num_heads, seq_len, head_dim, theta or 10000.0, 0)
	if rc ~= 0 then
		return nil, error_table(rc, "rope failed"), rc
	end
	return table_from_float_array(out, n)
end

---@param a number[]
---@param b number[]
---@param m integer
---@param k integer
---@param n integer
---@param bias number[]?
---@return number[]?, needle.Error?, integer?
function M.kernels.matmul(a, b, m, k, n, bias)
	local runtime = load_lib()
	local ca = float_array(a, m * k)
	local cb = float_array(b, k * n)
	local cbias = bias and float_array(bias, n) or nil
	local out = ffi.new("float[?]", m * n) --[[@as needle.FloatBuffer]]
	local rc = runtime.needle_kernel_matmul_f32(ca, cb, cbias, out, m, k, n)
	if rc ~= 0 then
		return nil, error_table(rc, "matmul failed"), rc
	end
	return table_from_float_array(out, m * n)
end

---@param x number[]
---@param rows integer
---@param cols integer
---@param mask (boolean|integer)[]?
---@return number[]?, needle.Error?, integer?
function M.kernels.softmax(x, rows, cols, mask)
	local runtime = load_lib()
	local n = rows * cols
	local cx = float_array(x, n)
	local cmask = mask_array(mask, n)
	local out = ffi.new("float[?]", n) --[[@as needle.FloatBuffer]]
	local rc = runtime.needle_kernel_softmax_f32(cx, cmask, out, rows, cols)
	if rc ~= 0 then
		return nil, error_table(rc, "softmax failed"), rc
	end
	return table_from_float_array(out, n)
end

---@param q number[]
---@param k_values number[]
---@param v number[]
---@param q_len integer
---@param kv_len integer
---@param head_dim integer
---@param mask (boolean|integer)[]?
---@return number[]?, needle.Error?, integer?
function M.kernels.attention(q, k_values, v, q_len, kv_len, head_dim, mask)
	local runtime = load_lib()
	local qn = q_len * head_dim
	local kvn = kv_len * head_dim
	local cq = float_array(q, qn)
	local ck = float_array(k_values, kvn)
	local cv = float_array(v, kvn)
	local cmask = mask_array(mask, q_len * kv_len)
	local out = ffi.new("float[?]", qn) --[[@as needle.FloatBuffer]]
	local rc = runtime.needle_kernel_attention_f32(cq, ck, cv, cmask, out, q_len, kv_len, head_dim)
	if rc ~= 0 then
		return nil, error_table(rc, "attention failed"), rc
	end
	return table_from_float_array(out, qn)
end

return M
