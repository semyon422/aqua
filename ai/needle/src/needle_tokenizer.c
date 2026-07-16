#include "needle_tokenizer.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TOK_MAGIC "NDLTOK1"
#define TOK_MAGIC_SIZE 8
#define TOK_VERSION 1
#define TOK_ERROR_CAP 256
#define TOK_WS "\xE2\x96\x81"
#define TOK_WS_LEN 3

typedef struct {
    char *text;
    uint32_t len;
    float score;
    uint16_t type;
} tok_piece;

struct needle_tokenizer {
    tok_piece *pieces;
    uint32_t vocab_size;
    uint32_t unk_id;
    uint32_t bos_id;
    uint32_t eos_id;
    uint32_t pad_id;
    uint32_t tool_call_id;
    uint32_t tools_id;
    int byte_id[256];
    int last_error_code;
    char last_error[TOK_ERROR_CAP];
};

typedef struct {
    char *text;
    uint32_t len;
    int id;
} symbol;

static void tok_set_error(needle_tokenizer *tok, int code, const char *msg) {
    if (!tok) return;
    tok->last_error_code = code;
    if (!msg) {
        tok->last_error[0] = '\0';
    } else {
        snprintf(tok->last_error, sizeof(tok->last_error), "%s", msg);
    }
}

static int read_exact(FILE *f, void *dst, size_t n) {
    return fread(dst, 1, n, f) == n ? 0 : -1;
}

static uint16_t le16(const unsigned char b[2]) {
    return (uint16_t)b[0] | ((uint16_t)b[1] << 8);
}

static uint32_t le32(const unsigned char b[4]) {
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) | ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

static uint64_t le64(const unsigned char b[8]) {
    return (uint64_t)b[0] | ((uint64_t)b[1] << 8) | ((uint64_t)b[2] << 16) | ((uint64_t)b[3] << 24) |
           ((uint64_t)b[4] << 32) | ((uint64_t)b[5] << 40) | ((uint64_t)b[6] << 48) | ((uint64_t)b[7] << 56);
}

static int read_u16(FILE *f, uint16_t *out) {
    unsigned char b[2];
    if (read_exact(f, b, sizeof(b)) != 0) return -1;
    *out = le16(b);
    return 0;
}

static int read_u32(FILE *f, uint32_t *out) {
    unsigned char b[4];
    if (read_exact(f, b, sizeof(b)) != 0) return -1;
    *out = le32(b);
    return 0;
}

static int read_u64(FILE *f, uint64_t *out) {
    unsigned char b[8];
    if (read_exact(f, b, sizeof(b)) != 0) return -1;
    *out = le64(b);
    return 0;
}

static int read_f32(FILE *f, float *out) {
    uint32_t bits;
    if (read_u32(f, &bits) != 0) return -1;
    memcpy(out, &bits, sizeof(bits));
    return 0;
}

static char *dup_bytes(const char *src, uint32_t len) {
    char *dst = (char *)malloc((size_t)len + 1);
    if (!dst) return NULL;
    memcpy(dst, src, len);
    dst[len] = '\0';
    return dst;
}

static int find_piece(needle_tokenizer *tok, const char *text, uint32_t len, int allow_special) {
    for (uint32_t i = 0; i < tok->vocab_size; i++) {
        tok_piece *p = &tok->pieces[i];
        if (!allow_special && p->type != 1) continue;
        if (p->len == len && memcmp(p->text, text, len) == 0) return (int)i;
    }
    return -1;
}

static int utf8_len(unsigned char c) {
    if (c < 0x80) return 1;
    if ((c & 0xE0) == 0xC0) return 2;
    if ((c & 0xF0) == 0xE0) return 3;
    if ((c & 0xF8) == 0xF0) return 4;
    return 1;
}

static int is_ascii_space(unsigned char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v';
}

static char *normalize_text(const char *text, uint32_t *out_len) {
    size_t n = strlen(text);
    size_t cap = TOK_WS_LEN + n * TOK_WS_LEN + 1;
    char *out = (char *)malloc(cap);
    if (!out) return NULL;
    size_t w = 0;
    memcpy(out + w, TOK_WS, TOK_WS_LEN);
    w += TOK_WS_LEN;
    int pending_space = 0;
    int emitted = 0;
    for (size_t i = 0; i < n; i++) {
        unsigned char c = (unsigned char)text[i];
        if (is_ascii_space(c)) {
            if (emitted) pending_space = 1;
            continue;
        }
        if (pending_space) {
            memcpy(out + w, TOK_WS, TOK_WS_LEN);
            w += TOK_WS_LEN;
            pending_space = 0;
        }
        out[w++] = (char)c;
        emitted = 1;
    }
    out[w] = '\0';
    *out_len = (uint32_t)w;
    return out;
}

