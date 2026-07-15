#ifndef NEEDLE_KERNELS_H
#define NEEDLE_KERNELS_H

#include "needle_runtime.h"

#ifdef __cplusplus
extern "C" {
#endif

NEEDLE_API int needle_kernel_zcrmsnorm_f32(
    const float *x,
    const float *scale,
    float *out,
    int rows,
    int cols,
    float epsilon);

NEEDLE_API int needle_kernel_rope_f32(
    const float *x,
    float *out,
    int num_heads,
    int seq_len,
    int head_dim,
    float theta,
    int rope_keys_only);

NEEDLE_API int needle_kernel_matmul_f32(
    const float *a,
    const float *b,
    const float *bias,
    float *out,
    int m,
    int k,
    int n);

NEEDLE_API int needle_kernel_softmax_f32(
    const float *x,
    const unsigned char *mask,
    float *out,
    int rows,
    int cols);

NEEDLE_API int needle_kernel_attention_f32(
    const float *q,
    const float *k,
    const float *v,
    const unsigned char *mask,
    float *out,
    int q_len,
    int kv_len,
    int head_dim);

#ifdef __cplusplus
}
#endif

#endif
