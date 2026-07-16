#ifndef NEEDLE_RUNTIME_H
#define NEEDLE_RUNTIME_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(NEEDLE_RUNTIME_BUILD)
#    define NEEDLE_API __declspec(dllexport)
#  else
#    define NEEDLE_API __declspec(dllimport)
#  endif
#else
#  define NEEDLE_API __attribute__((visibility("default")))
#endif

#define NEEDLE_ABI_VERSION 5

#define NEEDLE_OK 0
#define NEEDLE_ERR_NULL_CONTEXT -1
#define NEEDLE_ERR_INVALID_ARGUMENT -2
#define NEEDLE_ERR_NOT_LOADED -3
#define NEEDLE_ERR_IO -4
#define NEEDLE_ERR_FORMAT -5
#define NEEDLE_ERR_UNSUPPORTED -6
#define NEEDLE_ERR_OUT_OF_MEMORY -7
#define NEEDLE_ERR_NOT_IMPLEMENTED -8

#define NEEDLE_DTYPE_F32 1
#define NEEDLE_DTYPE_F16 2
#define NEEDLE_DTYPE_BF16 3
#define NEEDLE_DTYPE_I8 4
#define NEEDLE_DTYPE_I32 5
#define NEEDLE_DTYPE_U8 6

typedef struct needle_ctx needle_ctx;
typedef struct needle_kv_cache needle_kv_cache;
typedef struct needle_encoder_state needle_encoder_state;
typedef struct needle_tokenizer needle_tokenizer;
typedef int (*needle_stream_callback)(const char *chunk, int chunk_len, void *user_data);
typedef int (*needle_token_callback)(
    int token_id,
    int step,
    const int *tokens,
    int token_count,
    void *user_data);
typedef int (*needle_token_filter_callback)(
    int step,
    const int *tokens,
    int token_count,
    const float *logits,
    int vocab_size,
    int *allowed_ids,
    int allowed_cap,
    void *user_data);

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

NEEDLE_API int needle_abi_version(void);
NEEDLE_API const char *needle_version(void);
NEEDLE_API int needle_probe_add(int a, int b);
NEEDLE_API void needle_runtime_reset_memory_stats(void);
NEEDLE_API unsigned long long needle_runtime_aligned_alloc_count(void);
NEEDLE_API unsigned long long needle_runtime_aligned_alloc_total_bytes(void);
NEEDLE_API unsigned long long needle_runtime_aligned_alloc_active_count(void);
NEEDLE_API unsigned long long needle_runtime_aligned_alloc_current_bytes(void);
NEEDLE_API unsigned long long needle_runtime_aligned_alloc_peak_bytes(void);
NEEDLE_API unsigned long long needle_runtime_dense_q8_projection_count(void);
NEEDLE_API unsigned long long needle_runtime_dense_float_projection_count(void);
NEEDLE_API unsigned long long needle_runtime_dense_q8_fallback_count(void);
NEEDLE_API unsigned long long needle_runtime_output_q8_projection_count(void);
NEEDLE_API unsigned long long needle_runtime_output_float_projection_count(void);
NEEDLE_API unsigned long long needle_runtime_output_q8_fallback_count(void);