static int append_symbol(symbol **arr, int *count, int *cap, const char *text, uint32_t len, int id) {
    if (*count >= *cap) {
        int new_cap = *cap ? *cap * 2 : 32;
        symbol *next = (symbol *)realloc(*arr, sizeof(symbol) * (size_t)new_cap);
        if (!next) return -1;
        *arr = next;
        *cap = new_cap;
    }
    (*arr)[*count].text = dup_bytes(text, len);
    if (!(*arr)[*count].text) return -1;
    (*arr)[*count].len = len;
    (*arr)[*count].id = id;
    (*count)++;
    return 0;
}

static void free_symbols(symbol *symbols, int count) {
    for (int i = 0; i < count; i++) free(symbols[i].text);
    free(symbols);
}

static int initial_symbols(needle_tokenizer *tok, const char *norm, uint32_t norm_len, symbol **out, int *out_count) {
    symbol *symbols = NULL;
    int count = 0;
    int cap = 0;
    uint32_t i = 0;
    while (i < norm_len) {
        int matched = -1;
        if (norm[i] == '<') {
            for (uint32_t id = 0; id < tok->vocab_size; id++) {
                if (tok->pieces[id].type != 4) continue;
                tok_piece *p = &tok->pieces[id];
                if (i + p->len <= norm_len && memcmp(norm + i, p->text, p->len) == 0) {
                    matched = (int)id;
                    break;
                }
            }
        }
        if (matched >= 0) {
            tok_piece *p = &tok->pieces[matched];
            if (append_symbol(&symbols, &count, &cap, p->text, p->len, matched) != 0) goto oom;
            i += p->len;
            continue;
        }

        uint32_t len = (uint32_t)utf8_len((unsigned char)norm[i]);
        if (i + len > norm_len) len = 1;
        int id = find_piece(tok, norm + i, len, 1);
        if (id < 0) {
            unsigned char c = (unsigned char)norm[i];
            id = tok->byte_id[c] >= 0 ? tok->byte_id[c] : (int)tok->unk_id;
            len = 1;
        }
        if (append_symbol(&symbols, &count, &cap, norm + i, len, id) != 0) goto oom;
        i += len;
    }
    *out = symbols;
    *out_count = count;
    return 0;
oom:
    free_symbols(symbols, count);
    return -1;
}

static int merge_symbols(needle_tokenizer *tok, symbol **symbols_ptr, int *count_ptr) {
    symbol *symbols = *symbols_ptr;
    int count = *count_ptr;
    while (count > 1) {
        int best_pos = -1;
        int best_id = -1;
        float best_score = -3.4e38f;
        for (int i = 0; i < count - 1; i++) {
            uint32_t len = symbols[i].len + symbols[i + 1].len;
            char *tmp = (char *)malloc((size_t)len);
            if (!tmp) return -1;
            memcpy(tmp, symbols[i].text, symbols[i].len);
            memcpy(tmp + symbols[i].len, symbols[i + 1].text, symbols[i + 1].len);
            int id = find_piece(tok, tmp, len, 0);
            free(tmp);
            if (id >= 0 && tok->pieces[id].score > best_score) {
                best_score = tok->pieces[id].score;
                best_pos = i;
                best_id = id;
            }
        }
        if (best_pos < 0) break;

        tok_piece *p = &tok->pieces[best_id];
        char *merged = dup_bytes(p->text, p->len);
        if (!merged) return -1;
        free(symbols[best_pos].text);
        free(symbols[best_pos + 1].text);
        symbols[best_pos].text = merged;
        symbols[best_pos].len = p->len;
        symbols[best_pos].id = best_id;
        for (int j = best_pos + 1; j < count - 1; j++) symbols[j] = symbols[j + 1];
        count--;
    }
    *count_ptr = count;
    return 0;
}

