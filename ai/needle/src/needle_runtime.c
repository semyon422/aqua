#include "needle_runtime.h"
#include "needle_tokenizer.h"

#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#if defined(__x86_64__) || defined(__i386__)
#include <immintrin.h>
#endif

#define NEEDLE_ERROR_CAP 256
#define NEEDLE_MAGIC "NDLRTM1"
#define NEEDLE_MAGIC_SIZE 8
#define NEEDLE_FORMAT_VERSION 1
#define NEEDLE_MAX_NDIM 32
#define NEEDLE_ALIGNMENT 64
#define NEEDLE_ALLOC_HEADER_SLOTS 2

typedef struct needle_tensor {
    char *name;
    uint16_t dtype;
    uint32_t ndim;
    uint64_t shape[NEEDLE_MAX_NDIM];
    uint64_t nbytes;
    unsigned char *data;
    float *f32_data;
    uint64_t f32_count;
    struct needle_tensor *q8_tensor;
    struct needle_tensor *q8_scale_tensor;
} needle_tensor;

struct needle_ctx {
    char *model_path;
    char *metadata_json;
    needle_tensor *tensors;
    needle_config config;
    uint64_t tensor_count;
    uint64_t tensor_data_bytes;
    uint64_t tokenizer_bytes;
    unsigned char *tokenizer_data;
    int loaded;
    int last_error_code;
    char last_error[NEEDLE_ERROR_CAP];
};

struct needle_kv_cache {
    needle_ctx *ctx;
    int max_tokens;
    int token_count;
    int layers;
    int kv_heads;
    int head_dim;
    int kv_dim;
    unsigned long long bytes;
    float *self_k;
    float *self_v;
};

struct needle_encoder_state {
    needle_ctx *ctx;
    int enc_len;
    int d_model;
    float *encoder_out;
};

static unsigned long long g_aligned_alloc_count = 0;
static unsigned long long g_aligned_alloc_total_bytes = 0;
static unsigned long long g_aligned_alloc_active_count = 0;
static unsigned long long g_aligned_alloc_current_bytes = 0;
static unsigned long long g_aligned_alloc_peak_bytes = 0;
static unsigned long long g_dense_q8_projection_count = 0;
static unsigned long long g_dense_float_projection_count = 0;
static unsigned long long g_dense_q8_fallback_count = 0;
static unsigned long long g_output_q8_projection_count = 0;
static unsigned long long g_output_float_projection_count = 0;
static unsigned long long g_output_q8_fallback_count = 0;

enum {
    NEEDLE_PROFILE_ENCODER_EMBEDDING = 0,
    NEEDLE_PROFILE_ENCODER_BLOCK_NORM,
    NEEDLE_PROFILE_ENCODER_Q_PROJ,
    NEEDLE_PROFILE_ENCODER_K_PROJ,
    NEEDLE_PROFILE_ENCODER_V_PROJ,
    NEEDLE_PROFILE_ENCODER_QK_NORM_ROPE,
    NEEDLE_PROFILE_ENCODER_ATTENTION_SCORES,
    NEEDLE_PROFILE_ENCODER_ATTENTION_VALUES,
    NEEDLE_PROFILE_ENCODER_OUT_PROJ,
    NEEDLE_PROFILE_ENCODER_BLOCK_RESIDUAL,
    NEEDLE_PROFILE_ENCODER_FINAL_NORM,
    NEEDLE_PROFILE_COUNT
};

static int g_profile_enabled = 0;
static unsigned long long g_profile_ns[NEEDLE_PROFILE_COUNT] = {0};

static unsigned long long profile_now_ns(void) {
#if defined(CLOCK_MONOTONIC)
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0) {
        return (unsigned long long)ts.tv_sec * 1000000000ULL + (unsigned long long)ts.tv_nsec;
    }
#endif
    return (unsigned long long)((double)clock() * (1000000000.0 / (double)CLOCKS_PER_SEC));
}

static unsigned long long profile_start(void) {
    return g_profile_enabled ? profile_now_ns() : 0ULL;
}

static void profile_end(int counter, unsigned long long start) {
    if (start && counter >= 0 && counter < NEEDLE_PROFILE_COUNT) {
        g_profile_ns[counter] += profile_now_ns() - start;
    }
}

static void set_error(needle_ctx *ctx, int code, const char *message) {
    if (!ctx) {
        return;
    }
    ctx->last_error_code = code;
    if (!message) {
        ctx->last_error[0] = '\0';
        return;
    }
    snprintf(ctx->last_error, sizeof(ctx->last_error), "%s", message);
}

static void *aligned_alloc_bytes(size_t bytes, int zero) {
    if (bytes == 0) {
        bytes = 1;
    }
    size_t header_bytes = NEEDLE_ALLOC_HEADER_SLOTS * sizeof(uintptr_t);
    if (bytes > SIZE_MAX - NEEDLE_ALIGNMENT - header_bytes) {
        return NULL;
    }
    void *raw = malloc(bytes + NEEDLE_ALIGNMENT - 1U + header_bytes);
    if (!raw) {
        return NULL;
    }
    uintptr_t start = (uintptr_t)raw + header_bytes;
    uintptr_t aligned = (start + (uintptr_t)NEEDLE_ALIGNMENT - 1U) & ~((uintptr_t)NEEDLE_ALIGNMENT - 1U);
    uintptr_t *header = (uintptr_t *)aligned;
    header[-2] = (uintptr_t)raw;
    header[-1] = (uintptr_t)bytes;
    if (zero) {
        memset((void *)aligned, 0, bytes);
    }
    g_aligned_alloc_count++;
    g_aligned_alloc_total_bytes += (unsigned long long)bytes;
    g_aligned_alloc_active_count++;
    g_aligned_alloc_current_bytes += (unsigned long long)bytes;
    if (g_aligned_alloc_current_bytes > g_aligned_alloc_peak_bytes) {
        g_aligned_alloc_peak_bytes = g_aligned_alloc_current_bytes;
    }
    return (void *)aligned;
}

static void aligned_free(void *ptr) {
    if (ptr) {
        uintptr_t *header = (uintptr_t *)ptr;
        unsigned long long bytes = (unsigned long long)header[-1];
        void *raw = (void *)header[-2];
        if (g_aligned_alloc_active_count > 0) {
            g_aligned_alloc_active_count--;
        }
        if (g_aligned_alloc_current_bytes >= bytes) {
            g_aligned_alloc_current_bytes -= bytes;
        } else {
            g_aligned_alloc_current_bytes = 0;
        }
        free(raw);
    }
}

static float *alloc_floats(size_t count) {
    if (count > SIZE_MAX / sizeof(float)) {
        return NULL;
    }
    return (float *)aligned_alloc_bytes(count * sizeof(float), 0);
}

static float *calloc_floats(size_t count) {
    if (count > SIZE_MAX / sizeof(float)) {
        return NULL;
    }
    return (float *)aligned_alloc_bytes(count * sizeof(float), 1);
}

static float dot_f32_scalar(const float *a, const float *b, int n) {
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
        sum += (double)a[i] * (double)b[i];
    }
    return (float)sum;
}

#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
__attribute__((target("avx2,fma")))
static float dot_f32_avx2_fma(const float *a, const float *b, int n) {
    __m256 acc = _mm256_setzero_ps();
    int i = 0;
    for (; i + 8 <= n; i += 8) {
        __m256 av = _mm256_loadu_ps(a + i);
        __m256 bv = _mm256_loadu_ps(b + i);
        acc = _mm256_fmadd_ps(av, bv, acc);
    }
    __m128 lo = _mm256_castps256_ps128(acc);
    __m128 hi = _mm256_extractf128_ps(acc, 1);
    __m128 sum = _mm_add_ps(lo, hi);
    sum = _mm_add_ps(sum, _mm_movehl_ps(sum, sum));
    sum = _mm_add_ss(sum, _mm_shuffle_ps(sum, sum, 0x55));
    float out = _mm_cvtss_f32(sum);
    for (; i < n; i++) {
        out += a[i] * b[i];
    }
    return out;
}

static int cpu_has_avx2_fma(void) {
    static int cached = -1;
    if (cached < 0) {
        cached = (__builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma")) ? 1 : 0;
    }
    return cached;
}
#else
static int cpu_has_avx2_fma(void) {
    return 0;
}
#endif

static float dot_f32(const float *a, const float *b, int n) {
#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
    if (cpu_has_avx2_fma()) {
        return dot_f32_avx2_fma(a, b, n);
    }
#endif
    return dot_f32_scalar(a, b, n);
}

static float attention_dot(const float *q, const float *k, size_t q_off, size_t k_off, int head_dim) {
    return dot_f32(q + q_off, k + k_off, head_dim);
}

static void scale_f32_scalar(float *dst, float scale, int n) {
    for (int i = 0; i < n; i++) {
        dst[i] *= scale;
    }
}

#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
__attribute__((target("avx2")))
static void scale_f32_avx2(float *dst, float scale, int n) {
    __m256 sv = _mm256_set1_ps(scale);
    int i = 0;
    for (; i + 16 <= n; i += 16) {
        __m256 a = _mm256_loadu_ps(dst + i);
        __m256 b = _mm256_loadu_ps(dst + i + 8);
        _mm256_storeu_ps(dst + i, _mm256_mul_ps(a, sv));
        _mm256_storeu_ps(dst + i + 8, _mm256_mul_ps(b, sv));
    }
    for (; i + 8 <= n; i += 8) {
        __m256 a = _mm256_loadu_ps(dst + i);
        _mm256_storeu_ps(dst + i, _mm256_mul_ps(a, sv));
    }
    for (; i < n; i++) {
        dst[i] *= scale;
    }
}
#endif

static void scale_f32(float *dst, float scale, int n) {
#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
    if (cpu_has_avx2_fma() && n >= 8) {
        scale_f32_avx2(dst, scale, n);
        return;
    }
#endif
    scale_f32_scalar(dst, scale, n);
}

static double attention_values_row_scalar(
    float *dst,
    const float *v,
    const float *scores,
    float max_score,
    int seq_len,
    int kv_heads,
    int kh,
    int head_dim) {
    double denom = 0.0;
    for (int tk = 0; tk < seq_len; tk++) {
        float weight = expf(scores[tk] - max_score);
        denom += (double)weight;
        const float *vv = v + ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
        for (int d = 0; d < head_dim; d++) {
            dst[d] += weight * vv[d];
        }
    }
    return denom;
}

#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
__attribute__((target("avx2,fma")))
static double attention_values_row_avx2_fma(
    float *dst,
    const float *v,
    const float *scores,
    float max_score,
    int seq_len,
    int kv_heads,
    int kh,
    int head_dim) {
    double denom = 0.0;
    for (int tk = 0; tk < seq_len; tk++) {
        float weight = expf(scores[tk] - max_score);
        denom += (double)weight;
        __m256 wv = _mm256_set1_ps(weight);
        const float *vv = v + ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
        int d = 0;
        for (; d + 16 <= head_dim; d += 16) {
            __m256 a = _mm256_loadu_ps(dst + d);
            __m256 b = _mm256_loadu_ps(dst + d + 8);
            __m256 x = _mm256_loadu_ps(vv + d);
            __m256 y = _mm256_loadu_ps(vv + d + 8);
            _mm256_storeu_ps(dst + d, _mm256_fmadd_ps(wv, x, a));
            _mm256_storeu_ps(dst + d + 8, _mm256_fmadd_ps(wv, y, b));
        }
        for (; d + 8 <= head_dim; d += 8) {
            __m256 a = _mm256_loadu_ps(dst + d);
            __m256 x = _mm256_loadu_ps(vv + d);
            _mm256_storeu_ps(dst + d, _mm256_fmadd_ps(wv, x, a));
        }
        for (; d < head_dim; d++) {
            dst[d] += weight * vv[d];
        }
    }
    return denom;
}
#endif

static double attention_values_row(
    float *dst,
    const float *v,
    const float *scores,
    float max_score,
    int seq_len,
    int kv_heads,
    int kh,
    int head_dim) {
#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
    if (cpu_has_avx2_fma() && head_dim >= 8) {
        return attention_values_row_avx2_fma(dst, v, scores, max_score, seq_len, kv_heads, kh, head_dim);
    }
#endif
    return attention_values_row_scalar(dst, v, scores, max_score, seq_len, kv_heads, kh, head_dim);
}

static float projection_col_dot_scalar(const float *src, const float *weights_col, int in_dim, int out_dim) {
    double sum = 0.0;
    for (int i = 0; i < in_dim; i++) {
        sum += (double)src[i] * (double)weights_col[(size_t)i * (size_t)out_dim];
    }
    return (float)sum;
}

#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
__attribute__((target("avx2,fma")))
static float projection_col_dot_avx2_fma(const float *src, const float *weights_col, int in_dim, int out_dim) {
    __m256d acc0 = _mm256_setzero_pd();
    __m256d acc1 = _mm256_setzero_pd();
    int i = 0;
    int stride = out_dim;
    for (; i + 8 <= in_dim; i += 8) {
        __m256 xv = _mm256_loadu_ps(src + i);
        __m256i idx = _mm256_setr_epi32(
            (i + 0) * stride,
            (i + 1) * stride,
            (i + 2) * stride,
            (i + 3) * stride,
            (i + 4) * stride,
            (i + 5) * stride,
            (i + 6) * stride,
            (i + 7) * stride);
        __m256 wv = _mm256_i32gather_ps(weights_col, idx, 4);
        __m128 xlo = _mm256_castps256_ps128(xv);
        __m128 xhi = _mm256_extractf128_ps(xv, 1);
        __m128 wlo = _mm256_castps256_ps128(wv);
        __m128 whi = _mm256_extractf128_ps(wv, 1);
        acc0 = _mm256_fmadd_pd(_mm256_cvtps_pd(xlo), _mm256_cvtps_pd(wlo), acc0);
        acc1 = _mm256_fmadd_pd(_mm256_cvtps_pd(xhi), _mm256_cvtps_pd(whi), acc1);
    }
    __m256d acc = _mm256_add_pd(acc0, acc1);
    __m128d lo = _mm256_castpd256_pd128(acc);
    __m128d hi = _mm256_extractf128_pd(acc, 1);
    __m128d pair = _mm_add_pd(lo, hi);
    double sum = _mm_cvtsd_f64(pair) + _mm_cvtsd_f64(_mm_unpackhi_pd(pair, pair));
    for (; i < in_dim; i++) {
        sum += (double)src[i] * (double)weights_col[(size_t)i * (size_t)out_dim];
    }
    return (float)sum;
}
#endif

static float projection_col_dot(const float *src, const float *weights_col, int in_dim, int out_dim) {
#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
    if (cpu_has_avx2_fma() && in_dim >= 8 && out_dim > 0 && in_dim <= INT_MAX / out_dim) {
        return projection_col_dot_avx2_fma(src, weights_col, in_dim, out_dim);
    }
#endif
    return projection_col_dot_scalar(src, weights_col, in_dim, out_dim);
}

static int read_exact(FILE *f, void *dst, size_t n) {
    return fread(dst, 1, n, f) == n ? 0 : -1;
}

static uint16_t le16(const unsigned char b[2]) {
    return (uint16_t)b[0] | ((uint16_t)b[1] << 8);
}

static uint32_t le32(const unsigned char b[4]) {
    return (uint32_t)b[0] |
           ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) |
           ((uint32_t)b[3] << 24);
}

static uint64_t le64(const unsigned char b[8]) {
    return (uint64_t)b[0] |
           ((uint64_t)b[1] << 8) |
           ((uint64_t)b[2] << 16) |
           ((uint64_t)b[3] << 24) |
           ((uint64_t)b[4] << 32) |
           ((uint64_t)b[5] << 40) |
           ((uint64_t)b[6] << 48) |
           ((uint64_t)b[7] << 56);
}

static int read_u16(FILE *f, uint16_t *out) {
    unsigned char b[2];
    if (read_exact(f, b, sizeof(b)) != 0) {
        return -1;
    }
    *out = le16(b);
    return 0;
}

static int read_u32(FILE *f, uint32_t *out) {
    unsigned char b[4];
    if (read_exact(f, b, sizeof(b)) != 0) {
        return -1;
    }
    *out = le32(b);
    return 0;
}

static int read_u64(FILE *f, uint64_t *out) {
    unsigned char b[8];
    if (read_exact(f, b, sizeof(b)) != 0) {
        return -1;
    }
    *out = le64(b);
    return 0;
}

static int validate_dtype(uint16_t dtype) {
    return dtype >= 1 && dtype <= 6;
}

static const char *json_find_key(const char *json, const char *key) {
    if (!json || !key) {
        return NULL;
    }
    char pattern[96];
    snprintf(pattern, sizeof(pattern), "\"%s\":", key);
    return strstr(json, pattern);
}

static int json_get_int(const char *json, const char *key, int fallback) {
    const char *p = json_find_key(json, key);
    if (!p) {
        return fallback;
    }
    p = strchr(p, ':');
    return p ? (int)strtol(p + 1, NULL, 10) : fallback;
}

static float json_get_float(const char *json, const char *key, float fallback) {
    const char *p = json_find_key(json, key);
    if (!p) {
        return fallback;
    }
    p = strchr(p, ':');
    return p ? strtof(p + 1, NULL) : fallback;
}

