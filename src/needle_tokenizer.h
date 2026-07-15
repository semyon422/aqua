#ifndef NEEDLE_TOKENIZER_H
#define NEEDLE_TOKENIZER_H

#include "needle_runtime.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct needle_tokenizer needle_tokenizer;

NEEDLE_API needle_tokenizer *needle_tokenizer_load(const char *path);
NEEDLE_API void needle_tokenizer_free(needle_tokenizer *tok);
NEEDLE_API const char *needle_tokenizer_last_error(needle_tokenizer *tok);
NEEDLE_API int needle_tokenizer_last_error_code(needle_tokenizer *tok);
NEEDLE_API unsigned int needle_tokenizer_vocab_size(needle_tokenizer *tok);
NEEDLE_API int needle_tokenizer_encode(needle_tokenizer *tok, const char *text, int *out_ids, int out_cap);
NEEDLE_API int needle_tokenizer_decode(needle_tokenizer *tok, const int *ids, int count, char *out, int out_cap);
NEEDLE_API int needle_tokenizer_token_text(needle_tokenizer *tok, int id, char *out, int out_cap);

#ifdef __cplusplus
}
#endif

#endif