needle_tokenizer *needle_tokenizer_load(const char *path) {
    needle_tokenizer *tok = (needle_tokenizer *)calloc(1, sizeof(needle_tokenizer));
    if (!tok) return NULL;
    for (int i = 0; i < 256; i++) tok->byte_id[i] = -1;

    if (!path || path[0] == '\0') {
        tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "tokenizer path is empty");
        return tok;
    }

    FILE *f = fopen(path, "rb");
    if (!f) {
        tok_set_error(tok, NEEDLE_ERR_IO, "could not open tokenizer file");
        return tok;
    }

    char magic[TOK_MAGIC_SIZE];
    uint32_t version = 0, flags = 0, vocab = 0;
    uint64_t string_bytes = 0;
    if (read_exact(f, magic, sizeof(magic)) != 0 || memcmp(magic, TOK_MAGIC, strlen(TOK_MAGIC)) != 0 || magic[7] != '\0' ||
        read_u32(f, &version) != 0 || read_u32(f, &flags) != 0 || read_u32(f, &vocab) != 0 ||
        read_u32(f, &tok->unk_id) != 0 || read_u32(f, &tok->bos_id) != 0 || read_u32(f, &tok->eos_id) != 0 ||
        read_u32(f, &tok->pad_id) != 0 || read_u32(f, &tok->tool_call_id) != 0 || read_u32(f, &tok->tools_id) != 0 ||
        read_u64(f, &string_bytes) != 0) {
        tok_set_error(tok, NEEDLE_ERR_FORMAT, "truncated tokenizer header");
        fclose(f);
        return tok;
    }
    if (version != TOK_VERSION || flags != 0 || vocab == 0 || string_bytes > (uint64_t)1024 * 1024 * 1024) {
        tok_set_error(tok, NEEDLE_ERR_FORMAT, "invalid tokenizer header");
        fclose(f);
        return tok;
    }

    uint32_t *offsets = (uint32_t *)calloc(vocab, sizeof(uint32_t));
    uint32_t *lens = (uint32_t *)calloc(vocab, sizeof(uint32_t));
    float *scores = (float *)calloc(vocab, sizeof(float));
    uint16_t *types = (uint16_t *)calloc(vocab, sizeof(uint16_t));
    tok->pieces = (tok_piece *)calloc(vocab, sizeof(tok_piece));
    char *strings = (char *)malloc((size_t)string_bytes);
    if (!offsets || !lens || !scores || !types || !tok->pieces || !strings) {
        tok_set_error(tok, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while loading tokenizer");
        fclose(f);
        free(offsets); free(lens); free(scores); free(types); free(strings);
        return tok;
    }

    for (uint32_t i = 0; i < vocab; i++) {
        uint16_t reserved = 0;
        if (read_u32(f, &offsets[i]) != 0 || read_u32(f, &lens[i]) != 0 || read_f32(f, &scores[i]) != 0 ||
            read_u16(f, &types[i]) != 0 || read_u16(f, &reserved) != 0) {
            tok_set_error(tok, NEEDLE_ERR_FORMAT, "truncated tokenizer piece table");
            fclose(f);
            free(offsets); free(lens); free(scores); free(types); free(strings);
            return tok;
        }
        (void)reserved;
    }
    if (read_exact(f, strings, (size_t)string_bytes) != 0) {
        tok_set_error(tok, NEEDLE_ERR_FORMAT, "truncated tokenizer string table");
        fclose(f);
        free(offsets); free(lens); free(scores); free(types); free(strings);
        return tok;
    }
    fclose(f);

    tok->vocab_size = vocab;
    for (uint32_t i = 0; i < vocab; i++) {
        if ((uint64_t)offsets[i] + lens[i] > string_bytes) {
            tok_set_error(tok, NEEDLE_ERR_FORMAT, "invalid tokenizer string offset");
            free(offsets); free(lens); free(scores); free(types); free(strings);
            return tok;
        }
        tok->pieces[i].text = dup_bytes(strings + offsets[i], lens[i]);
        tok->pieces[i].len = lens[i];
        tok->pieces[i].score = scores[i];
        tok->pieces[i].type = types[i];
        if (types[i] == 6 && lens[i] == 6 && memcmp(tok->pieces[i].text, "<0x", 3) == 0) {
            char hex[3] = { tok->pieces[i].text[3], tok->pieces[i].text[4], 0 };
            char *end = NULL;
            long b = strtol(hex, &end, 16);
            if (end && *end == '\0' && b >= 0 && b < 256) tok->byte_id[b] = (int)i;
        }
    }

    free(offsets); free(lens); free(scores); free(types); free(strings);
    tok_set_error(tok, NEEDLE_OK, NULL);
    return tok;
}

void needle_tokenizer_free(needle_tokenizer *tok) {
    if (!tok) return;
    if (tok->pieces) {
        for (uint32_t i = 0; i < tok->vocab_size; i++) free(tok->pieces[i].text);
    }
    free(tok->pieces);
    free(tok);
}

const char *needle_tokenizer_last_error(needle_tokenizer *tok) {
    return tok ? tok->last_error : "needle tokenizer is null";
}

int needle_tokenizer_last_error_code(needle_tokenizer *tok) {
    return tok ? tok->last_error_code : NEEDLE_ERR_NULL_CONTEXT;
}

unsigned int needle_tokenizer_vocab_size(needle_tokenizer *tok) {
    return tok ? tok->vocab_size : 0;
}