static int json_get_bool(const char *json, const char *key, int fallback) {
    const char *p = json_find_key(json, key);
    if (!p) {
        return fallback;
    }
    p = strchr(p, ':');
    if (!p) {
        return fallback;
    }
    p++;
    if (strncmp(p, "true", 4) == 0) {
        return 1;
    }
    if (strncmp(p, "false", 5) == 0) {
        return 0;
    }
    return fallback;
}

static void json_get_string(const char *json, const char *key, char *out, size_t out_cap, const char *fallback) {
    if (!out || out_cap == 0) {
        return;
    }
    const char *p = json_find_key(json, key);
    if (!p) {
        snprintf(out, out_cap, "%s", fallback ? fallback : "");
        return;
    }
    p = strchr(p, ':');
    if (!p) {
        snprintf(out, out_cap, "%s", fallback ? fallback : "");
        return;
    }
    p++;
    if (*p != '"') {
        snprintf(out, out_cap, "%s", fallback ? fallback : "");
        return;
    }
    p++;
    size_t n = 0;
    while (p[n] && p[n] != '"' && n + 1 < out_cap) {
        out[n] = p[n];
        n++;
    }
    out[n] = '\0';
}

static void parse_config(needle_ctx *ctx) {
    needle_config *cfg = &ctx->config;
    const char *json = ctx->metadata_json;
    cfg->vocab_size = json_get_int(json, "vocab_size", 0);
    cfg->d_model = json_get_int(json, "d_model", 0);
    cfg->num_heads = json_get_int(json, "num_heads", 0);
    cfg->num_kv_heads = json_get_int(json, "num_kv_heads", 0);
    cfg->num_encoder_layers = json_get_int(json, "num_encoder_layers", 0);
    cfg->num_decoder_layers = json_get_int(json, "num_decoder_layers", 0);
    cfg->d_ff = json_get_int(json, "d_ff", 0);
    cfg->max_seq_len = json_get_int(json, "max_seq_len", 0);
    cfg->pad_token_id = json_get_int(json, "pad_token_id", 0);
    cfg->rope_theta = json_get_float(json, "rope_theta", 10000.0f);
    cfg->num_memory_slots = json_get_int(json, "num_memory_slots", 0);
    cfg->dropout_rate = json_get_float(json, "dropout_rate", 0.0f);
    cfg->contrastive_dim = json_get_int(json, "contrastive_dim", 0);
    cfg->no_feedforward = json_get_bool(json, "no_feedforward", 1);
    cfg->enable_speech = json_get_bool(json, "enable_speech", 0);
    json_get_string(json, "dtype", cfg->dtype, sizeof(cfg->dtype), "");
    json_get_string(json, "activation", cfg->activation, sizeof(cfg->activation), "");
}

static void free_tensors(needle_ctx *ctx) {
    if (!ctx || !ctx->tensors) {
        return;
    }
    for (uint64_t i = 0; i < ctx->tensor_count; i++) {
        free(ctx->tensors[i].name);
        free(ctx->tensors[i].data);
        aligned_free(ctx->tensors[i].f32_data);
    }
    free(ctx->tensors);
    ctx->tensors = NULL;
}

static long long find_tensor_index_linear(needle_ctx *ctx, const char *name) {
    if (!ctx || !name) {
        return -1;
    }
    for (uint64_t i = 0; i < ctx->tensor_count; i++) {
        if (ctx->tensors[i].name && strcmp(ctx->tensors[i].name, name) == 0) {
            return (long long)i;
        }
    }
    return -1;
}

static needle_tensor *find_tensor_ptr_linear(needle_ctx *ctx, const char *name) {
    long long index = find_tensor_index_linear(ctx, name);
    if (index < 0) {
        return NULL;
    }
    return &ctx->tensors[index];
}

static void link_quantized_tensors(needle_ctx *ctx) {
    if (!ctx || !ctx->tensors) {
        return;
    }
    char name[512];
    for (uint64_t i = 0; i < ctx->tensor_count; i++) {
        needle_tensor *tensor = &ctx->tensors[i];
        if (!tensor->name) {
            continue;
        }
        int n = snprintf(name, sizeof(name), "%s.q8", tensor->name);
        if (n > 0 && (size_t)n < sizeof(name)) {
            tensor->q8_tensor = find_tensor_ptr_linear(ctx, name);
        }
        n = snprintf(name, sizeof(name), "%s.q8_scale", tensor->name);
        if (n > 0 && (size_t)n < sizeof(name)) {
            tensor->q8_scale_tensor = find_tensor_ptr_linear(ctx, name);
        }
    }
}

static float f16_to_f32(uint16_t h) {
    uint32_t sign = ((uint32_t)h & 0x8000U) << 16;
    uint32_t exp = ((uint32_t)h >> 10) & 0x1FU;
    uint32_t mant = (uint32_t)h & 0x03FFU;
    uint32_t bits;

    if (exp == 0) {
        if (mant == 0) {
            bits = sign;
        } else {
            exp = 1;
            while ((mant & 0x0400U) == 0) {
                mant <<= 1;
                exp--;
            }
            mant &= 0x03FFU;
            bits = sign | ((exp + 112U) << 23) | (mant << 13);
        }
    } else if (exp == 31) {
        bits = sign | 0x7F800000U | (mant << 13);
    } else {
        bits = sign | ((exp + 112U) << 23) | (mant << 13);
    }

    float out;
    memcpy(&out, &bits, sizeof(out));
    return out;
}

static int tensor_to_f32_at(const needle_tensor *tensor, uint64_t index, float *out) {
    if (!tensor || !out) {
        return -1;
    }
    if (tensor->dtype == NEEDLE_DTYPE_F32) {
        if ((index + 1) * sizeof(float) > tensor->nbytes) {
            return -1;
        }
        memcpy(out, tensor->data + index * sizeof(float), sizeof(float));
        return 0;
    }
    if (tensor->dtype == NEEDLE_DTYPE_F16) {
        if ((index + 1) * sizeof(uint16_t) > tensor->nbytes) {
            return -1;
        }
        uint16_t h = (uint16_t)tensor->data[index * 2] | ((uint16_t)tensor->data[index * 2 + 1] << 8);
        *out = f16_to_f32(h);
        return 0;
    }
    return -1;
}

static int tensor_element_count(const needle_tensor *tensor, uint64_t *out) {
    if (!tensor || !out) {
        return -1;
    }
    uint64_t n = 1;
    for (uint32_t i = 0; i < tensor->ndim; i++) {
        if (tensor->shape[i] != 0 && n > UINT64_MAX / tensor->shape[i]) {
            return -1;
        }
        n *= tensor->shape[i];
    }
    *out = n;
    return 0;
}

static float *tensor_f32_data(needle_tensor *tensor) {
    if (!tensor) {
        return NULL;
    }
    if (tensor->f32_data) {
        return tensor->f32_data;
    }
    if (tensor->dtype != NEEDLE_DTYPE_F32 && tensor->dtype != NEEDLE_DTYPE_F16) {
        return NULL;
    }
    uint64_t count64 = 0;
    if (tensor_element_count(tensor, &count64) != 0 || count64 > (uint64_t)(SIZE_MAX / sizeof(float))) {
        return NULL;
    }
    float *data = alloc_floats((size_t)count64);
    if (!data) {
        return NULL;
    }
    for (uint64_t i = 0; i < count64; i++) {
        if (tensor_to_f32_at(tensor, i, &data[i]) != 0) {
            aligned_free(data);
            return NULL;
        }
    }
    tensor->f32_data = data;
    tensor->f32_count = count64;
    return tensor->f32_data;
}

static int load_runtime_file(needle_ctx *ctx, const char *model_path) {
    FILE *f = fopen(model_path, "rb");
    if (!f) {
        ctx->last_error_code = NEEDLE_ERR_IO;
        snprintf(ctx->last_error, sizeof(ctx->last_error),
                 "could not open model file '%s': %s", model_path, strerror(errno));
        return -1;
    }

    char magic[NEEDLE_MAGIC_SIZE];
    if (read_exact(f, magic, sizeof(magic)) != 0 ||
        memcmp(magic, NEEDLE_MAGIC, strlen(NEEDLE_MAGIC)) != 0 ||
        magic[7] != '\0') {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid runtime model magic");
        fclose(f);
        return -1;
    }

    uint32_t format_version = 0;
    uint32_t flags = 0;
    uint64_t metadata_len = 0;
    uint64_t tokenizer_len = 0;
    uint64_t tensor_count = 0;

    if (read_u32(f, &format_version) != 0 ||
        read_u32(f, &flags) != 0 ||
        read_u64(f, &metadata_len) != 0 ||
        read_u64(f, &tokenizer_len) != 0 ||
        read_u64(f, &tensor_count) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "truncated runtime model header");
        fclose(f);
        return -1;
    }

    if (format_version != NEEDLE_FORMAT_VERSION) {
        ctx->last_error_code = NEEDLE_ERR_UNSUPPORTED;
        snprintf(ctx->last_error, sizeof(ctx->last_error),
                 "unsupported runtime format version %u", format_version);
        fclose(f);
        return -1;
    }
    if (flags != 0) {
        set_error(ctx, NEEDLE_ERR_UNSUPPORTED, "unsupported runtime model flags");
        fclose(f);
        return -1;
    }
    if (metadata_len > (uint64_t)1024 * 1024 * 1024) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "metadata block is too large");
        fclose(f);
        return -1;
    }

    ctx->metadata_json = (char *)malloc((size_t)metadata_len + 1);
    if (!ctx->metadata_json) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while reading metadata");
        fclose(f);
        return -1;
    }
    if (read_exact(f, ctx->metadata_json, (size_t)metadata_len) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "truncated metadata block");
        fclose(f);
        return -1;
    }
    ctx->metadata_json[metadata_len] = '\0';
    parse_config(ctx);

    if (tokenizer_len > (uint64_t)SIZE_MAX) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "tokenizer block is too large");
        fclose(f);
        return -1;
    }
    ctx->tokenizer_data = (unsigned char *)malloc((size_t)tokenizer_len);
    if (tokenizer_len > 0 && !ctx->tokenizer_data) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while reading tokenizer block");
        fclose(f);
        return -1;
    }
    if (read_exact(f, ctx->tokenizer_data, (size_t)tokenizer_len) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "truncated tokenizer block");
        fclose(f);
        return -1;
    }

    if (tensor_count > (uint64_t)SIZE_MAX / sizeof(needle_tensor)) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "tensor table is too large");
        fclose(f);
        return -1;
    }
    ctx->tensors = (needle_tensor *)calloc((size_t)tensor_count, sizeof(needle_tensor));
    if (!ctx->tensors) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while allocating tensor table");
        fclose(f);
        return -1;
    }
    ctx->tensor_count = tensor_count;

    uint64_t total_tensor_bytes = 0;
    for (uint64_t i = 0; i < tensor_count; i++) {
        needle_tensor *tensor = &ctx->tensors[i];
        uint16_t name_len = 0;
        uint16_t dtype = 0;
        uint32_t ndim = 0;
        if (read_u16(f, &name_len) != 0 ||
            read_u16(f, &dtype) != 0 ||
            read_u32(f, &ndim) != 0) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "truncated tensor record header");
            fclose(f);
            return -1;
        }
        if (!validate_dtype(dtype)) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "invalid tensor dtype");
            fclose(f);
            return -1;
        }
        if (ndim > NEEDLE_MAX_NDIM) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "tensor has too many dimensions");
            fclose(f);
            return -1;
        }
        tensor->dtype = dtype;
        tensor->ndim = ndim;

        for (uint32_t d = 0; d < ndim; d++) {
            uint64_t dim = 0;
            if (read_u64(f, &dim) != 0) {
                set_error(ctx, NEEDLE_ERR_FORMAT, "truncated tensor shape");
                fclose(f);
                return -1;
            }
            tensor->shape[d] = dim;
        }

        uint64_t data_nbytes = 0;
        if (read_u64(f, &data_nbytes) != 0) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "truncated tensor byte size");
            fclose(f);
            return -1;
        }
        if (UINT64_MAX - total_tensor_bytes < data_nbytes) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "tensor byte count overflow");
            fclose(f);
            return -1;
        }
        total_tensor_bytes += data_nbytes;
        tensor->nbytes = data_nbytes;

        tensor->name = (char *)malloc((size_t)name_len + 1);
        if (!tensor->name) {
            set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while reading tensor name");
            fclose(f);
            return -1;
        }
        if (read_exact(f, tensor->name, name_len) != 0) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "truncated tensor name");
            fclose(f);
            return -1;
        }
        tensor->name[name_len] = '\0';

        if (data_nbytes > (uint64_t)SIZE_MAX) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "tensor payload is too large");
            fclose(f);
            return -1;
        }
        tensor->data = (unsigned char *)malloc((size_t)data_nbytes);
        if (!tensor->data) {
            set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while reading tensor payload");
            fclose(f);
            return -1;
        }
        if (read_exact(f, tensor->data, (size_t)data_nbytes) != 0) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "truncated tensor payload");
            fclose(f);
            return -1;
        }
    }

    int extra = fgetc(f);
    if (extra != EOF) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "unexpected trailing bytes in runtime model");
        fclose(f);
        return -1;
    }
    if (ferror(f)) {
        set_error(ctx, NEEDLE_ERR_IO, "error while reading runtime model");
        fclose(f);
        return -1;
    }

    fclose(f);
    ctx->tensor_count = tensor_count;
    ctx->tensor_data_bytes = total_tensor_bytes;
    ctx->tokenizer_bytes = tokenizer_len;
    link_quantized_tensors(ctx);
    ctx->loaded = 1;
    set_error(ctx, NEEDLE_OK, NULL);
    return 0;
}

int needle_abi_version(void) {
    return NEEDLE_ABI_VERSION;
}

const char *needle_version(void) {
    return "needle-luajit-runtime/0.0.1";
}

int needle_probe_add(int a, int b) {
    return a + b;
}

void needle_runtime_reset_memory_stats(void) {
    g_aligned_alloc_count = 0;
    g_aligned_alloc_total_bytes = 0;
    g_aligned_alloc_peak_bytes = g_aligned_alloc_current_bytes;
    g_dense_q8_projection_count = 0;
    g_dense_float_projection_count = 0;
    g_dense_q8_fallback_count = 0;
    g_output_q8_projection_count = 0;
    g_output_float_projection_count = 0;
    g_output_q8_fallback_count = 0;
}

unsigned long long needle_runtime_aligned_alloc_count(void) {
    return g_aligned_alloc_count;
}

unsigned long long needle_runtime_aligned_alloc_total_bytes(void) {
    return g_aligned_alloc_total_bytes;
}

unsigned long long needle_runtime_aligned_alloc_active_count(void) {
    return g_aligned_alloc_active_count;
}

unsigned long long needle_runtime_aligned_alloc_current_bytes(void) {
    return g_aligned_alloc_current_bytes;
}

unsigned long long needle_runtime_aligned_alloc_peak_bytes(void) {
    return g_aligned_alloc_peak_bytes;
}

unsigned long long needle_runtime_dense_q8_projection_count(void) {
    return g_dense_q8_projection_count;
}

unsigned long long needle_runtime_dense_float_projection_count(void) {
    return g_dense_float_projection_count;
}

unsigned long long needle_runtime_dense_q8_fallback_count(void) {
    return g_dense_q8_fallback_count;
}

unsigned long long needle_runtime_output_q8_projection_count(void) {
    return g_output_q8_projection_count;
}

unsigned long long needle_runtime_output_float_projection_count(void) {
    return g_output_float_projection_count;
}

unsigned long long needle_runtime_output_q8_fallback_count(void) {
    return g_output_q8_fallback_count;
}

void needle_runtime_set_profile_enabled(int enabled) {
    g_profile_enabled = enabled ? 1 : 0;
}

int needle_runtime_profile_enabled(void) {
    return g_profile_enabled;
}

void needle_runtime_reset_profile_stats(void) {
    memset(g_profile_ns, 0, sizeof(g_profile_ns));
}

unsigned long long needle_runtime_profile_counter_ns(int counter) {
    if (counter < 0 || counter >= NEEDLE_PROFILE_COUNT) {
        return 0ULL;
    }
    return g_profile_ns[counter];
}

needle_ctx *needle_load(const char *model_path) {
    needle_ctx *ctx = (needle_ctx *)calloc(1, sizeof(needle_ctx));
    if (!ctx) {
        return NULL;
    }

    if (!model_path || model_path[0] == '\0') {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "model path is empty");
        return ctx;
    }

    size_t len = strlen(model_path);
    ctx->model_path = (char *)malloc(len + 1);
    if (!ctx->model_path) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while storing model path");
        return ctx;
    }
    memcpy(ctx->model_path, model_path, len + 1);

    (void)load_runtime_file(ctx, model_path);
    return ctx;
}

void needle_free(needle_ctx *ctx) {
    if (!ctx) {
        return;
    }
    free(ctx->model_path);
    free(ctx->metadata_json);
    free(ctx->tokenizer_data);
    free_tensors(ctx);
    free(ctx);
}

const char *needle_last_error(needle_ctx *ctx) {
    if (!ctx) {
        return "needle context is null";
    }
    return ctx->last_error;
}

