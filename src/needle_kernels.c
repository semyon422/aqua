#include "needle_kernels.h"

#include <math.h>
#include <stddef.h>
#include <float.h>

int needle_kernel_zcrmsnorm_f32(
    const float *x,
    const float *scale,
    float *out,
    int rows,
    int cols,
    float epsilon) {
    if (!x || !scale || !out || rows <= 0 || cols <= 0 || epsilon <= 0.0f) {
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    for (int r = 0; r < rows; r++) {
        const float *row = x + (size_t)r * (size_t)cols;
        float *dst = out + (size_t)r * (size_t)cols;
        double sumsq = 0.0;
        for (int c = 0; c < cols; c++) {
            double v = (double)row[c];
            sumsq += v * v;
        }
        float inv_rms = 1.0f / sqrtf((float)(sumsq / (double)cols) + epsilon);
        for (int c = 0; c < cols; c++) {
            dst[c] = (1.0f + scale[c]) * row[c] * inv_rms;
        }
    }
    return NEEDLE_OK;
}

int needle_kernel_rope_f32(
    const float *x,
    float *out,
    int num_heads,
    int seq_len,
    int head_dim,
    float theta,
    int rope_keys_only) {
    (void)rope_keys_only;
    if (!x || !out || num_heads <= 0 || seq_len <= 0 || head_dim <= 0 ||
        (head_dim % 2) != 0 || theta <= 0.0f) {
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    int half = head_dim / 2;
    for (int h = 0; h < num_heads; h++) {
        for (int t = 0; t < seq_len; t++) {
            for (int i = 0; i < half; i++) {
                float freq = 1.0f / powf(theta, (float)(2 * i) / (float)head_dim);
                float angle = (float)t * freq;
                float cs = cosf(angle);
                float sn = sinf(angle);
                size_t base = ((size_t)h * (size_t)seq_len + (size_t)t) * (size_t)head_dim;
                float x1 = x[base + (size_t)i];
                float x2 = x[base + (size_t)half + (size_t)i];
                out[base + (size_t)i] = x1 * cs - x2 * sn;
                out[base + (size_t)half + (size_t)i] = x2 * cs + x1 * sn;
            }
        }
    }
    return NEEDLE_OK;
}

int needle_kernel_matmul_f32(
    const float *a,
    const float *b,
    const float *bias,
    float *out,
    int m,
    int k,
    int n) {
    if (!a || !b || !out || m <= 0 || k <= 0 || n <= 0) {
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    for (int i = 0; i < m; i++) {
        for (int j = 0; j < n; j++) {
            double sum = bias ? (double)bias[j] : 0.0;
            for (int p = 0; p < k; p++) {
                sum += (double)a[(size_t)i * (size_t)k + (size_t)p] *
                       (double)b[(size_t)p * (size_t)n + (size_t)j];
            }
            out[(size_t)i * (size_t)n + (size_t)j] = (float)sum;
        }
    }
    return NEEDLE_OK;
}

int needle_kernel_softmax_f32(
    const float *x,
    const unsigned char *mask,
    float *out,
    int rows,
    int cols) {
    if (!x || !out || rows <= 0 || cols <= 0) {
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    for (int r = 0; r < rows; r++) {
        float max_v = -FLT_MAX;
        int any = 0;
        for (int c = 0; c < cols; c++) {
            size_t idx = (size_t)r * (size_t)cols + (size_t)c;
            if (!mask || mask[idx]) {
                if (x[idx] > max_v) max_v = x[idx];
                any = 1;
            }
        }
        if (!any) {
            for (int c = 0; c < cols; c++) {
                out[(size_t)r * (size_t)cols + (size_t)c] = 0.0f;
            }
            continue;
        }

        double sum = 0.0;
        for (int c = 0; c < cols; c++) {
            size_t idx = (size_t)r * (size_t)cols + (size_t)c;
            if (!mask || mask[idx]) {
                float e = expf(x[idx] - max_v);
                out[idx] = e;
                sum += (double)e;
            } else {
                out[idx] = 0.0f;
            }
        }

        float inv = sum > 0.0 ? (float)(1.0 / sum) : 0.0f;
        for (int c = 0; c < cols; c++) {
            size_t idx = (size_t)r * (size_t)cols + (size_t)c;
            out[idx] *= inv;
        }
    }
    return NEEDLE_OK;
}

int needle_kernel_attention_f32(
    const float *q,
    const float *k,
    const float *v,
    const unsigned char *mask,
    float *out,
    int q_len,
    int kv_len,
    int head_dim) {
    if (!q || !k || !v || !out || q_len <= 0 || kv_len <= 0 || head_dim <= 0) {
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }

    float scale = 1.0f / sqrtf((float)head_dim);
    for (int qi = 0; qi < q_len; qi++) {
        float max_score = -FLT_MAX;
        int any = 0;
        for (int ki = 0; ki < kv_len; ki++) {
            size_t mask_idx = (size_t)qi * (size_t)kv_len + (size_t)ki;
            if (mask && !mask[mask_idx]) {
                continue;
            }
            double dot = 0.0;
            for (int d = 0; d < head_dim; d++) {
                dot += (double)q[(size_t)qi * (size_t)head_dim + (size_t)d] *
                       (double)k[(size_t)ki * (size_t)head_dim + (size_t)d];
            }
            float score = (float)dot * scale;
            if (score > max_score) max_score = score;
            any = 1;
        }

        for (int d = 0; d < head_dim; d++) {
            out[(size_t)qi * (size_t)head_dim + (size_t)d] = 0.0f;
        }
        if (!any) {
            continue;
        }

        double denom = 0.0;
        for (int ki = 0; ki < kv_len; ki++) {
            size_t mask_idx = (size_t)qi * (size_t)kv_len + (size_t)ki;
            if (mask && !mask[mask_idx]) {
                continue;
            }
            double dot = 0.0;
            for (int d = 0; d < head_dim; d++) {
                dot += (double)q[(size_t)qi * (size_t)head_dim + (size_t)d] *
                       (double)k[(size_t)ki * (size_t)head_dim + (size_t)d];
            }
            float score = (float)dot * scale;
            float weight = expf(score - max_score);
            denom += (double)weight;
            for (int d = 0; d < head_dim; d++) {
                out[(size_t)qi * (size_t)head_dim + (size_t)d] +=
                    weight * v[(size_t)ki * (size_t)head_dim + (size_t)d];
            }
        }

        if (denom > 0.0) {
            float inv = (float)(1.0 / denom);
            for (int d = 0; d < head_dim; d++) {
                out[(size_t)qi * (size_t)head_dim + (size_t)d] *= inv;
            }
        }
    }
    return NEEDLE_OK;
}