int needle_tokenizer_encode(needle_tokenizer *tok, const char *text, int *out_ids, int out_cap) {
    if (!tok) return NEEDLE_ERR_NULL_CONTEXT;
    if (!text || !out_ids || out_cap <= 0) {
        tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "invalid encode arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    uint32_t norm_len = 0;
    char *norm = normalize_text(text, &norm_len);
    if (!norm) {
        tok_set_error(tok, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while normalizing text");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    symbol *symbols = NULL;
    int count = 0;
    if (initial_symbols(tok, norm, norm_len, &symbols, &count) != 0 || merge_symbols(tok, &symbols, &count) != 0) {
        free(norm);
        free_symbols(symbols, count);
        tok_set_error(tok, NEEDLE_ERR_OUT_OF_MEMORY, "out of memory while encoding text");
        return NEEDLE_ERR_OUT_OF_MEMORY;
    }
    free(norm);
    if (count > out_cap) {
        free_symbols(symbols, count);
        tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "token output buffer is too small");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    for (int i = 0; i < count; i++) out_ids[i] = symbols[i].id;
    free_symbols(symbols, count);
    tok_set_error(tok, NEEDLE_OK, NULL);
    return count;
}

int needle_tokenizer_decode(needle_tokenizer *tok, const int *ids, int count, char *out, int out_cap) {
    if (!tok) return NEEDLE_ERR_NULL_CONTEXT;
    if (!ids || !out || out_cap <= 0 || count < 0) {
        tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "invalid decode arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    int w = 0;
    int at_start = 1;
    for (int i = 0; i < count; i++) {
        int id = ids[i];
        if (id < 0 || (uint32_t)id >= tok->vocab_size) continue;
        tok_piece *p = &tok->pieces[id];
        if (p->type == 3 || p->type == 2) continue;
        if (p->type == 6 && p->len == 6 && memcmp(p->text, "<0x", 3) == 0) {
            char hex[3] = { p->text[3], p->text[4], 0 };
            char *end = NULL;
            long b = strtol(hex, &end, 16);
            if (end && *end == '\0' && b >= 0 && b < 256) {
                if (w + 1 >= out_cap) goto small;
                out[w++] = (char)b;
                at_start = 0;
            }
            continue;
        }
        uint32_t pos = 0;
        while (pos < p->len) {
            if (p->len - pos >= TOK_WS_LEN && memcmp(p->text + pos, TOK_WS, TOK_WS_LEN) == 0) {
                if (!at_start) {
                    if (w + 1 >= out_cap) goto small;
                    out[w++] = ' ';
                }
                pos += TOK_WS_LEN;
            } else {
                if (w + 1 >= out_cap) goto small;
                out[w++] = p->text[pos++];
                at_start = 0;
            }
        }
    }
    out[w] = '\0';
    tok_set_error(tok, NEEDLE_OK, NULL);
    return w;
small:
    out[0] = '\0';
    tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "decode output buffer is too small");
    return NEEDLE_ERR_INVALID_ARGUMENT;
}

int needle_tokenizer_token_text(needle_tokenizer *tok, int id, char *out, int out_cap) {
    if (!tok) return NEEDLE_ERR_NULL_CONTEXT;
    if (!out || out_cap <= 0 || id < 0 || (uint32_t)id >= tok->vocab_size) {
        tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "invalid token text arguments");
        return NEEDLE_ERR_INVALID_ARGUMENT;
    }
    out[0] = '\0';
    tok_piece *p = &tok->pieces[id];
    if (p->type == 3 || p->type == 2) {
        tok_set_error(tok, NEEDLE_OK, NULL);
        return 0;
    }
    if (p->type == 6 && p->len == 6 && memcmp(p->text, "<0x", 3) == 0) {
        char hex[3] = { p->text[3], p->text[4], 0 };
        char *end = NULL;
        long b = strtol(hex, &end, 16);
        if (end && *end == '\0' && b >= 0 && b < 256) {
            if (out_cap < 2) {
                tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "token text output buffer is too small");
                return NEEDLE_ERR_INVALID_ARGUMENT;
            }
            out[0] = (char)b;
            out[1] = '\0';
            tok_set_error(tok, NEEDLE_OK, NULL);
            return 1;
        }
    }

    int w = 0;
    uint32_t pos = 0;
    while (pos < p->len) {
        if (p->len - pos >= TOK_WS_LEN && memcmp(p->text + pos, TOK_WS, TOK_WS_LEN) == 0) {
            if (w + 1 >= out_cap) {
                out[0] = '\0';
                tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "token text output buffer is too small");
                return NEEDLE_ERR_INVALID_ARGUMENT;
            }
            out[w++] = ' ';
            pos += TOK_WS_LEN;
        } else {
            if (w + 1 >= out_cap) {
                out[0] = '\0';
                tok_set_error(tok, NEEDLE_ERR_INVALID_ARGUMENT, "token text output buffer is too small");
                return NEEDLE_ERR_INVALID_ARGUMENT;
            }
            out[w++] = p->text[pos++];
        }
    }
    out[w] = '\0';
    tok_set_error(tok, NEEDLE_OK, NULL);
    return w;
}