int needle_last_error_code(needle_ctx *ctx) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    return ctx->last_error_code;
}

void needle_clear_error(needle_ctx *ctx) {
    set_error(ctx, NEEDLE_OK, NULL);
}

int needle_is_loaded(needle_ctx *ctx) {
    return ctx && ctx->loaded ? 1 : 0;
}

unsigned long long needle_tensor_count(needle_ctx *ctx) {
    return ctx ? (unsigned long long)ctx->tensor_count : 0ULL;
}

unsigned long long needle_tensor_data_bytes(needle_ctx *ctx) {
    return ctx ? (unsigned long long)ctx->tensor_data_bytes : 0ULL;
}

unsigned long long needle_tokenizer_bytes(needle_ctx *ctx) {
    return ctx ? (unsigned long long)ctx->tokenizer_bytes : 0ULL;
}

needle_tokenizer *needle_tokenizer_from_context(needle_ctx *ctx) {
    if (!ctx || !ctx->loaded || !ctx->tokenizer_data || ctx->tokenizer_bytes == 0) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "runtime model has no embedded tokenizer");
        return NULL;
    }
    needle_tokenizer *tok = needle_tokenizer_load_memory(ctx->tokenizer_data, ctx->tokenizer_bytes);
    if (!tok) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "could not allocate embedded tokenizer");
    }
    return tok;
}

const char *needle_metadata_json(needle_ctx *ctx) {
    if (!ctx || !ctx->metadata_json) {
        return "";
    }
    return ctx->metadata_json;
}

const needle_config *needle_get_config(needle_ctx *ctx) {
    if (!ctx || !ctx->loaded) {
        return NULL;
    }
    return &ctx->config;
}

static needle_tensor *get_tensor_by_index(needle_ctx *ctx, unsigned long long index) {
    if (!ctx || !ctx->loaded || index >= ctx->tensor_count) {
        return NULL;
    }
    return &ctx->tensors[index];
}

const char *needle_tensor_name(needle_ctx *ctx, unsigned long long index) {
    needle_tensor *tensor = get_tensor_by_index(ctx, index);
    return tensor && tensor->name ? tensor->name : "";
}

int needle_tensor_dtype(needle_ctx *ctx, unsigned long long index) {
    needle_tensor *tensor = get_tensor_by_index(ctx, index);
    return tensor ? (int)tensor->dtype : 0;
}

const unsigned char *needle_tensor_data(needle_ctx *ctx, unsigned long long index) {
    if (!ctx || !ctx->loaded || index >= ctx->tensor_count) {
        if (ctx) {
            set_error(ctx, !ctx->loaded ? NEEDLE_ERR_NOT_LOADED : NEEDLE_ERR_INVALID_ARGUMENT, "invalid tensor data index");
        }
        return NULL;
    }
    set_error(ctx, NEEDLE_OK, NULL);
    return ctx->tensors[index].data;
}

int needle_tensor_ndim(needle_ctx *ctx, unsigned long long index) {
    needle_tensor *tensor = get_tensor_by_index(ctx, index);
    return tensor ? (int)tensor->ndim : 0;
}

unsigned long long needle_tensor_dim(needle_ctx *ctx, unsigned long long index, int dim) {
    needle_tensor *tensor = get_tensor_by_index(ctx, index);
    if (!tensor || dim < 0 || (uint32_t)dim >= tensor->ndim) {
        return 0ULL;
    }
    return (unsigned long long)tensor->shape[dim];
}

unsigned long long needle_tensor_nbytes(needle_ctx *ctx, unsigned long long index) {
    needle_tensor *tensor = get_tensor_by_index(ctx, index);
    return tensor ? (unsigned long long)tensor->nbytes : 0ULL;
}

long long needle_find_tensor(needle_ctx *ctx, const char *name) {
    if (!ctx || !ctx->loaded || !name) {
        return -1;
    }
    return find_tensor_index_linear(ctx, name);
}

int needle_embedding_lookup(needle_ctx *ctx, int token_id, float *out, int out_cap) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    if (!out || out_cap <= 0 || token_id < 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid embedding lookup arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    long long index = needle_find_tensor(ctx, "embedding/embedding");
    if (index < 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "embedding tensor is missing");
        return NEEDLE_ERR_FORMAT;
    }
    needle_tensor *embedding = &ctx->tensors[index];
    if (embedding->ndim != 2 || embedding->shape[1] > (uint64_t)out_cap || (uint64_t)token_id >= embedding->shape[0]) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "embedding lookup is out of bounds");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    uint64_t d_model = embedding->shape[1];
    uint64_t base = (uint64_t)token_id * d_model;
    float *embedding_f32 = tensor_f32_data(embedding);
    if (embedding_f32) {
        memcpy(out, embedding_f32 + base, (size_t)d_model * sizeof(float));
        set_error(ctx, NEEDLE_OK, NULL);
        return (int)d_model;
    }
    for (uint64_t i = 0; i < d_model; i++) {
        if (tensor_to_f32_at(embedding, base + i, &out[i]) != 0) {
            set_error(ctx, NEEDLE_ERR_UNSUPPORTED, "embedding dtype is not supported yet");
            return NEEDLE_ERR_UNSUPPORTED;
        }
    }
    set_error(ctx, NEEDLE_OK, NULL);
    return (int)d_model;
}

static needle_tensor *find_tensor_ptr(needle_ctx *ctx, const char *name) {
    long long index = needle_find_tensor(ctx, name);
    if (index < 0) {
        return NULL;
    }
    return &ctx->tensors[index];
}

static int tensor_value_f32(const needle_tensor *tensor, uint64_t index, float *out) {
    return tensor_to_f32_at(tensor, index, out);
}

static int read_layer_matrix_value(
    const needle_tensor *tensor,
    int layer,
    int row,
    int col,
    int rows,
    int cols,
    float *out) {
    if (!tensor || tensor->ndim != 3 || tensor->shape[1] != (uint64_t)rows || tensor->shape[2] != (uint64_t)cols ||
        layer < 0 || (uint64_t)layer >= tensor->shape[0] || row < 0 || row >= rows || col < 0 || col >= cols) {
        return -1;
    }
    uint64_t index = ((uint64_t)layer * (uint64_t)rows + (uint64_t)row) * (uint64_t)cols + (uint64_t)col;
    return tensor_value_f32(tensor, index, out);
}

static int read_layer_vector_value(const needle_tensor *tensor, int layer, int col, int cols, float *out) {
    if (!tensor || tensor->ndim != 2 || tensor->shape[1] != (uint64_t)cols ||
        layer < 0 || (uint64_t)layer >= tensor->shape[0] || col < 0 || col >= cols) {
        return -1;
    }
    uint64_t index = (uint64_t)layer * (uint64_t)cols + (uint64_t)col;
    return tensor_value_f32(tensor, index, out);
}

static int read_layer_scalar_value(const needle_tensor *tensor, int layer, float *out) {
    if (!tensor || tensor->ndim != 1 || layer < 0 || (uint64_t)layer >= tensor->shape[0]) {
        return -1;
    }
    return tensor_value_f32(tensor, (uint64_t)layer, out);
}

static int zcrmsnorm_model_inplace(float *x, int seq_len, int d_model, const needle_tensor *scale, int layer) {
    if (!scale || scale->ndim != 2 || scale->shape[1] != (uint64_t)d_model ||
        layer < 0 || (uint64_t)layer >= scale->shape[0]) {
        return -1;
    }
    for (int t = 0; t < seq_len; t++) {
        float *row = x + (size_t)t * (size_t)d_model;
        double sumsq = 0.0;
        for (int d = 0; d < d_model; d++) {
            sumsq += (double)row[d] * (double)row[d];
        }
        float inv_rms = 1.0f / sqrtf((float)(sumsq / (double)d_model) + 1e-6f);
        for (int d = 0; d < d_model; d++) {
            float s = 0.0f;
            if (read_layer_vector_value(scale, layer, d, d_model, &s) != 0) {
                return -1;
            }
            row[d] = (1.0f + s) * row[d] * inv_rms;
        }
    }
    return 0;
}

static int zcrmsnorm_model_final_inplace(float *x, int seq_len, int d_model, const needle_tensor *scale) {
    if (!scale || scale->ndim != 1 || scale->shape[0] != (uint64_t)d_model) {
        return -1;
    }
    for (int t = 0; t < seq_len; t++) {
        float *row = x + (size_t)t * (size_t)d_model;
        double sumsq = 0.0;
        for (int d = 0; d < d_model; d++) {
            sumsq += (double)row[d] * (double)row[d];
        }
        float inv_rms = 1.0f / sqrtf((float)(sumsq / (double)d_model) + 1e-6f);
        for (int d = 0; d < d_model; d++) {
            float s = 0.0f;
            if (tensor_value_f32(scale, (uint64_t)d, &s) != 0) {
                return -1;
            }
            row[d] = (1.0f + s) * row[d] * inv_rms;
        }
    }
    return 0;
}

static needle_tensor *find_tensor_ptr(needle_ctx *ctx, const char *name);

static void q8_project_row_scalar(
    const float *src,
    float *dst,
    const int8_t *q_data,
    const float *scales,
    size_t layer_base,
    size_t scale_base,
    int in_dim,
    int out_dim) {
    memset(dst, 0, (size_t)out_dim * sizeof(float));
    for (int i = 0; i < in_dim; i++) {
        float xi = src[i];
        const int8_t *q_row = q_data + layer_base + (size_t)i * (size_t)out_dim;
        for (int j = 0; j < out_dim; j++) {
            dst[j] += xi * (float)q_row[j];
        }
    }
    for (int j = 0; j < out_dim; j++) {
        dst[j] *= scales[scale_base + (size_t)j];
    }
}

#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
__attribute__((target("avx2,fma")))
static void q8_project_row_avx2_fma(
    const float *src,
    float *dst,
    const int8_t *q_data,
    const float *scales,
    size_t layer_base,
    size_t scale_base,
    int in_dim,
    int out_dim) {
    int j = 0;
    for (; j + 32 <= out_dim; j += 32) {
        __m256 acc0 = _mm256_setzero_ps();
        __m256 acc1 = _mm256_setzero_ps();
        __m256 acc2 = _mm256_setzero_ps();
        __m256 acc3 = _mm256_setzero_ps();
        for (int i = 0; i < in_dim; i++) {
            const int8_t *q = q_data + layer_base + (size_t)i * (size_t)out_dim + (size_t)j;
            __m256 xv = _mm256_set1_ps(src[i]);
            __m128i q8 = _mm_loadl_epi64((const __m128i *)q);
            acc0 = _mm256_fmadd_ps(xv, _mm256_cvtepi32_ps(_mm256_cvtepi8_epi32(q8)), acc0);
            q8 = _mm_loadl_epi64((const __m128i *)(q + 8));
            acc1 = _mm256_fmadd_ps(xv, _mm256_cvtepi32_ps(_mm256_cvtepi8_epi32(q8)), acc1);
            q8 = _mm_loadl_epi64((const __m128i *)(q + 16));
            acc2 = _mm256_fmadd_ps(xv, _mm256_cvtepi32_ps(_mm256_cvtepi8_epi32(q8)), acc2);
            q8 = _mm_loadl_epi64((const __m128i *)(q + 24));
            acc3 = _mm256_fmadd_ps(xv, _mm256_cvtepi32_ps(_mm256_cvtepi8_epi32(q8)), acc3);
        }
        __m256 sv = _mm256_loadu_ps(scales + scale_base + (size_t)j);
        _mm256_storeu_ps(dst + j, _mm256_mul_ps(acc0, sv));
        sv = _mm256_loadu_ps(scales + scale_base + (size_t)j + 8);
        _mm256_storeu_ps(dst + j + 8, _mm256_mul_ps(acc1, sv));
        sv = _mm256_loadu_ps(scales + scale_base + (size_t)j + 16);
        _mm256_storeu_ps(dst + j + 16, _mm256_mul_ps(acc2, sv));
        sv = _mm256_loadu_ps(scales + scale_base + (size_t)j + 24);
        _mm256_storeu_ps(dst + j + 24, _mm256_mul_ps(acc3, sv));
    }
    for (; j + 8 <= out_dim; j += 8) {
        __m256 acc = _mm256_setzero_ps();
        for (int i = 0; i < in_dim; i++) {
            __m128i q8 = _mm_loadl_epi64((const __m128i *)(q_data + layer_base + (size_t)i * (size_t)out_dim + (size_t)j));
            __m256 qf = _mm256_cvtepi32_ps(_mm256_cvtepi8_epi32(q8));
            __m256 xv = _mm256_set1_ps(src[i]);
            acc = _mm256_fmadd_ps(xv, qf, acc);
        }
        __m256 sv = _mm256_loadu_ps(scales + scale_base + (size_t)j);
        _mm256_storeu_ps(dst + j, _mm256_mul_ps(acc, sv));
    }
    for (; j < out_dim; j++) {
        float sum = 0.0f;
        for (int i = 0; i < in_dim; i++) {
            sum += src[i] * (float)q_data[layer_base + (size_t)i * (size_t)out_dim + (size_t)j];
        }
        dst[j] = sum * scales[scale_base + (size_t)j];
    }
}
#endif

static void q8_project_row(
    const float *src,
    float *dst,
    const int8_t *q_data,
    const float *scales,
    size_t layer_base,
    size_t scale_base,
    int in_dim,
    int out_dim) {
#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
    if (cpu_has_avx2_fma() && out_dim >= 8) {
        q8_project_row_avx2_fma(src, dst, q_data, scales, layer_base, scale_base, in_dim, out_dim);
        return;
    }
#endif
    q8_project_row_scalar(src, dst, q_data, scales, layer_base, scale_base, in_dim, out_dim);
}

static float q8_row_dot_scalar(const float *src, const int8_t *q_row, int n) {
    float sum = 0.0f;
    for (int i = 0; i < n; i++) {
        sum += src[i] * (float)q_row[i];
    }
    return sum;
}

#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
__attribute__((target("avx2,fma")))
static float q8_row_dot_avx2_fma(const float *src, const int8_t *q_row, int n) {
    __m256 acc = _mm256_setzero_ps();
    int i = 0;
    for (; i + 8 <= n; i += 8) {
        __m128i q8 = _mm_loadl_epi64((const __m128i *)(q_row + i));
        __m256 qf = _mm256_cvtepi32_ps(_mm256_cvtepi8_epi32(q8));
        __m256 xv = _mm256_loadu_ps(src + i);
        acc = _mm256_fmadd_ps(xv, qf, acc);
    }
    __m128 lo = _mm256_castps256_ps128(acc);
    __m128 hi = _mm256_extractf128_ps(acc, 1);
    __m128 sum = _mm_add_ps(lo, hi);
    sum = _mm_add_ps(sum, _mm_movehl_ps(sum, sum));
    sum = _mm_add_ss(sum, _mm_shuffle_ps(sum, sum, 0x55));
    float out = _mm_cvtss_f32(sum);
    for (; i < n; i++) {
        out += src[i] * (float)q_row[i];
    }
    return out;
}
#endif

static float q8_row_dot(const float *src, const int8_t *q_row, int n) {
#if (defined(__x86_64__) || defined(__i386__)) && (defined(__GNUC__) || defined(__clang__))
    if (cpu_has_avx2_fma() && n >= 8) {
        return q8_row_dot_avx2_fma(src, q_row, n);
    }
#endif
    return q8_row_dot_scalar(src, q_row, n);
}

static int output_projection_q8_embedding(
    needle_ctx *ctx,
    const float *x,
    int seq_len,
    int d_model,
    int vocab_size,
    float *out) {
    needle_tensor *embedding = find_tensor_ptr(ctx, "embedding/embedding");
    needle_tensor *q_embedding = embedding ? embedding->q8_tensor : find_tensor_ptr(ctx, "embedding/embedding.q8");
    needle_tensor *scale = embedding ? embedding->q8_scale_tensor : find_tensor_ptr(ctx, "embedding/embedding.q8_scale");
    if (!q_embedding && !scale) {
        return 1;
    }
    if (!q_embedding || !scale ||
        q_embedding->dtype != NEEDLE_DTYPE_I8 || scale->dtype != NEEDLE_DTYPE_F32 ||
        q_embedding->ndim != 2 || q_embedding->shape[0] != (uint64_t)vocab_size ||
        q_embedding->shape[1] != (uint64_t)d_model ||
        scale->ndim != 1 || scale->shape[0] != (uint64_t)vocab_size) {
        return -1;
    }

    const int8_t *q_data = (const int8_t *)q_embedding->data;
    const float *scales = (const float *)scale->data;
    for (int t = 0; t < seq_len; t++) {
        const float *row = x + (size_t)t * (size_t)d_model;
        float *dst = out + (size_t)t * (size_t)vocab_size;
        for (int vocab = 0; vocab < vocab_size; vocab++) {
            const int8_t *q_row = q_data + (size_t)vocab * (size_t)d_model;
            dst[vocab] = q8_row_dot(row, q_row, d_model) * scales[vocab];
        }
    }
    return 0;
}