NEEDLE_API needle_ctx *needle_load(const char *model_path);
NEEDLE_API void needle_free(needle_ctx *ctx);
NEEDLE_API const char *needle_last_error(needle_ctx *ctx);
NEEDLE_API int needle_last_error_code(needle_ctx *ctx);
NEEDLE_API void needle_clear_error(needle_ctx *ctx);
NEEDLE_API int needle_is_loaded(needle_ctx *ctx);
NEEDLE_API unsigned long long needle_tensor_count(needle_ctx *ctx);
NEEDLE_API unsigned long long needle_tensor_data_bytes(needle_ctx *ctx);
NEEDLE_API unsigned long long needle_tokenizer_bytes(needle_ctx *ctx);
NEEDLE_API needle_tokenizer *needle_tokenizer_from_context(needle_ctx *ctx);
NEEDLE_API const char *needle_metadata_json(needle_ctx *ctx);
NEEDLE_API const needle_config *needle_get_config(needle_ctx *ctx);
NEEDLE_API const char *needle_tensor_name(needle_ctx *ctx, unsigned long long index);
NEEDLE_API int needle_tensor_dtype(needle_ctx *ctx, unsigned long long index);
NEEDLE_API int needle_tensor_ndim(needle_ctx *ctx, unsigned long long index);
NEEDLE_API unsigned long long needle_tensor_dim(needle_ctx *ctx, unsigned long long index, int dim);
NEEDLE_API unsigned long long needle_tensor_nbytes(needle_ctx *ctx, unsigned long long index);
NEEDLE_API long long needle_find_tensor(needle_ctx *ctx, const char *name);
NEEDLE_API int needle_embedding_lookup(needle_ctx *ctx, int token_id, float *out, int out_cap);
NEEDLE_API int needle_encoder_self_attention_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_encoder_block_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_output_projection_f32(
    needle_ctx *ctx,
    const float *x,
    int seq_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_encode_tokens_f32(
    needle_ctx *ctx,
    const int *token_ids,
    int seq_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_decoder_self_attention_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    int causal,
    float *out,
    int out_cap);
NEEDLE_API int needle_decoder_self_attention_cached_step_f32(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int layer,
    const float *x,
    float *out,
    int out_cap);
NEEDLE_API int needle_decoder_cross_attention_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_decoder_block_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_decoder_block_cached_step_f32(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int layer,
    const float *x,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_decode_tokens_f32(
    needle_ctx *ctx,
    const int *token_ids,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_decode_token_cached_step_f32(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int token_id,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap);
NEEDLE_API int needle_forward_logits_f32(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    const int *tgt_ids,
    int tgt_len,
    float *out,
    int out_cap);
NEEDLE_API needle_encoder_state *needle_encoder_state_create(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len);
NEEDLE_API void needle_encoder_state_free(needle_encoder_state *state);
NEEDLE_API int needle_encoder_state_len(needle_encoder_state *state);
NEEDLE_API int needle_encoder_state_d_model(needle_encoder_state *state);
NEEDLE_API needle_kv_cache *needle_kv_cache_create(needle_ctx *ctx, int max_tokens);
NEEDLE_API void needle_kv_cache_free(needle_kv_cache *cache);
NEEDLE_API int needle_kv_cache_reset(needle_kv_cache *cache);
NEEDLE_API int needle_kv_cache_set_token_count(needle_kv_cache *cache, int token_count);
NEEDLE_API int needle_kv_cache_token_count(needle_kv_cache *cache);
NEEDLE_API int needle_kv_cache_max_tokens(needle_kv_cache *cache);
NEEDLE_API int needle_kv_cache_layer_count(needle_kv_cache *cache);
NEEDLE_API int needle_kv_cache_kv_heads(needle_kv_cache *cache);
NEEDLE_API int needle_kv_cache_head_dim(needle_kv_cache *cache);
NEEDLE_API unsigned long long needle_kv_cache_bytes(needle_kv_cache *cache);
NEEDLE_API int needle_generate_tokens_greedy(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    const int *prompt_ids,
    int prompt_len,
    int max_new_tokens,
    int eos_token_id,
    int *out_ids,
    int out_cap);
NEEDLE_API int needle_generate_tokens_greedy_filtered(
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
    int out_cap);
NEEDLE_API int needle_generate_tokens_greedy_cached(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    const int *prompt_ids,
    int prompt_len,
    int max_new_tokens,
    int eos_token_id,
    int *out_ids,
    int out_cap);
NEEDLE_API int needle_generate_tokens_greedy_cached_filtered(
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
    int out_cap);
NEEDLE_API int needle_generate_tokens_greedy_cached_from_encoder_filtered(
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
    int out_cap);
NEEDLE_API int needle_generate_tokens_greedy_cached_from_state_filtered(
    needle_ctx *ctx,
    needle_encoder_state *state,
    const int *prompt_ids,
    int prompt_len,
    int max_new_tokens,
    int eos_token_id,
    needle_token_filter_callback filter,
    void *user_data,
    int *out_ids,
    int out_cap);
NEEDLE_API int needle_generate_tokens_greedy_cached_from_state_stream_filtered(
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
    int out_cap);

NEEDLE_API int needle_generate(
    needle_ctx *ctx,
    const char *query,
    const char *tools_json,
    char *out,
    int out_cap);

NEEDLE_API int needle_generate_stream(
    needle_ctx *ctx,
    const char *query,
    const char *tools_json,
    needle_stream_callback callback,
    void *user_data);

#ifdef __cplusplus
}
#endif

#endif