static int dense_project_layer_q8(
    needle_ctx *ctx,
    const float *x,
    float *out,
    int seq_len,
    int in_dim,
    int out_dim,
    needle_tensor *kernel,
    int layer) {
    if (!ctx || !kernel || !kernel->name) {
        return 1;
    }
    needle_tensor *q_kernel = kernel->q8_tensor;
    needle_tensor *scale = kernel->q8_scale_tensor;
    if (!q_kernel && !scale) {
        return 1;
    }
    if (!q_kernel || !scale ||
        q_kernel->dtype != NEEDLE_DTYPE_I8 || scale->dtype != NEEDLE_DTYPE_F32 ||
        q_kernel->ndim != 3 || q_kernel->shape[1] != (uint64_t)in_dim || q_kernel->shape[2] != (uint64_t)out_dim ||
        scale->ndim != 2 || scale->shape[1] != (uint64_t)out_dim ||
        layer < 0 || (uint64_t)layer >= q_kernel->shape[0] || (uint64_t)layer >= scale->shape[0]) {
        return -1;
    }

    const int8_t *q_data = (const int8_t *)q_kernel->data;
    const float *scales = (const float *)scale->data;
    size_t layer_base = (size_t)layer * (size_t)in_dim * (size_t)out_dim;
    size_t scale_base = (size_t)layer * (size_t)out_dim;
    for (int t = 0; t < seq_len; t++) {
        const float *src = x + (size_t)t * (size_t)in_dim;
        float *dst = out + (size_t)t * (size_t)out_dim;
        q8_project_row(src, dst, q_data, scales, layer_base, scale_base, in_dim, out_dim);
    }
    return 0;
}

static int dense_project_layer(
    needle_ctx *ctx,
    const float *x,
    float *out,
    int seq_len,
    int in_dim,
    int out_dim,
    needle_tensor *kernel,
    int layer) {
    if (!kernel || kernel->ndim != 3 || kernel->shape[1] != (uint64_t)in_dim ||
        kernel->shape[2] != (uint64_t)out_dim || layer < 0 || (uint64_t)layer >= kernel->shape[0]) {
        return -1;
    }
    int q8_rc = dense_project_layer_q8(ctx, x, out, seq_len, in_dim, out_dim, kernel, layer);
    if (q8_rc == 0) {
        g_dense_q8_projection_count++;
        return 0;
    }
    if (q8_rc < 0) {
        return -1;
    }
    g_dense_q8_fallback_count++;
    g_dense_float_projection_count++;

    float *weights = tensor_f32_data(kernel);
    if (weights) {
        size_t layer_base = (size_t)layer * (size_t)in_dim * (size_t)out_dim;
        for (int t = 0; t < seq_len; t++) {
            const float *src = x + (size_t)t * (size_t)in_dim;
            for (int j = 0; j < out_dim; j++) {
                const float *weights_col = weights + layer_base + (size_t)j;
                out[(size_t)t * (size_t)out_dim + (size_t)j] = projection_col_dot(src, weights_col, in_dim, out_dim);
            }
        }
        return 0;
    }

    for (int t = 0; t < seq_len; t++) {
        for (int j = 0; j < out_dim; j++) {
            double sum = 0.0;
            for (int i = 0; i < in_dim; i++) {
                float w = 0.0f;
                if (read_layer_matrix_value(kernel, layer, i, j, in_dim, out_dim, &w) != 0) {
                    return -1;
                }
                sum += (double)x[(size_t)t * (size_t)in_dim + (size_t)i] * (double)w;
            }
            out[(size_t)t * (size_t)out_dim + (size_t)j] = (float)sum;
        }
    }
    return 0;
}

static int zcrmsnorm_heads_inplace(float *x, int seq_len, int heads, int head_dim, const needle_tensor *scale, int layer) {
    for (int t = 0; t < seq_len; t++) {
        for (int h = 0; h < heads; h++) {
            float *row = x + ((size_t)t * (size_t)heads + (size_t)h) * (size_t)head_dim;
            double sumsq = 0.0;
            for (int d = 0; d < head_dim; d++) {
                sumsq += (double)row[d] * (double)row[d];
            }
            float inv_rms = 1.0f / sqrtf((float)(sumsq / (double)head_dim) + 1e-6f);
            for (int d = 0; d < head_dim; d++) {
                float s = 0.0f;
                if (read_layer_vector_value(scale, layer, d, head_dim, &s) != 0) {
                    return -1;
                }
                row[d] = (1.0f + s) * row[d] * inv_rms;
            }
        }
    }
    return 0;
}

static void build_rope_tables(float *cos_table, float *sin_table, int seq_len, int head_dim, float theta) {
    int half = head_dim / 2;
    for (int t = 0; t < seq_len; t++) {
        for (int i = 0; i < half; i++) {
            float freq = 1.0f / powf(theta, (float)(2 * i) / (float)head_dim);
            float angle = (float)t * freq;
            cos_table[(size_t)t * (size_t)half + (size_t)i] = cosf(angle);
            sin_table[(size_t)t * (size_t)half + (size_t)i] = sinf(angle);
        }
    }
}

static void apply_rope_seq_heads_table(float *x, int seq_len, int heads, int head_dim, const float *cos_table, const float *sin_table) {
    int half = head_dim / 2;
    for (int t = 0; t < seq_len; t++) {
        for (int h = 0; h < heads; h++) {
            float *row = x + ((size_t)t * (size_t)heads + (size_t)h) * (size_t)head_dim;
            const float *cos_row = cos_table + (size_t)t * (size_t)half;
            const float *sin_row = sin_table + (size_t)t * (size_t)half;
            for (int i = 0; i < half; i++) {
                float cs = cos_row[i];
                float sn = sin_row[i];
                float x1 = row[i];
                float x2 = row[half + i];
                row[i] = x1 * cs - x2 * sn;
                row[half + i] = x2 * cs + x1 * sn;
            }
        }
    }
}

static void apply_rope_seq_heads(float *x, int seq_len, int heads, int head_dim, float theta) {
    int half = head_dim / 2;
    for (int t = 0; t < seq_len; t++) {
        for (int h = 0; h < heads; h++) {
            float *row = x + ((size_t)t * (size_t)heads + (size_t)h) * (size_t)head_dim;
            for (int i = 0; i < half; i++) {
                float freq = 1.0f / powf(theta, (float)(2 * i) / (float)head_dim);
                float angle = (float)t * freq;
                float cs = cosf(angle);
                float sn = sinf(angle);
                float x1 = row[i];
                float x2 = row[half + i];
                row[i] = x1 * cs - x2 * sn;
                row[half + i] = x2 * cs + x1 * sn;
            }
        }
    }
}

static void apply_rope_heads_at_position(float *x, int position, int heads, int head_dim, float theta) {
    int half = head_dim / 2;
    for (int h = 0; h < heads; h++) {
        float *row = x + (size_t)h * (size_t)head_dim;
        for (int i = 0; i < half; i++) {
            float freq = 1.0f / powf(theta, (float)(2 * i) / (float)head_dim);
            float angle = (float)position * freq;
            float cs = cosf(angle);
            float sn = sinf(angle);
            float x1 = row[i];
            float x2 = row[half + i];
            row[i] = x1 * cs - x2 * sn;
            row[half + i] = x2 * cs + x1 * sn;
        }
    }
}

static int encoder_self_attention_impl(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    float *out,
    int out_cap,
    float *scratch_q,
    float *scratch_k,
    float *scratch_v,
    float *scratch_ctx_out,
    const float *rope_cos,
    const float *rope_sin) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    if (!x || !out || seq_len <= 0 || d_model <= 0 || heads <= 0 || kv_heads <= 0 ||
        (d_model % heads) != 0 || (heads % kv_heads) != 0 || out_cap < seq_len * d_model ||
        layer < 0 || layer >= cfg->num_encoder_layers) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder self-attention arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    if ((head_dim % 2) != 0) {
        set_error(ctx, NEEDLE_ERR_UNSUPPORTED, "odd attention head dimensions are not supported");
        return NEEDLE_ERR_UNSUPPORTED;
    }

    needle_tensor *q_kernel = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel");
    needle_tensor *k_kernel = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/self_attn/k_proj/kernel");
    needle_tensor *v_kernel = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/self_attn/v_proj/kernel");
    needle_tensor *out_kernel = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/self_attn/out_proj/kernel");
    needle_tensor *q_scale = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/self_attn/q_norm/scale");
    needle_tensor *k_scale = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/self_attn/k_norm/scale");
    if (!q_kernel || !k_kernel || !v_kernel || !out_kernel || !q_scale || !k_scale) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "encoder self-attention tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t q_size = (size_t)seq_len * (size_t)d_model;
    size_t kv_size = (size_t)seq_len * (size_t)kv_dim;
    int owns_scratch = (!scratch_q || !scratch_k || !scratch_v || !scratch_ctx_out);
    float *q = owns_scratch ? calloc_floats(q_size) : scratch_q;
    float *k = owns_scratch ? calloc_floats(kv_size) : scratch_k;
    float *v = owns_scratch ? calloc_floats(kv_size) : scratch_v;
    float *ctx_out = owns_scratch ? calloc_floats(q_size) : scratch_ctx_out;
    if (!q || !k || !v || !ctx_out) {
        if (owns_scratch) {
            aligned_free(q); aligned_free(k); aligned_free(v); aligned_free(ctx_out);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in encoder self-attention");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    if (!owns_scratch) {
        memset(ctx_out, 0, q_size * sizeof(float));
    }

    int rc = NEEDLE_OK;
    float *scores = alloc_floats((size_t)seq_len);
    if (!scores) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in encoder self-attention scores");
        rc = NEEDLE_ERR_OUT_OF_MEMORY;
        goto done;
    }
    unsigned long long profile_t = profile_start();
    if (dense_project_layer(ctx, x, q, seq_len, d_model, d_model, q_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder self-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_end(NEEDLE_PROFILE_ENCODER_Q_PROJ, profile_t);
    profile_t = profile_start();
    if (dense_project_layer(ctx, x, k, seq_len, d_model, kv_dim, k_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder self-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_end(NEEDLE_PROFILE_ENCODER_K_PROJ, profile_t);
    profile_t = profile_start();
    if (dense_project_layer(ctx, x, v, seq_len, d_model, kv_dim, v_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder self-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_end(NEEDLE_PROFILE_ENCODER_V_PROJ, profile_t);

    profile_t = profile_start();
    if (zcrmsnorm_heads_inplace(q, seq_len, heads, head_dim, q_scale, layer) != 0 ||
        zcrmsnorm_heads_inplace(k, seq_len, kv_heads, head_dim, k_scale, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder self-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }

    if (rope_cos && rope_sin) {
        apply_rope_seq_heads_table(q, seq_len, heads, head_dim, rope_cos, rope_sin);
        apply_rope_seq_heads_table(k, seq_len, kv_heads, head_dim, rope_cos, rope_sin);
    } else {
        apply_rope_seq_heads(q, seq_len, heads, head_dim, cfg->rope_theta);
        apply_rope_seq_heads(k, seq_len, kv_heads, head_dim, cfg->rope_theta);
    }
    profile_end(NEEDLE_PROFILE_ENCODER_QK_NORM_ROPE, profile_t);

    int repeats = heads / kv_heads;
    float inv_sqrt = 1.0f / sqrtf((float)head_dim);
    for (int h = 0; h < heads; h++) {
        int kh = h / repeats;
        for (int tq = 0; tq < seq_len; tq++) {
            size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
            size_t ctx_off = q_off;
            float max_score = -3.402823466e38f;
            profile_t = profile_start();
            for (int tk = 0; tk < seq_len; tk++) {
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                scores[tk] = score;
                if (score > max_score) max_score = score;
            }
            profile_end(NEEDLE_PROFILE_ENCODER_ATTENTION_SCORES, profile_t);

            profile_t = profile_start();
            double denom = attention_values_row(ctx_out + ctx_off, v, scores, max_score, seq_len, kv_heads, kh, head_dim);
            float inv = denom > 0.0 ? (float)(1.0 / denom) : 0.0f;
            scale_f32(ctx_out + ctx_off, inv, head_dim);
            profile_end(NEEDLE_PROFILE_ENCODER_ATTENTION_VALUES, profile_t);
        }
    }

    profile_t = profile_start();
    if (dense_project_layer(ctx, ctx_out, out, seq_len, d_model, d_model, out_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder self-attention output projection shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_end(NEEDLE_PROFILE_ENCODER_OUT_PROJ, profile_t);

    set_error(ctx, NEEDLE_OK, NULL);

done:
    aligned_free(scores);
    if (owns_scratch) {
        aligned_free(q);
        aligned_free(k);
        aligned_free(v);
        aligned_free(ctx_out);
    }
    return rc;
}

int needle_encoder_self_attention_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    float *out,
    int out_cap) {
    return encoder_self_attention_impl(ctx, layer, x, seq_len, out, out_cap, NULL, NULL, NULL, NULL, NULL, NULL);
}

static int encoder_block_impl(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    float *out,
    int out_cap,
    float *scratch_normed,
    float *scratch_attn,
    float *self_q,
    float *self_k,
    float *self_v,
    float *self_ctx_out,
    const float *rope_cos,
    const float *rope_sin) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    if (!x || !out || seq_len <= 0 || d_model <= 0 || out_cap < seq_len * d_model ||
        layer < 0 || layer >= ctx->config.num_encoder_layers) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder block arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    needle_tensor *norm_scale = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/ZCRMSNorm_0/scale");
    needle_tensor *attn_gate = find_tensor_ptr(ctx, "encoder/layers/EncoderBlock_0/attn_gate");
    if (!norm_scale || !attn_gate) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "encoder block tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t n = (size_t)seq_len * (size_t)d_model;
    int owns_scratch = (!scratch_normed || !scratch_attn);
    float *normed = owns_scratch ? alloc_floats(n) : scratch_normed;
    float *attn = owns_scratch ? alloc_floats(n) : scratch_attn;
    if (!normed || !attn) {
        if (owns_scratch) {
            aligned_free(normed);
            aligned_free(attn);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in encoder block");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    memcpy(normed, x, n * sizeof(float));

    int rc = NEEDLE_OK;
    unsigned long long profile_t = profile_start();
    if (zcrmsnorm_model_inplace(normed, seq_len, d_model, norm_scale, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder block norm shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_end(NEEDLE_PROFILE_ENCODER_BLOCK_NORM, profile_t);
    rc = encoder_self_attention_impl(
        ctx, layer, normed, seq_len, attn, (int)n, self_q, self_k, self_v, self_ctx_out, rope_cos, rope_sin);
    if (rc != NEEDLE_OK) {
        goto done;
    }

    float gate_raw = 0.0f;
    if (read_layer_scalar_value(attn_gate, layer, &gate_raw) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid encoder block gate shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_t = profile_start();
    float gate = 1.0f / (1.0f + expf(-gate_raw));
    for (size_t i = 0; i < n; i++) {
        out[i] = x[i] + gate * attn[i];
    }
    profile_end(NEEDLE_PROFILE_ENCODER_BLOCK_RESIDUAL, profile_t);
    set_error(ctx, NEEDLE_OK, NULL);

done:
    if (owns_scratch) {
        aligned_free(normed);
        aligned_free(attn);
    }
    return rc;
}

int needle_encoder_block_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    float *out,
    int out_cap) {
    return encoder_block_impl(ctx, layer, x, seq_len, out, out_cap, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}

int needle_output_projection_f32(
    needle_ctx *ctx,
    const float *x,
    int seq_len,
    float *out,
    int out_cap) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int vocab_size = cfg->vocab_size;
    if (!x || !out || seq_len <= 0 || d_model <= 0 || vocab_size <= 0 ||
        out_cap < seq_len * vocab_size) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid output projection arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    needle_tensor *embedding = find_tensor_ptr(ctx, "embedding/embedding");
    if (!embedding || embedding->ndim != 2 || embedding->shape[0] != (uint64_t)vocab_size ||
        embedding->shape[1] != (uint64_t)d_model) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "embedding tensor shape is invalid for output projection");
        return NEEDLE_ERR_FORMAT;
    }

    int q8_rc = output_projection_q8_embedding(ctx, x, seq_len, d_model, vocab_size, out);
    if (q8_rc == 0) {
        g_output_q8_projection_count++;
        set_error(ctx, NEEDLE_OK, NULL);
        return seq_len * vocab_size;
    }
    if (q8_rc < 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "embedding q8 tensor shape is invalid for output projection");
        return NEEDLE_ERR_FORMAT;
    }
    g_output_q8_fallback_count++;
    g_output_float_projection_count++;

    float *embedding_f32 = tensor_f32_data(embedding);
    if (embedding_f32) {
        for (int t = 0; t < seq_len; t++) {
            const float *row = x + (size_t)t * (size_t)d_model;
            for (int vocab = 0; vocab < vocab_size; vocab++) {
                const float *emb = embedding_f32 + (size_t)vocab * (size_t)d_model;
                out[(size_t)t * (size_t)vocab_size + (size_t)vocab] = dot_f32(row, emb, d_model);
            }
        }
        set_error(ctx, NEEDLE_OK, NULL);
        return seq_len * vocab_size;
    }

    for (int t = 0; t < seq_len; t++) {
        for (int vocab = 0; vocab < vocab_size; vocab++) {
            double sum = 0.0;
            for (int d = 0; d < d_model; d++) {
                float w = 0.0f;
                uint64_t emb_index = (uint64_t)vocab * (uint64_t)d_model + (uint64_t)d;
                if (tensor_value_f32(embedding, emb_index, &w) != 0) {
                    set_error(ctx, NEEDLE_ERR_UNSUPPORTED, "embedding dtype is not supported for output projection");
                    return NEEDLE_ERR_UNSUPPORTED;
                }
                sum += (double)x[(size_t)t * (size_t)d_model + (size_t)d] * (double)w;
            }
            out[(size_t)t * (size_t)vocab_size + (size_t)vocab] = (float)sum;
        }
    }
    set_error(ctx, NEEDLE_OK, NULL);
    return seq_len * vocab_size;
}

static int encode_tokens_f32_cancellable(
    needle_ctx *ctx,
    const int *token_ids,
    int seq_len,
    float *out,
    int out_cap,
    needle_progress_callback callback,
    void *user_data) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    int layers = ctx->config.num_encoder_layers;
    if (!token_ids || !out || seq_len <= 0 || d_model <= 0 || layers <= 0 || out_cap < seq_len * d_model) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    size_t n = (size_t)seq_len * (size_t)d_model;
    float *cur = out;
    float *next_storage = alloc_floats(n);
    float *next = next_storage;
    int heads = ctx->config.num_heads;
    int kv_heads = ctx->config.num_kv_heads;
    if (heads <= 0 || kv_heads <= 0 || (d_model % heads) != 0 || (heads % kv_heads) != 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder attention dimensions");
        aligned_free(next_storage);
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    size_t q_size = n;
    size_t kv_size = (size_t)seq_len * (size_t)kv_dim;
    float *block_normed = alloc_floats(n);
    float *block_attn = alloc_floats(n);
    float *self_q = alloc_floats(q_size);
    float *self_k = alloc_floats(kv_size);
    float *self_v = alloc_floats(kv_size);
    float *self_ctx_out = alloc_floats(q_size);
    float *rope_cos = alloc_floats((size_t)seq_len * (size_t)(head_dim / 2));
    float *rope_sin = alloc_floats((size_t)seq_len * (size_t)(head_dim / 2));
    if (!cur || !next || !block_normed || !block_attn || !self_q || !self_k || !self_v || !self_ctx_out || !rope_cos || !rope_sin) {
        aligned_free(next_storage);
        aligned_free(block_normed);
        aligned_free(block_attn);
        aligned_free(self_q);
        aligned_free(self_k);
        aligned_free(self_v);
        aligned_free(self_ctx_out);
        aligned_free(rope_cos);
        aligned_free(rope_sin);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in encoder");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    build_rope_tables(rope_cos, rope_sin, seq_len, head_dim, ctx->config.rope_theta);

    float embed_scale = sqrtf((float)d_model);
    int rc = NEEDLE_OK;
    unsigned long long profile_t = profile_start();
    for (int t = 0; t < seq_len; t++) {
        int got = needle_embedding_lookup(ctx, token_ids[t], cur + (size_t)t * (size_t)d_model, d_model);
        if (got != d_model) {
            rc = got < 0 ? got : NEEDLE_ERR_FORMAT;
            goto done;
        }
        for (int d = 0; d < d_model; d++) {
            cur[(size_t)t * (size_t)d_model + (size_t)d] *= embed_scale;
        }
    }
    profile_end(NEEDLE_PROFILE_ENCODER_EMBEDDING, profile_t);

    if (callback && !callback(0, layers, user_data)) {
        set_error(ctx, NEEDLE_ERR_CANCELLED, "encoder cancelled");
        rc = NEEDLE_ERR_CANCELLED;
        goto done;
    }

    for (int layer = 0; layer < layers; layer++) {
        rc = encoder_block_impl(
            ctx, layer, cur, seq_len, next, (int)n,
            block_normed, block_attn, self_q, self_k, self_v, self_ctx_out, rope_cos, rope_sin);
        if (rc != NEEDLE_OK) {
            goto done;
        }
        float *tmp = cur;
        cur = next;
        next = tmp;
        if (callback && !callback(layer + 1, layers, user_data)) {
            set_error(ctx, NEEDLE_ERR_CANCELLED, "encoder cancelled");
            rc = NEEDLE_ERR_CANCELLED;
            goto done;
        }
    }

    profile_t = profile_start();
    needle_tensor *final_norm = find_tensor_ptr(ctx, "encoder/final_norm/scale");
    if (!final_norm || zcrmsnorm_model_final_inplace(cur, seq_len, d_model, final_norm) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "encoder final norm tensor is missing or invalid");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    profile_end(NEEDLE_PROFILE_ENCODER_FINAL_NORM, profile_t);

    if (cur != out) {
        memcpy(out, cur, n * sizeof(float));
    }
    set_error(ctx, NEEDLE_OK, NULL);
    rc = (int)n;

done:
    aligned_free(next_storage);
    aligned_free(block_normed);
    aligned_free(block_attn);
    aligned_free(self_q);
    aligned_free(self_k);
    aligned_free(self_v);
    aligned_free(self_ctx_out);
    aligned_free(rope_cos);
    aligned_free(rope_sin);
    return rc;
}

int needle_encode_tokens_f32(
    needle_ctx *ctx,
    const int *token_ids,
    int seq_len,
    float *out,
    int out_cap) {
    return encode_tokens_f32_cancellable(ctx, token_ids, seq_len, out, out_cap, NULL, NULL);
}

static needle_tensor *find_named_layer_tensor(needle_ctx *ctx, const char *scope, const char *suffix) {
    char name[256];
    snprintf(name, sizeof(name), "%s/%s", scope, suffix);
    return find_tensor_ptr(ctx, name);
}

static int decoder_self_attention_impl(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    int causal,
    float *out,
    int out_cap,
    float *scratch_q,
    float *scratch_k,
    float *scratch_v,
    float *scratch_ctx_out) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    if (!x || !out || seq_len <= 0 || d_model <= 0 || heads <= 0 || kv_heads <= 0 ||
        (d_model % heads) != 0 || (heads % kv_heads) != 0 || out_cap < seq_len * d_model ||
        layer < 0 || layer >= cfg->num_decoder_layers) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid decoder self-attention arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    if ((head_dim % 2) != 0) {
        set_error(ctx, NEEDLE_ERR_UNSUPPORTED, "odd attention head dimensions are not supported");
        return NEEDLE_ERR_UNSUPPORTED;
    }

    const char *scope = "decoder/layers/DecoderBlock_0/self_attn";
    needle_tensor *q_kernel = find_named_layer_tensor(ctx, scope, "q_proj/kernel");
    needle_tensor *k_kernel = find_named_layer_tensor(ctx, scope, "k_proj/kernel");
    needle_tensor *v_kernel = find_named_layer_tensor(ctx, scope, "v_proj/kernel");
    needle_tensor *out_kernel = find_named_layer_tensor(ctx, scope, "out_proj/kernel");
    needle_tensor *q_scale = find_named_layer_tensor(ctx, scope, "q_norm/scale");
    needle_tensor *k_scale = find_named_layer_tensor(ctx, scope, "k_norm/scale");
    if (!q_kernel || !k_kernel || !v_kernel || !out_kernel || !q_scale || !k_scale) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder self-attention tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t q_size = (size_t)seq_len * (size_t)d_model;
    size_t kv_size = (size_t)seq_len * (size_t)kv_dim;
    int owns_scratch = (!scratch_q || !scratch_k || !scratch_v || !scratch_ctx_out);
    float *q = owns_scratch ? calloc_floats(q_size) : scratch_q;
    float *k = owns_scratch ? calloc_floats(kv_size) : scratch_k;
    float *v = owns_scratch ? calloc_floats(kv_size) : scratch_v;
    float *ctx_out = owns_scratch ? calloc_floats(q_size) : scratch_ctx_out;
    if (!q || !k || !v || !ctx_out) {
        if (owns_scratch) {
            aligned_free(q); aligned_free(k); aligned_free(v); aligned_free(ctx_out);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in decoder self-attention");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    if (!owns_scratch) {
        memset(ctx_out, 0, q_size * sizeof(float));
    }

    int rc = NEEDLE_OK;
    if (dense_project_layer(ctx, x, q, seq_len, d_model, d_model, q_kernel, layer) != 0 ||
        dense_project_layer(ctx, x, k, seq_len, d_model, kv_dim, k_kernel, layer) != 0 ||
        dense_project_layer(ctx, x, v, seq_len, d_model, kv_dim, v_kernel, layer) != 0 ||
        zcrmsnorm_heads_inplace(q, seq_len, heads, head_dim, q_scale, layer) != 0 ||
        zcrmsnorm_heads_inplace(k, seq_len, kv_heads, head_dim, k_scale, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder self-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }

    apply_rope_seq_heads(q, seq_len, heads, head_dim, cfg->rope_theta);
    apply_rope_seq_heads(k, seq_len, kv_heads, head_dim, cfg->rope_theta);

    int repeats = heads / kv_heads;
    float inv_sqrt = 1.0f / sqrtf((float)head_dim);
    for (int h = 0; h < heads; h++) {
        int kh = h / repeats;
        for (int tq = 0; tq < seq_len; tq++) {
            float max_score = -3.402823466e38f;
            int any = 0;
            for (int tk = 0; tk < seq_len; tk++) {
                if (causal && tk > tq) {
                    continue;
                }
                size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                if (score > max_score) max_score = score;
                any = 1;
            }
            if (!any) {
                continue;
            }

            double denom = 0.0;
            for (int tk = 0; tk < seq_len; tk++) {
                if (causal && tk > tq) {
                    continue;
                }
                size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                float weight = expf(score - max_score);
                denom += (double)weight;
                for (int d = 0; d < head_dim; d++) {
                    float vv = v[((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim + (size_t)d];
                    ctx_out[((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim + (size_t)d] += weight * vv;
                }
            }
            float inv = denom > 0.0 ? (float)(1.0 / denom) : 0.0f;
            for (int d = 0; d < head_dim; d++) {
                ctx_out[((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim + (size_t)d] *= inv;
            }
        }
    }

    if (dense_project_layer(ctx, ctx_out, out, seq_len, d_model, d_model, out_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder self-attention output projection shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    set_error(ctx, NEEDLE_OK, NULL);

done:
    if (owns_scratch) {
        aligned_free(q);
        aligned_free(k);
        aligned_free(v);
        aligned_free(ctx_out);
    }
    return rc;
}

int needle_decoder_self_attention_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    int causal,
    float *out,
    int out_cap) {
    return decoder_self_attention_impl(
        ctx, layer, x, seq_len, causal, out, out_cap, NULL, NULL, NULL, NULL);
}

static int decoder_self_attention_cached_step_impl(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int layer,
    const float *x,
    float *out,
    int out_cap,
    int position,
    int advance,
    float *scratch_q,
    float *scratch_k,
    float *scratch_v,
    float *scratch_ctx_out) {
    if (!ctx || !cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    if (cache->ctx != ctx) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "KV cache belongs to a different context");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    if (!x || !out || d_model <= 0 || heads <= 0 || kv_heads <= 0 ||
        (d_model % heads) != 0 || (heads % kv_heads) != 0 ||
        out_cap < d_model || layer < 0 || layer >= cfg->num_decoder_layers ||
        layer >= cache->layers || position < 0 || position >= cache->max_tokens) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid cached decoder self-attention arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    if ((head_dim % 2) != 0 || head_dim != cache->head_dim || kv_heads != cache->kv_heads || kv_dim != cache->kv_dim) {
        set_error(ctx, NEEDLE_ERR_UNSUPPORTED, "KV cache dimensions do not match model");
        return NEEDLE_ERR_UNSUPPORTED;
    }

    const char *scope = "decoder/layers/DecoderBlock_0/self_attn";
    needle_tensor *q_kernel = find_named_layer_tensor(ctx, scope, "q_proj/kernel");
    needle_tensor *k_kernel = find_named_layer_tensor(ctx, scope, "k_proj/kernel");
    needle_tensor *v_kernel = find_named_layer_tensor(ctx, scope, "v_proj/kernel");
    needle_tensor *out_kernel = find_named_layer_tensor(ctx, scope, "out_proj/kernel");
    needle_tensor *q_scale = find_named_layer_tensor(ctx, scope, "q_norm/scale");
    needle_tensor *k_scale = find_named_layer_tensor(ctx, scope, "k_norm/scale");
    if (!q_kernel || !k_kernel || !v_kernel || !out_kernel || !q_scale || !k_scale) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder self-attention tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    int owns_scratch = (!scratch_q || !scratch_k || !scratch_v || !scratch_ctx_out);
    float *q = owns_scratch ? calloc_floats((size_t)d_model) : scratch_q;
    float *k = owns_scratch ? calloc_floats((size_t)kv_dim) : scratch_k;
    float *v = owns_scratch ? calloc_floats((size_t)kv_dim) : scratch_v;
    float *ctx_out = owns_scratch ? calloc_floats((size_t)d_model) : scratch_ctx_out;
    if (!q || !k || !v || !ctx_out) {
        if (owns_scratch) {
            aligned_free(q); aligned_free(k); aligned_free(v); aligned_free(ctx_out);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in cached decoder self-attention");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    if (!owns_scratch) {
        memset(ctx_out, 0, (size_t)d_model * sizeof(float));
    }

    int rc = NEEDLE_OK;
    int pos = position;
    if (dense_project_layer(ctx, x, q, 1, d_model, d_model, q_kernel, layer) != 0 ||
        dense_project_layer(ctx, x, k, 1, d_model, kv_dim, k_kernel, layer) != 0 ||
        dense_project_layer(ctx, x, v, 1, d_model, kv_dim, v_kernel, layer) != 0 ||
        zcrmsnorm_heads_inplace(q, 1, heads, head_dim, q_scale, layer) != 0 ||
        zcrmsnorm_heads_inplace(k, 1, kv_heads, head_dim, k_scale, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid cached decoder self-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }

    apply_rope_heads_at_position(q, pos, heads, head_dim, cfg->rope_theta);
    apply_rope_heads_at_position(k, pos, kv_heads, head_dim, cfg->rope_theta);

    size_t base = ((size_t)layer * (size_t)cache->max_tokens + (size_t)pos) * (size_t)kv_dim;
    memcpy(cache->self_k + base, k, (size_t)kv_dim * sizeof(float));
    memcpy(cache->self_v + base, v, (size_t)kv_dim * sizeof(float));

    int repeats = heads / kv_heads;
    float inv_sqrt = 1.0f / sqrtf((float)head_dim);
    int kv_len = pos + 1;
    size_t layer_base = (size_t)layer * (size_t)cache->max_tokens * (size_t)kv_dim;
    for (int h = 0; h < heads; h++) {
        int kh = h / repeats;
        float max_score = -3.402823466e38f;
        size_t q_off = (size_t)h * (size_t)head_dim;
        for (int tk = 0; tk < kv_len; tk++) {
            size_t kv_off = layer_base + (size_t)tk * (size_t)kv_dim + (size_t)kh * (size_t)head_dim;
            float score = attention_dot(q, cache->self_k, q_off, kv_off, head_dim) * inv_sqrt;
            if (score > max_score) max_score = score;
        }

        double denom = 0.0;
        for (int tk = 0; tk < kv_len; tk++) {
            size_t kv_off = layer_base + (size_t)tk * (size_t)kv_dim + (size_t)kh * (size_t)head_dim;
            float score = attention_dot(q, cache->self_k, q_off, kv_off, head_dim) * inv_sqrt;
            float weight = expf(score - max_score);
            denom += (double)weight;
            for (int d = 0; d < head_dim; d++) {
                float vv = cache->self_v[kv_off + (size_t)d];
                ctx_out[(size_t)h * (size_t)head_dim + (size_t)d] += weight * vv;
            }
        }
        float inv = denom > 0.0 ? (float)(1.0 / denom) : 0.0f;
        for (int d = 0; d < head_dim; d++) {
            ctx_out[(size_t)h * (size_t)head_dim + (size_t)d] *= inv;
        }
    }

    if (dense_project_layer(ctx, ctx_out, out, 1, d_model, d_model, out_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid cached decoder self-attention output projection shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    if (advance) {
        cache->token_count = kv_len;
    }
    set_error(ctx, NEEDLE_OK, NULL);
    rc = d_model;

done:
    if (owns_scratch) {
        aligned_free(q);
        aligned_free(k);
        aligned_free(v);
        aligned_free(ctx_out);
    }
    return rc;
}

int needle_decoder_self_attention_cached_step_f32(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int layer,
    const float *x,
    float *out,
    int out_cap) {
    if (!cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    return decoder_self_attention_cached_step_impl(
        ctx, cache, layer, x, out, out_cap, cache->token_count, 1,
        NULL, NULL, NULL, NULL);
}

static int decoder_cross_attention_impl(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap,
    float *scratch_q,
    float *scratch_k,
    float *scratch_v,
    float *scratch_ctx_out) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    if (!x || !encoder_out || !out || seq_len <= 0 || enc_len <= 0 ||
        d_model <= 0 || heads <= 0 || kv_heads <= 0 || (d_model % heads) != 0 ||
        (heads % kv_heads) != 0 || out_cap < seq_len * d_model ||
        layer < 0 || layer >= cfg->num_decoder_layers) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid decoder cross-attention arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    const char *scope = "decoder/layers/DecoderBlock_0/cross_attn";
    needle_tensor *q_kernel = find_named_layer_tensor(ctx, scope, "q_proj/kernel");
    needle_tensor *k_kernel = find_named_layer_tensor(ctx, scope, "k_proj/kernel");
    needle_tensor *v_kernel = find_named_layer_tensor(ctx, scope, "v_proj/kernel");
    needle_tensor *out_kernel = find_named_layer_tensor(ctx, scope, "out_proj/kernel");
    needle_tensor *q_scale = find_named_layer_tensor(ctx, scope, "q_norm/scale");
    needle_tensor *k_scale = find_named_layer_tensor(ctx, scope, "k_norm/scale");
    if (!q_kernel || !k_kernel || !v_kernel || !out_kernel || !q_scale || !k_scale) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder cross-attention tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t q_size = (size_t)seq_len * (size_t)d_model;
    size_t kv_size = (size_t)enc_len * (size_t)kv_dim;
    int owns_scratch = (!scratch_q || !scratch_k || !scratch_v || !scratch_ctx_out);
    float *q = owns_scratch ? calloc_floats(q_size) : scratch_q;
    float *k = owns_scratch ? calloc_floats(kv_size) : scratch_k;
    float *v = owns_scratch ? calloc_floats(kv_size) : scratch_v;
    float *ctx_out = owns_scratch ? calloc_floats(q_size) : scratch_ctx_out;
    if (!q || !k || !v || !ctx_out) {
        if (owns_scratch) {
            aligned_free(q); aligned_free(k); aligned_free(v); aligned_free(ctx_out);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in decoder cross-attention");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    if (!owns_scratch) {
        memset(ctx_out, 0, q_size * sizeof(float));
    }

    int rc = NEEDLE_OK;
    if (dense_project_layer(ctx, x, q, seq_len, d_model, d_model, q_kernel, layer) != 0 ||
        dense_project_layer(ctx, encoder_out, k, enc_len, d_model, kv_dim, k_kernel, layer) != 0 ||
        dense_project_layer(ctx, encoder_out, v, enc_len, d_model, kv_dim, v_kernel, layer) != 0 ||
        zcrmsnorm_heads_inplace(q, seq_len, heads, head_dim, q_scale, layer) != 0 ||
        zcrmsnorm_heads_inplace(k, enc_len, kv_heads, head_dim, k_scale, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder cross-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }

    int repeats = heads / kv_heads;
    float inv_sqrt = 1.0f / sqrtf((float)head_dim);
    for (int h = 0; h < heads; h++) {
        int kh = h / repeats;
        for (int tq = 0; tq < seq_len; tq++) {
            float max_score = -3.402823466e38f;
            for (int tk = 0; tk < enc_len; tk++) {
                size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                if (score > max_score) max_score = score;
            }

            double denom = 0.0;
            for (int tk = 0; tk < enc_len; tk++) {
                size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                float weight = expf(score - max_score);
                denom += (double)weight;
                for (int d = 0; d < head_dim; d++) {
                    float vv = v[((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim + (size_t)d];
                    ctx_out[((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim + (size_t)d] += weight * vv;
                }
            }
            float inv = denom > 0.0 ? (float)(1.0 / denom) : 0.0f;
            for (int d = 0; d < head_dim; d++) {
                ctx_out[((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim + (size_t)d] *= inv;
            }
        }
    }

    if (dense_project_layer(ctx, ctx_out, out, seq_len, d_model, d_model, out_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder cross-attention output projection shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    set_error(ctx, NEEDLE_OK, NULL);

done:
    if (owns_scratch) {
        aligned_free(q);
        aligned_free(k);
        aligned_free(v);
        aligned_free(ctx_out);
    }
    return rc;
}

static int decoder_cross_attention_precomputed_kv_impl(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    int enc_len,
    const float *k,
    const float *v,
    float *out,
    int out_cap,
    float *scratch_q,
    float *scratch_ctx_out) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    if (!x || !k || !v || !out || seq_len <= 0 || enc_len <= 0 ||
        d_model <= 0 || heads <= 0 || kv_heads <= 0 || (d_model % heads) != 0 ||
        (heads % kv_heads) != 0 || out_cap < seq_len * d_model ||
        layer < 0 || layer >= cfg->num_decoder_layers) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid precomputed decoder cross-attention arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    const char *scope = "decoder/layers/DecoderBlock_0/cross_attn";
    needle_tensor *q_kernel = find_named_layer_tensor(ctx, scope, "q_proj/kernel");
    needle_tensor *out_kernel = find_named_layer_tensor(ctx, scope, "out_proj/kernel");
    needle_tensor *q_scale = find_named_layer_tensor(ctx, scope, "q_norm/scale");
    if (!q_kernel || !out_kernel || !q_scale) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder cross-attention tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t q_size = (size_t)seq_len * (size_t)d_model;
    int owns_scratch = (!scratch_q || !scratch_ctx_out);
    float *q = owns_scratch ? calloc_floats(q_size) : scratch_q;
    float *ctx_out = owns_scratch ? calloc_floats(q_size) : scratch_ctx_out;
    if (!q || !ctx_out) {
        if (owns_scratch) {
            aligned_free(q); aligned_free(ctx_out);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in precomputed decoder cross-attention");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    if (!owns_scratch) {
        memset(ctx_out, 0, q_size * sizeof(float));
    }

    int rc = NEEDLE_OK;
    if (dense_project_layer(ctx, x, q, seq_len, d_model, d_model, q_kernel, layer) != 0 ||
        zcrmsnorm_heads_inplace(q, seq_len, heads, head_dim, q_scale, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid precomputed decoder cross-attention tensor shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }

    int repeats = heads / kv_heads;
    float inv_sqrt = 1.0f / sqrtf((float)head_dim);
    for (int h = 0; h < heads; h++) {
        int kh = h / repeats;
        for (int tq = 0; tq < seq_len; tq++) {
            float max_score = -3.402823466e38f;
            for (int tk = 0; tk < enc_len; tk++) {
                size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                if (score > max_score) max_score = score;
            }

            double denom = 0.0;
            for (int tk = 0; tk < enc_len; tk++) {
                size_t q_off = ((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim;
                size_t k_off = ((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim;
                float score = attention_dot(q, k, q_off, k_off, head_dim) * inv_sqrt;
                float weight = expf(score - max_score);
                denom += (double)weight;
                for (int d = 0; d < head_dim; d++) {
                    float vv = v[((size_t)tk * (size_t)kv_heads + (size_t)kh) * (size_t)head_dim + (size_t)d];
                    ctx_out[((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim + (size_t)d] += weight * vv;
                }
            }
            float inv = denom > 0.0 ? (float)(1.0 / denom) : 0.0f;
            for (int d = 0; d < head_dim; d++) {
                ctx_out[((size_t)tq * (size_t)heads + (size_t)h) * (size_t)head_dim + (size_t)d] *= inv;
            }
        }
    }

    if (dense_project_layer(ctx, ctx_out, out, seq_len, d_model, d_model, out_kernel, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid precomputed decoder cross-attention output projection shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    set_error(ctx, NEEDLE_OK, NULL);

done:
    if (owns_scratch) {
        aligned_free(q);
        aligned_free(ctx_out);
    }
    return rc;
}

static int precompute_decoder_cross_attention_kv(
    needle_ctx *ctx,
    const float *encoder_out,
    int enc_len,
    float *k_cache,
    float *v_cache) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    needle_config *cfg = &ctx->config;
    int d_model = cfg->d_model;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    int layers = cfg->num_decoder_layers;
    if (!encoder_out || !k_cache || !v_cache || enc_len <= 0 || d_model <= 0 ||
        heads <= 0 || kv_heads <= 0 || layers <= 0 || (d_model % heads) != 0 ||
        (heads % kv_heads) != 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid decoder cross-attention KV precompute arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    const char *scope = "decoder/layers/DecoderBlock_0/cross_attn";
    needle_tensor *k_kernel = find_named_layer_tensor(ctx, scope, "k_proj/kernel");
    needle_tensor *v_kernel = find_named_layer_tensor(ctx, scope, "v_proj/kernel");
    needle_tensor *k_scale = find_named_layer_tensor(ctx, scope, "k_norm/scale");
    if (!k_kernel || !v_kernel || !k_scale) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder cross-attention KV tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t layer_elems = (size_t)enc_len * (size_t)kv_dim;
    for (int layer = 0; layer < layers; layer++) {
        float *k = k_cache + (size_t)layer * layer_elems;
        float *v = v_cache + (size_t)layer * layer_elems;
        if (dense_project_layer(ctx, encoder_out, k, enc_len, d_model, kv_dim, k_kernel, layer) != 0 ||
            dense_project_layer(ctx, encoder_out, v, enc_len, d_model, kv_dim, v_kernel, layer) != 0 ||
            zcrmsnorm_heads_inplace(k, enc_len, kv_heads, head_dim, k_scale, layer) != 0) {
            set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder cross-attention KV precompute tensor shape");
            return NEEDLE_ERR_FORMAT;
        }
    }
    set_error(ctx, NEEDLE_OK, NULL);
    return NEEDLE_OK;
}

int needle_decoder_cross_attention_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap) {
    return decoder_cross_attention_impl(
        ctx, layer, x, seq_len, encoder_out, enc_len, out, out_cap, NULL, NULL, NULL, NULL);
}

static int decoder_block_impl(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap,
    float *scratch_normed,
    float *scratch_attn,
    float *scratch_hidden,
    float *self_q,
    float *self_k,
    float *self_v,
    float *self_ctx_out,
    float *cross_q,
    float *cross_k,
    float *cross_v,
    float *cross_ctx_out) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    if (!x || !encoder_out || !out || seq_len <= 0 || enc_len <= 0 ||
        d_model <= 0 || out_cap < seq_len * d_model ||
        layer < 0 || layer >= ctx->config.num_decoder_layers) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid decoder block arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    needle_tensor *self_norm = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/ZCRMSNorm_0/scale");
    needle_tensor *cross_norm = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/ZCRMSNorm_1/scale");
    needle_tensor *self_gate_t = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/self_attn_gate");
    needle_tensor *cross_gate_t = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/cross_attn_gate");
    if (!self_norm || !cross_norm || !self_gate_t || !cross_gate_t) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder block tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    size_t n = (size_t)seq_len * (size_t)d_model;
    int owns_scratch = (!scratch_normed || !scratch_attn || !scratch_hidden);
    float *normed = owns_scratch ? alloc_floats(n) : scratch_normed;
    float *attn = owns_scratch ? alloc_floats(n) : scratch_attn;
    float *hidden = owns_scratch ? alloc_floats(n) : scratch_hidden;
    if (!normed || !attn || !hidden) {
        if (owns_scratch) {
            aligned_free(normed); aligned_free(attn); aligned_free(hidden);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in decoder block");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }

    int rc = NEEDLE_OK;
    memcpy(normed, x, n * sizeof(float));
    if (zcrmsnorm_model_inplace(normed, seq_len, d_model, self_norm, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder self norm shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    rc = decoder_self_attention_impl(
        ctx, layer, normed, seq_len, 1, attn, (int)n, self_q, self_k, self_v, self_ctx_out);
    if (rc != NEEDLE_OK) {
        goto done;
    }
    float self_gate_raw = 0.0f;
    if (read_layer_scalar_value(self_gate_t, layer, &self_gate_raw) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder self gate shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    float self_gate = 1.0f / (1.0f + expf(-self_gate_raw));
    for (size_t i = 0; i < n; i++) {
        hidden[i] = x[i] + self_gate * attn[i];
    }

    memcpy(normed, hidden, n * sizeof(float));
    if (zcrmsnorm_model_inplace(normed, seq_len, d_model, cross_norm, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder cross norm shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    rc = decoder_cross_attention_impl(
        ctx, layer, normed, seq_len, encoder_out, enc_len, attn, (int)n,
        cross_q, cross_k, cross_v, cross_ctx_out);
    if (rc != NEEDLE_OK) {
        goto done;
    }
    float cross_gate_raw = 0.0f;
    if (read_layer_scalar_value(cross_gate_t, layer, &cross_gate_raw) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid decoder cross gate shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    float cross_gate = 1.0f / (1.0f + expf(-cross_gate_raw));
    for (size_t i = 0; i < n; i++) {
        out[i] = hidden[i] + cross_gate * attn[i];
    }
    set_error(ctx, NEEDLE_OK, NULL);

done:
    if (owns_scratch) {
        aligned_free(normed);
        aligned_free(attn);
        aligned_free(hidden);
    }
    return rc;
}

int needle_decoder_block_f32(
    needle_ctx *ctx,
    int layer,
    const float *x,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap) {
    return decoder_block_impl(
        ctx, layer, x, seq_len, encoder_out, enc_len, out, out_cap,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}

static int decoder_block_cached_step_impl(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int layer,
    const float *x,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap,
    int position,
    int advance,
    float *scratch_normed,
    float *scratch_attn,
    float *scratch_hidden,
    float *self_q,
    float *self_k,
    float *self_v,
    float *self_ctx_out,
    float *cross_q,
    float *cross_k,
    float *cross_v,
    float *cross_ctx_out,
    const float *precomputed_cross_k,
    const float *precomputed_cross_v,
    size_t precomputed_cross_layer_elems) {
    if (!ctx || !cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    if (!x || !encoder_out || !out || enc_len <= 0 || d_model <= 0 || out_cap < d_model ||
        layer < 0 || layer >= ctx->config.num_decoder_layers || cache->ctx != ctx) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid cached decoder block arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    needle_tensor *self_norm = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/ZCRMSNorm_0/scale");
    needle_tensor *cross_norm = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/ZCRMSNorm_1/scale");
    needle_tensor *self_gate_t = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/self_attn_gate");
    needle_tensor *cross_gate_t = find_tensor_ptr(ctx, "decoder/layers/DecoderBlock_0/cross_attn_gate");
    if (!self_norm || !cross_norm || !self_gate_t || !cross_gate_t) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder block tensors are missing");
        return NEEDLE_ERR_FORMAT;
    }

    int owns_scratch = (!scratch_normed || !scratch_attn || !scratch_hidden);
    float *normed = owns_scratch ? alloc_floats((size_t)d_model) : scratch_normed;
    float *attn = owns_scratch ? alloc_floats((size_t)d_model) : scratch_attn;
    float *hidden = owns_scratch ? alloc_floats((size_t)d_model) : scratch_hidden;
    if (!normed || !attn || !hidden) {
        if (owns_scratch) {
            aligned_free(normed); aligned_free(attn); aligned_free(hidden);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in cached decoder block");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }

    int rc = NEEDLE_OK;
    int old_token_count = cache->token_count;
    memcpy(normed, x, (size_t)d_model * sizeof(float));
    if (zcrmsnorm_model_inplace(normed, 1, d_model, self_norm, layer) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid cached decoder self norm shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    rc = decoder_self_attention_cached_step_impl(
        ctx, cache, layer, normed, attn, d_model, position, advance,
        self_q, self_k, self_v, self_ctx_out);
    if (rc < 0) {
        goto done;
    }

    float self_gate_raw = 0.0f;
    if (read_layer_scalar_value(self_gate_t, layer, &self_gate_raw) != 0) {
        if (advance) cache->token_count = old_token_count;
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid cached decoder self gate shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    float self_gate = 1.0f / (1.0f + expf(-self_gate_raw));
    for (int i = 0; i < d_model; i++) {
        hidden[i] = x[i] + self_gate * attn[i];
    }

    memcpy(normed, hidden, (size_t)d_model * sizeof(float));
    if (zcrmsnorm_model_inplace(normed, 1, d_model, cross_norm, layer) != 0) {
        if (advance) cache->token_count = old_token_count;
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid cached decoder cross norm shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    if (precomputed_cross_k && precomputed_cross_v && precomputed_cross_layer_elems > 0) {
        rc = decoder_cross_attention_precomputed_kv_impl(
            ctx, layer, normed, 1, enc_len,
            precomputed_cross_k + (size_t)layer * precomputed_cross_layer_elems,
            precomputed_cross_v + (size_t)layer * precomputed_cross_layer_elems,
            attn, d_model, cross_q, cross_ctx_out);
    } else {
        rc = decoder_cross_attention_impl(
            ctx, layer, normed, 1, encoder_out, enc_len, attn, d_model,
            cross_q, cross_k, cross_v, cross_ctx_out);
    }
    if (rc != NEEDLE_OK) {
        if (advance) cache->token_count = old_token_count;
        goto done;
    }

    float cross_gate_raw = 0.0f;
    if (read_layer_scalar_value(cross_gate_t, layer, &cross_gate_raw) != 0) {
        cache->token_count = old_token_count;
        set_error(ctx, NEEDLE_ERR_FORMAT, "invalid cached decoder cross gate shape");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }
    float cross_gate = 1.0f / (1.0f + expf(-cross_gate_raw));
    for (int i = 0; i < d_model; i++) {
        out[i] = hidden[i] + cross_gate * attn[i];
    }
    set_error(ctx, NEEDLE_OK, NULL);
    rc = d_model;

done:
    if (owns_scratch) {
        aligned_free(normed);
        aligned_free(attn);
        aligned_free(hidden);
    }
    return rc;
}

int needle_decoder_block_cached_step_f32(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int layer,
    const float *x,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap) {
    if (!cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    return decoder_block_cached_step_impl(
        ctx, cache, layer, x, encoder_out, enc_len, out, out_cap, cache->token_count, 1,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0);
}

static int decode_tokens_impl(
    needle_ctx *ctx,
    const int *token_ids,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap,
    float *cur,
    float *next,
    float *block_normed,
    float *block_attn,
    float *block_hidden,
    float *self_q,
    float *self_k,
    float *self_v,
    float *self_ctx_out,
    float *cross_q,
    float *cross_k,
    float *cross_v,
    float *cross_ctx_out) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    int layers = ctx->config.num_decoder_layers;
    int heads = ctx->config.num_heads;
    int kv_heads = ctx->config.num_kv_heads;
    if (!token_ids || !encoder_out || !out || seq_len <= 0 || enc_len <= 0 ||
        d_model <= 0 || layers <= 0 || heads <= 0 || kv_heads <= 0 ||
        (d_model % heads) != 0 || (heads % kv_heads) != 0 ||
        out_cap < seq_len * d_model) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid decoder arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    size_t n = (size_t)seq_len * (size_t)d_model;
    size_t self_kv_n = (size_t)seq_len * (size_t)kv_dim;
    size_t cross_kv_n = (size_t)enc_len * (size_t)kv_dim;
    int owns_scratch = (!cur || !next || !block_normed || !block_attn || !block_hidden ||
        !self_q || !self_k || !self_v || !self_ctx_out ||
        !cross_q || !cross_k || !cross_v || !cross_ctx_out);
    cur = owns_scratch ? alloc_floats(n) : cur;
    next = owns_scratch ? alloc_floats(n) : next;
    block_normed = owns_scratch ? alloc_floats(n) : block_normed;
    block_attn = owns_scratch ? alloc_floats(n) : block_attn;
    block_hidden = owns_scratch ? alloc_floats(n) : block_hidden;
    self_q = owns_scratch ? alloc_floats(n) : self_q;
    self_k = owns_scratch ? alloc_floats(self_kv_n) : self_k;
    self_v = owns_scratch ? alloc_floats(self_kv_n) : self_v;
    self_ctx_out = owns_scratch ? alloc_floats(n) : self_ctx_out;
    cross_q = owns_scratch ? alloc_floats(n) : cross_q;
    cross_k = owns_scratch ? alloc_floats(cross_kv_n) : cross_k;
    cross_v = owns_scratch ? alloc_floats(cross_kv_n) : cross_v;
    cross_ctx_out = owns_scratch ? alloc_floats(n) : cross_ctx_out;
    if (!cur || !next || !block_normed || !block_attn || !block_hidden ||
        !self_q || !self_k || !self_v || !self_ctx_out ||
        !cross_q || !cross_k || !cross_v || !cross_ctx_out) {
        if (owns_scratch) {
            aligned_free(cur);
            aligned_free(next);
            aligned_free(block_normed);
            aligned_free(block_attn);
            aligned_free(block_hidden);
            aligned_free(self_q);
            aligned_free(self_k);
            aligned_free(self_v);
            aligned_free(self_ctx_out);
            aligned_free(cross_q);
            aligned_free(cross_k);
            aligned_free(cross_v);
            aligned_free(cross_ctx_out);
        }
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in decoder");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }

    float embed_scale = sqrtf((float)d_model);
    int rc = NEEDLE_OK;
    for (int t = 0; t < seq_len; t++) {
        int got = needle_embedding_lookup(ctx, token_ids[t], cur + (size_t)t * (size_t)d_model, d_model);
        if (got != d_model) {
            rc = got < 0 ? got : NEEDLE_ERR_FORMAT;
            goto done;
        }
        for (int d = 0; d < d_model; d++) {
            cur[(size_t)t * (size_t)d_model + (size_t)d] *= embed_scale;
        }
    }

    for (int layer = 0; layer < layers; layer++) {
        rc = decoder_block_impl(
            ctx, layer, cur, seq_len, encoder_out, enc_len, next, (int)n,
            block_normed, block_attn, block_hidden,
            self_q, self_k, self_v, self_ctx_out,
            cross_q, cross_k, cross_v, cross_ctx_out);
        if (rc != NEEDLE_OK) {
            goto done;
        }
        float *tmp = cur;
        cur = next;
        next = tmp;
    }

    needle_tensor *final_norm = find_tensor_ptr(ctx, "decoder/ZCRMSNorm_0/scale");
    if (!final_norm || zcrmsnorm_model_final_inplace(cur, seq_len, d_model, final_norm) != 0) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder final norm tensor is missing or invalid");
        rc = NEEDLE_ERR_FORMAT;
        goto done;
    }

    memcpy(out, cur, n * sizeof(float));
    set_error(ctx, NEEDLE_OK, NULL);
    rc = (int)n;

done:
    if (owns_scratch) {
        aligned_free(cur);
        aligned_free(next);
        aligned_free(block_normed);
        aligned_free(block_attn);
        aligned_free(block_hidden);
        aligned_free(self_q);
        aligned_free(self_k);
        aligned_free(self_v);
        aligned_free(self_ctx_out);
        aligned_free(cross_q);
        aligned_free(cross_k);
        aligned_free(cross_v);
        aligned_free(cross_ctx_out);
    }
    return rc;
}

int needle_decode_tokens_f32(
    needle_ctx *ctx,
    const int *token_ids,
    int seq_len,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap) {
    return decode_tokens_impl(
        ctx, token_ids, seq_len, encoder_out, enc_len, out, out_cap,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}

static int decode_token_cached_step_impl(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int token_id,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap,
    float *cur,
    float *next,
    float *block_normed,
    float *block_attn,
    float *block_hidden,
    float *self_q,
    float *self_k,
    float *self_v,
    float *self_ctx_out,
    float *cross_q,
    float *cross_k,
    float *cross_v,
    float *cross_ctx_out,
    const float *precomputed_cross_k,
    const float *precomputed_cross_v,
    size_t precomputed_cross_layer_elems) {
    if (!ctx || !cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    int layers = ctx->config.num_decoder_layers;
    if (!encoder_out || !out || !cur || !next || enc_len <= 0 || d_model <= 0 || layers <= 0 ||
        out_cap < d_model || cache->ctx != ctx || cache->token_count < 0 ||
        cache->token_count >= cache->max_tokens) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid cached decoder step arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int old_token_count = cache->token_count;
    int rc = needle_embedding_lookup(ctx, token_id, cur, d_model);
    if (rc != d_model) {
        rc = rc < 0 ? rc : NEEDLE_ERR_FORMAT;
        return rc;
    }
    float embed_scale = sqrtf((float)d_model);
    for (int d = 0; d < d_model; d++) {
        cur[d] *= embed_scale;
    }

    rc = NEEDLE_OK;
    for (int layer = 0; layer < layers; layer++) {
        rc = decoder_block_cached_step_impl(
            ctx, cache, layer, cur, encoder_out, enc_len, next, d_model, old_token_count, 0,
            block_normed, block_attn, block_hidden, self_q, self_k, self_v, self_ctx_out,
            cross_q, cross_k, cross_v, cross_ctx_out,
            precomputed_cross_k, precomputed_cross_v, precomputed_cross_layer_elems);
        if (rc < 0) {
            cache->token_count = old_token_count;
            return rc;
        }
        float *tmp = cur;
        cur = next;
        next = tmp;
    }

    needle_tensor *final_norm = find_tensor_ptr(ctx, "decoder/ZCRMSNorm_0/scale");
    if (!final_norm || zcrmsnorm_model_final_inplace(cur, 1, d_model, final_norm) != 0) {
        cache->token_count = old_token_count;
        set_error(ctx, NEEDLE_ERR_FORMAT, "decoder final norm tensor is missing or invalid");
        return NEEDLE_ERR_FORMAT;
    }
    memcpy(out, cur, (size_t)d_model * sizeof(float));
    cache->token_count = old_token_count + 1;
    set_error(ctx, NEEDLE_OK, NULL);
    return d_model;
}

int needle_decode_token_cached_step_f32(
    needle_ctx *ctx,
    needle_kv_cache *cache,
    int token_id,
    const float *encoder_out,
    int enc_len,
    float *out,
    int out_cap) {
    if (!ctx || !cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    if (d_model <= 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid cached decoder step arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    float *cur = alloc_floats((size_t)d_model);
    float *next = alloc_floats((size_t)d_model);
    if (!cur || !next) {
        aligned_free(cur);
        aligned_free(next);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in cached decoder step");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    int rc = decode_token_cached_step_impl(
        ctx, cache, token_id, encoder_out, enc_len, out, out_cap, cur, next,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0);
    aligned_free(cur);
    aligned_free(next);
    return rc;
}

int needle_forward_logits_f32(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    const int *tgt_ids,
    int tgt_len,
    float *out,
    int out_cap) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    int vocab_size = ctx->config.vocab_size;
    if (!src_ids || !tgt_ids || !out || src_len <= 0 || tgt_len <= 0 ||
        d_model <= 0 || vocab_size <= 0 || out_cap < tgt_len * vocab_size) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid forward arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    size_t enc_n = (size_t)src_len * (size_t)d_model;
    size_t dec_n = (size_t)tgt_len * (size_t)d_model;
    float *encoder = alloc_floats(enc_n);
    float *decoder = alloc_floats(dec_n);
    if (!encoder || !decoder) {
        aligned_free(encoder);
        aligned_free(decoder);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in forward");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }

    int rc = needle_encode_tokens_f32(ctx, src_ids, src_len, encoder, (int)enc_n);
    if (rc < 0) {
        goto done;
    }
    rc = needle_decode_tokens_f32(ctx, tgt_ids, tgt_len, encoder, src_len, decoder, (int)dec_n);
    if (rc < 0) {
        goto done;
    }
    rc = needle_output_projection_f32(ctx, decoder, tgt_len, out, out_cap);

done:
    aligned_free(encoder);
    aligned_free(decoder);
    return rc;
}

needle_encoder_state *needle_encoder_state_create(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len) {
    return needle_encoder_state_create_cancellable(ctx, src_ids, src_len, NULL, NULL);
}

needle_encoder_state *needle_encoder_state_create_cancellable(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    needle_progress_callback callback,
    void *user_data) {
    if (!ctx) {
        return NULL;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NULL;
    }
    int d_model = ctx->config.d_model;
    if (!src_ids || src_len <= 0 || d_model <= 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder state arguments");
        return NULL;
    }
    needle_encoder_state *state = (needle_encoder_state *)calloc(1, sizeof(needle_encoder_state));
    if (!state) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while allocating encoder state");
        return NULL;
    }
    state->encoder_out = alloc_floats((size_t)src_len * (size_t)d_model);
    if (!state->encoder_out) {
        free(state);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while allocating encoder state");
        return NULL;
    }
    int rc = encode_tokens_f32_cancellable(
        ctx, src_ids, src_len, state->encoder_out, src_len * d_model, callback, user_data);
    if (rc < 0) {
        aligned_free(state->encoder_out);
        free(state);
        return NULL;
    }
    state->ctx = ctx;
    state->enc_len = src_len;
    state->d_model = d_model;
    set_error(ctx, NEEDLE_OK, NULL);
    return state;
}

void needle_encoder_state_free(needle_encoder_state *state) {
    if (!state) {
        return;
    }
    aligned_free(state->encoder_out);
    free(state);
}

int needle_encoder_state_len(needle_encoder_state *state) {
    return state ? state->enc_len : 0;
}

int needle_encoder_state_d_model(needle_encoder_state *state) {
    return state ? state->d_model : 0;
}

needle_kv_cache *needle_kv_cache_create(needle_ctx *ctx, int max_tokens) {
    if (!ctx) {
        return NULL;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NULL;
    }
    needle_config *cfg = &ctx->config;
    int layers = cfg->num_decoder_layers;
    int heads = cfg->num_heads;
    int kv_heads = cfg->num_kv_heads;
    int d_model = cfg->d_model;
    if (max_tokens <= 0 || layers <= 0 || heads <= 0 || kv_heads <= 0 ||
        d_model <= 0 || (d_model % heads) != 0 || (heads % kv_heads) != 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid KV cache dimensions");
        return NULL;
    }
    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    if (kv_dim <= 0 ||
        (size_t)layers > SIZE_MAX / (size_t)max_tokens ||
        (size_t)layers * (size_t)max_tokens > SIZE_MAX / (size_t)kv_dim) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "KV cache dimensions overflow");
        return NULL;
    }
    size_t elems = (size_t)layers * (size_t)max_tokens * (size_t)kv_dim;
    if (elems > SIZE_MAX / sizeof(float) / 2U) {
        set_error(ctx, NEEDLE_ERR_FORMAT, "KV cache byte size overflow");
        return NULL;
    }

    needle_kv_cache *cache = (needle_kv_cache *)calloc(1, sizeof(needle_kv_cache));
    if (!cache) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while allocating KV cache");
        return NULL;
    }
    cache->self_k = calloc_floats(elems);
    cache->self_v = calloc_floats(elems);
    if (!cache->self_k || !cache->self_v) {
        aligned_free(cache->self_k);
        aligned_free(cache->self_v);
        free(cache);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while allocating KV cache buffers");
        return NULL;
    }
    cache->ctx = ctx;
    cache->max_tokens = max_tokens;
    cache->layers = layers;
    cache->kv_heads = kv_heads;
    cache->head_dim = head_dim;
    cache->kv_dim = kv_dim;
    cache->bytes = (unsigned long long)(elems * sizeof(float) * 2U);
    set_error(ctx, NEEDLE_OK, NULL);
    return cache;
}

void needle_kv_cache_free(needle_kv_cache *cache) {
    if (!cache) {
        return;
    }
    aligned_free(cache->self_k);
    aligned_free(cache->self_v);
    free(cache);
}

int needle_kv_cache_reset(needle_kv_cache *cache) {
    if (!cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    size_t elems = (size_t)cache->layers * (size_t)cache->max_tokens * (size_t)cache->kv_dim;
    memset(cache->self_k, 0, elems * sizeof(float));
    memset(cache->self_v, 0, elems * sizeof(float));
    cache->token_count = 0;
    return NEEDLE_OK;
}

int needle_kv_cache_set_token_count(needle_kv_cache *cache, int token_count) {
    if (!cache) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (token_count < 0 || token_count > cache->max_tokens) {
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    cache->token_count = token_count;
    return NEEDLE_OK;
}

int needle_kv_cache_token_count(needle_kv_cache *cache) {
    return cache ? cache->token_count : 0;
}

int needle_kv_cache_max_tokens(needle_kv_cache *cache) {
    return cache ? cache->max_tokens : 0;
}

int needle_kv_cache_layer_count(needle_kv_cache *cache) {
    return cache ? cache->layers : 0;
}

int needle_kv_cache_kv_heads(needle_kv_cache *cache) {
    return cache ? cache->kv_heads : 0;
}

int needle_kv_cache_head_dim(needle_kv_cache *cache) {
    return cache ? cache->head_dim : 0;
}

unsigned long long needle_kv_cache_bytes(needle_kv_cache *cache) {
    return cache ? cache->bytes : 0ULL;
}

static int generate_tokens_greedy_impl(
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
    int out_cap) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    int vocab_size = ctx->config.vocab_size;
    int heads = ctx->config.num_heads;
    int kv_heads = ctx->config.num_kv_heads;
    if (!src_ids || !prompt_ids || !out_ids || src_len <= 0 || prompt_len <= 0 ||
        max_new_tokens < 0 || out_cap < prompt_len + max_new_tokens ||
        d_model <= 0 || vocab_size <= 0 || heads <= 0 || kv_heads <= 0 ||
        (d_model % heads) != 0 || (heads % kv_heads) != 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid greedy generation arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;

    int total_cap = prompt_len + max_new_tokens;
    size_t max_dec_n = (size_t)total_cap * (size_t)d_model;
    size_t max_self_kv_n = (size_t)total_cap * (size_t)kv_dim;
    size_t cross_kv_n = (size_t)src_len * (size_t)kv_dim;
    int *tokens = (int *)malloc((size_t)total_cap * sizeof(int));
    float *encoder = alloc_floats((size_t)src_len * (size_t)d_model);
    float *decoder = alloc_floats(max_dec_n);
    float *dec_cur = alloc_floats(max_dec_n);
    float *dec_next = alloc_floats(max_dec_n);
    float *block_normed = alloc_floats(max_dec_n);
    float *block_attn = alloc_floats(max_dec_n);
    float *block_hidden = alloc_floats(max_dec_n);
    float *self_q = alloc_floats(max_dec_n);
    float *self_k = alloc_floats(max_self_kv_n);
    float *self_v = alloc_floats(max_self_kv_n);
    float *self_ctx_out = alloc_floats(max_dec_n);
    float *cross_q = alloc_floats(max_dec_n);
    float *cross_k = alloc_floats(cross_kv_n);
    float *cross_v = alloc_floats(cross_kv_n);
    float *cross_ctx_out = alloc_floats(max_dec_n);
    float *logits = alloc_floats((size_t)vocab_size);
    int *allowed = filter ? (int *)malloc((size_t)vocab_size * sizeof(int)) : NULL;
    if (!tokens || !encoder || !decoder || !dec_cur || !dec_next ||
        !block_normed || !block_attn || !block_hidden ||
        !self_q || !self_k || !self_v || !self_ctx_out ||
        !cross_q || !cross_k || !cross_v || !cross_ctx_out ||
        !logits || (filter && !allowed)) {
        free(tokens);
        aligned_free(encoder);
        aligned_free(decoder);
        aligned_free(dec_cur);
        aligned_free(dec_next);
        aligned_free(block_normed);
        aligned_free(block_attn);
        aligned_free(block_hidden);
        aligned_free(self_q);
        aligned_free(self_k);
        aligned_free(self_v);
        aligned_free(self_ctx_out);
        aligned_free(cross_q);
        aligned_free(cross_k);
        aligned_free(cross_v);
        aligned_free(cross_ctx_out);
        aligned_free(logits);
        free(allowed);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in greedy generation");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    for (int i = 0; i < prompt_len; i++) {
        tokens[i] = prompt_ids[i];
    }

    int rc = needle_encode_tokens_f32(ctx, src_ids, src_len, encoder, src_len * d_model);
    if (rc < 0) {
        free(tokens);
        aligned_free(encoder);
        aligned_free(decoder);
        aligned_free(dec_cur);
        aligned_free(dec_next);
        aligned_free(block_normed);
        aligned_free(block_attn);
        aligned_free(block_hidden);
        aligned_free(self_q);
        aligned_free(self_k);
        aligned_free(self_v);
        aligned_free(self_ctx_out);
        aligned_free(cross_q);
        aligned_free(cross_k);
        aligned_free(cross_v);
        aligned_free(cross_ctx_out);
        aligned_free(logits);
        free(allowed);
        return rc;
    }

    int cur_len = prompt_len;
    for (int step = 0; step < max_new_tokens; step++) {
        size_t dec_n = (size_t)cur_len * (size_t)d_model;

        rc = decode_tokens_impl(
            ctx, tokens, cur_len, encoder, src_len, decoder, (int)dec_n,
            dec_cur, dec_next, block_normed, block_attn, block_hidden,
            self_q, self_k, self_v, self_ctx_out,
            cross_q, cross_k, cross_v, cross_ctx_out);
        if (rc < 0) {
            break;
        }
        float *last_decoder = decoder + (size_t)(cur_len - 1) * (size_t)d_model;
        rc = needle_output_projection_f32(ctx, last_decoder, 1, logits, vocab_size);
        if (rc < 0) {
            break;
        }

        float *last = logits;
        int allowed_count = 0;
        if (filter) {
            allowed_count = filter(step, tokens, cur_len, last, vocab_size, allowed, vocab_size, user_data);
            if (allowed_count < 0) {
                set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter aborted generation");
                rc = NEEDLE_ERR_INVALID_ARGUMENT;
                break;
            }
            if (allowed_count > vocab_size) {
                set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter returned too many ids");
                rc = NEEDLE_ERR_INVALID_ARGUMENT;
                break;
            }
        }

        int best_id = 0;
        float best = last[0];
        if (allowed_count > 0) {
            best_id = allowed[0];
            if (best_id < 0 || best_id >= vocab_size) {
                set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter returned out-of-range id");
                rc = NEEDLE_ERR_INVALID_ARGUMENT;
                break;
            }
            best = last[best_id];
            for (int i = 1; i < allowed_count; i++) {
                int id = allowed[i];
                if (id < 0 || id >= vocab_size) {
                    set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter returned out-of-range id");
                    rc = NEEDLE_ERR_INVALID_ARGUMENT;
                    break;
                }
                if (last[id] > best) {
                    best = last[id];
                    best_id = id;
                }
            }
            if (rc < 0) {
                break;
            }
        } else {
            for (int i = 1; i < vocab_size; i++) {
                if (last[i] > best) {
                    best = last[i];
                    best_id = i;
                }
            }
        }
        tokens[cur_len++] = best_id;
        if (best_id == eos_token_id) {
            break;
        }
    }

    if (rc >= 0) {
        for (int i = 0; i < cur_len; i++) {
            out_ids[i] = tokens[i];
        }
        set_error(ctx, NEEDLE_OK, NULL);
        rc = cur_len;
    }
    free(tokens);
    aligned_free(encoder);
    aligned_free(decoder);
    aligned_free(dec_cur);
    aligned_free(dec_next);
    aligned_free(block_normed);
    aligned_free(block_attn);
    aligned_free(block_hidden);
    aligned_free(self_q);
    aligned_free(self_k);
    aligned_free(self_v);
    aligned_free(self_ctx_out);
    aligned_free(cross_q);
    aligned_free(cross_k);
    aligned_free(cross_v);
    aligned_free(cross_ctx_out);
    aligned_free(logits);
    free(allowed);
    return rc;
}

int needle_generate_tokens_greedy(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    const int *prompt_ids,
    int prompt_len,
    int max_new_tokens,
    int eos_token_id,
    int *out_ids,
    int out_cap) {
    return generate_tokens_greedy_impl(
        ctx, src_ids, src_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        NULL, NULL, out_ids, out_cap);
}

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
    int out_cap) {
    if (!filter) {
        return generate_tokens_greedy_impl(
            ctx, src_ids, src_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
            NULL, NULL, out_ids, out_cap);
    }
    return generate_tokens_greedy_impl(
        ctx, src_ids, src_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        filter, user_data, out_ids, out_cap);
}

static int select_greedy_token(
    needle_ctx *ctx,
    const float *logits,
    int vocab_size,
    const int *tokens,
    int cur_len,
    int step,
    needle_token_filter_callback filter,
    void *user_data,
    int *allowed,
    int *out_id) {
    int allowed_count = 0;
    if (filter) {
        allowed_count = filter(step, tokens, cur_len, logits, vocab_size, allowed, vocab_size, user_data);
        if (allowed_count < 0) {
            set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter aborted generation");
            return NEEDLE_ERR_INVALID_ARGUMENT;
        }
        if (allowed_count > vocab_size) {
            set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter returned too many ids");
            return NEEDLE_ERR_INVALID_ARGUMENT;
        }
    }

    int best_id = 0;
    float best = logits[0];
    if (allowed_count > 0) {
        best_id = allowed[0];
        if (best_id < 0 || best_id >= vocab_size) {
            set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter returned out-of-range id");
            return NEEDLE_ERR_INVALID_ARGUMENT;
        }
        best = logits[best_id];
        for (int i = 1; i < allowed_count; i++) {
            int id = allowed[i];
            if (id < 0 || id >= vocab_size) {
                set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token filter returned out-of-range id");
                return NEEDLE_ERR_INVALID_ARGUMENT;
            }
            if (logits[id] > best) {
                best = logits[id];
                best_id = id;
            }
        }
    } else {
        for (int i = 1; i < vocab_size; i++) {
            if (logits[i] > best) {
                best = logits[i];
                best_id = i;
            }
        }
    }
    *out_id = best_id;
    return NEEDLE_OK;
}

static int generate_tokens_greedy_cached_from_encoder_impl(
    needle_ctx *ctx,
    const float *encoder,
    int enc_len,
    const int *prompt_ids,
    int prompt_len,
    int max_new_tokens,
    int eos_token_id,
    needle_token_filter_callback filter,
    void *user_data,
    needle_token_callback token_callback,
    void *token_user_data,
    int *out_ids,
    int out_cap) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    int vocab_size = ctx->config.vocab_size;
    int heads = ctx->config.num_heads;
    int kv_heads = ctx->config.num_kv_heads;
    int layers = ctx->config.num_decoder_layers;
    if (!encoder || !prompt_ids || !out_ids || enc_len <= 0 || prompt_len <= 0 ||
        max_new_tokens < 0 || out_cap < prompt_len + max_new_tokens ||
        d_model <= 0 || vocab_size <= 0 || heads <= 0 || kv_heads <= 0 || layers <= 0 ||
        (d_model % heads) != 0 || (heads % kv_heads) != 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid cached greedy generation arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    int head_dim = d_model / heads;
    int kv_dim = kv_heads * head_dim;
    size_t cross_layer_elems = (size_t)enc_len * (size_t)kv_dim;

    int total_cap = prompt_len + max_new_tokens;
    int *tokens = (int *)malloc((size_t)total_cap * sizeof(int));
    float *decoded = alloc_floats((size_t)d_model);
    float *step_cur = alloc_floats((size_t)d_model);
    float *step_next = alloc_floats((size_t)d_model);
    float *block_normed = alloc_floats((size_t)d_model);
    float *block_attn = alloc_floats((size_t)d_model);
    float *block_hidden = alloc_floats((size_t)d_model);
    float *self_q = alloc_floats((size_t)d_model);
    float *self_k = alloc_floats((size_t)d_model);
    float *self_v = alloc_floats((size_t)d_model);
    float *self_ctx_out = alloc_floats((size_t)d_model);
    float *cross_q = alloc_floats((size_t)d_model);
    float *cross_k = NULL;
    float *cross_v = NULL;
    float *cross_ctx_out = alloc_floats((size_t)d_model);
    float *cross_k_cache = alloc_floats((size_t)layers * cross_layer_elems);
    float *cross_v_cache = alloc_floats((size_t)layers * cross_layer_elems);
    float *logits = alloc_floats((size_t)vocab_size);
    int *allowed = filter ? (int *)malloc((size_t)vocab_size * sizeof(int)) : NULL;
    if (!tokens || !decoded || !step_cur || !step_next ||
        !block_normed || !block_attn || !block_hidden ||
        !self_q || !self_k || !self_v || !self_ctx_out ||
        !cross_q || !cross_ctx_out ||
        !cross_k_cache || !cross_v_cache ||
        !logits || (filter && !allowed)) {
        free(tokens);
        aligned_free(decoded);
        aligned_free(step_cur);
        aligned_free(step_next);
        aligned_free(block_normed);
        aligned_free(block_attn);
        aligned_free(block_hidden);
        aligned_free(self_q);
        aligned_free(self_k);
        aligned_free(self_v);
        aligned_free(self_ctx_out);
        aligned_free(cross_q);
        aligned_free(cross_k);
        aligned_free(cross_v);
        aligned_free(cross_ctx_out);
        aligned_free(cross_k_cache);
        aligned_free(cross_v_cache);
        aligned_free(logits);
        free(allowed);
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in cached greedy generation");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    for (int i = 0; i < prompt_len; i++) {
        tokens[i] = prompt_ids[i];
    }

    int rc = precompute_decoder_cross_attention_kv(ctx, encoder, enc_len, cross_k_cache, cross_v_cache);
    if (rc < 0) {
        goto done_no_cache;
    }

    needle_kv_cache *cache = needle_kv_cache_create(ctx, total_cap);
    if (!cache) {
        rc = needle_last_error_code(ctx);
        if (rc == NEEDLE_OK) rc = NEEDLE_ERR_OUT_OF_MEMORY;
        goto done_no_cache;
    }

    for (int i = 0; i < prompt_len; i++) {
        rc = decode_token_cached_step_impl(
            ctx, cache, prompt_ids[i], encoder, enc_len, decoded, d_model, step_cur, step_next,
            block_normed, block_attn, block_hidden, self_q, self_k, self_v, self_ctx_out,
            cross_q, cross_k, cross_v, cross_ctx_out,
            cross_k_cache, cross_v_cache, cross_layer_elems);
        if (rc < 0) {
            needle_kv_cache_free(cache);
            goto done_no_cache;
        }
    }

    int cur_len = prompt_len;
    for (int step = 0; step < max_new_tokens; step++) {
        rc = needle_output_projection_f32(ctx, decoded, 1, logits, vocab_size);
        if (rc < 0) {
            break;
        }
        int best_id = 0;
        rc = select_greedy_token(ctx, logits, vocab_size, tokens, cur_len, step, filter, user_data, allowed, &best_id);
        if (rc < 0) {
            break;
        }
        tokens[cur_len++] = best_id;
        if (token_callback) {
            int cb_rc = token_callback(best_id, step, tokens, cur_len, token_user_data);
            if (cb_rc < 0) {
                set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token callback aborted generation");
                rc = NEEDLE_ERR_INVALID_ARGUMENT;
                break;
            }
        }
        if (best_id == eos_token_id) {
            break;
        }
        if (step + 1 < max_new_tokens) {
            rc = decode_token_cached_step_impl(
                ctx, cache, best_id, encoder, enc_len, decoded, d_model, step_cur, step_next,
                block_normed, block_attn, block_hidden, self_q, self_k, self_v, self_ctx_out,
                cross_q, cross_k, cross_v, cross_ctx_out,
                cross_k_cache, cross_v_cache, cross_layer_elems);
            if (rc < 0) {
                break;
            }
        }
    }

    needle_kv_cache_free(cache);
    if (rc >= 0) {
        for (int i = 0; i < cur_len; i++) {
            out_ids[i] = tokens[i];
        }
        set_error(ctx, NEEDLE_OK, NULL);
        rc = cur_len;
    }

done_no_cache:
    free(tokens);
    aligned_free(decoded);
    aligned_free(step_cur);
    aligned_free(step_next);
    aligned_free(block_normed);
    aligned_free(block_attn);
    aligned_free(block_hidden);
    aligned_free(self_q);
    aligned_free(self_k);
    aligned_free(self_v);
    aligned_free(self_ctx_out);
    aligned_free(cross_q);
    aligned_free(cross_k);
    aligned_free(cross_v);
    aligned_free(cross_ctx_out);
    aligned_free(cross_k_cache);
    aligned_free(cross_v_cache);
    aligned_free(logits);
    free(allowed);
    return rc;
}

static int generate_tokens_greedy_cached_impl(
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
    int out_cap) {
    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    int d_model = ctx->config.d_model;
    if (!src_ids || src_len <= 0 || d_model <= 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid cached greedy generation arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    float *encoder = alloc_floats((size_t)src_len * (size_t)d_model);
    if (!encoder) {
        set_error(ctx, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory in cached greedy generation");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    int rc = needle_encode_tokens_f32(ctx, src_ids, src_len, encoder, src_len * d_model);
    if (rc >= 0) {
        rc = generate_tokens_greedy_cached_from_encoder_impl(
            ctx, encoder, src_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
            filter, user_data, NULL, NULL, out_ids, out_cap);
    }
    aligned_free(encoder);
    return rc;
}

int needle_generate_tokens_greedy_cached(
    needle_ctx *ctx,
    const int *src_ids,
    int src_len,
    const int *prompt_ids,
    int prompt_len,
    int max_new_tokens,
    int eos_token_id,
    int *out_ids,
    int out_cap) {
    return generate_tokens_greedy_cached_impl(
        ctx, src_ids, src_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        NULL, NULL, out_ids, out_cap);
}

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
    int out_cap) {
    return generate_tokens_greedy_cached_impl(
        ctx, src_ids, src_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        filter, user_data, out_ids, out_cap);
}

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
    int out_cap) {
    return generate_tokens_greedy_cached_from_encoder_impl(
        ctx, encoder_out, enc_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        filter, user_data, NULL, NULL, out_ids, out_cap);
}

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
    int out_cap) {
    if (!ctx || !state) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (state->ctx != ctx || !state->encoder_out || state->enc_len <= 0 || state->d_model != ctx->config.d_model) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder state");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    return generate_tokens_greedy_cached_from_encoder_impl(
        ctx, state->encoder_out, state->enc_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        filter, user_data, NULL, NULL, out_ids, out_cap);
}

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
    int out_cap) {
    if (!ctx || !state) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!token_callback) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "token callback is null");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    if (state->ctx != ctx || !state->encoder_out || state->enc_len <= 0 || state->d_model != ctx->config.d_model) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encoder state");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    return generate_tokens_greedy_cached_from_encoder_impl(
        ctx, state->encoder_out, state->enc_len, prompt_ids, prompt_len, max_new_tokens, eos_token_id,
        filter, filter_user_data, token_callback, token_user_data, out_ids, out_cap);
}

int needle_generate(
    needle_ctx *ctx,
    const char *query,
    const char *tools_json,
    char *out,
    int out_cap) {
    (void)tools_json;

    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!out || out_cap <= 0) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "output buffer is invalid");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    out[0] = '\0';

    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    if (!query) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "query is null");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    set_error(ctx, NEEDLE_ERR_NOT_IMPLEMENTED, "generation is not implemented yet");
    return NEEDLE_ERR_NOT_IMPLEMENTED;
}

int needle_generate_stream(
    needle_ctx *ctx,
    const char *query,
    const char *tools_json,
    needle_stream_callback callback,
    void *user_data) {
    (void)query;
    (void)tools_json;
    (void)callback;
    (void)user_data;

    if (!ctx) {
        return NEEDLE_ERR_NULL_CONTEXT;
    }
    if (!ctx->loaded) {
        set_error(ctx, NEEDLE_ERR_NOT_LOADED, "model is not loaded");
        return NEEDLE_ERR_NOT_LOADED;
    }
    if (!callback) {
        set_error(ctx, NEEDLE_ERR_INVALID_ARGUMENT, "stream callback is null");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    set_error(ctx, NEEDLE_ERR_NOT_IMPLEMENTED, "streaming generation is not implemented yet");
    return NEEDLE_ERR_NOT_IMPLEMENTED;
}
