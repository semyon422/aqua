#!/usr/bin/env python3
"""Generate golden data for the tiny encoder self-attention fixture."""

from __future__ import annotations

import json
import math
from pathlib import Path


def zcrmsnorm(row: list[float], scale: list[float], eps: float = 1e-6) -> list[float]:
    inv = 1.0 / math.sqrt(sum(v * v for v in row) / len(row) + eps)
    return [(1.0 + s) * v * inv for v, s in zip(row, scale)]


def rope(row: list[float], pos: int, theta: float = 10000.0) -> list[float]:
    head_dim = len(row)
    half = head_dim // 2
    out = row[:]
    for i in range(half):
        freq = 1.0 / (theta ** ((2 * i) / head_dim))
        angle = pos * freq
        c = math.cos(angle)
        s = math.sin(angle)
        x1 = row[i]
        x2 = row[half + i]
        out[i] = x1 * c - x2 * s
        out[half + i] = x2 * c + x1 * s
    return out


def softmax(xs: list[float]) -> list[float]:
    m = max(xs)
    exps = [math.exp(x - m) for x in xs]
    z = sum(exps)
    return [x / z for x in exps]


def matmul_row(row: list[float], matrix: list[list[float]]) -> list[float]:
    return [sum(row[i] * matrix[i][j] for i in range(len(row))) for j in range(len(matrix[0]))]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_path = root / "build" / "golden_encoder_self_attention.json"

    # Matches scripts/write_test_fixture.py:
    # d_model=2, heads=1, kv_heads=1, all projection matrices are identity.
    x = [
        [1.0, 0.0],
        [0.0, 1.0],
    ]
    ident = [
        [1.0, 0.0],
        [0.0, 1.0],
    ]
    q_scale = [0.0, 0.0]
    k_scale = [0.0, 0.0]

    def self_attention(inp: list[list[float]], causal: bool = False) -> list[float]:
        q = [zcrmsnorm(matmul_row(row, ident), q_scale) for row in inp]
        k = [zcrmsnorm(matmul_row(row, ident), k_scale) for row in inp]
        v = [matmul_row(row, ident) for row in inp]
        q = [rope(row, pos) for pos, row in enumerate(q)]
        k = [rope(row, pos) for pos, row in enumerate(k)]

        result = []
        scale = 1.0 / math.sqrt(2.0)
        for qi in range(len(q)):
            allowed = [ki for ki in range(len(k)) if not causal or ki <= qi]
            scores = [sum(q[qi][d] * k[ki][d] for d in range(2)) * scale for ki in allowed]
            weights = softmax(scores)
            row = [
                sum(weights[pos] * v[ki][d] for pos, ki in enumerate(allowed))
                for d in range(2)
            ]
            result.extend(row)
        return result

    def cross_attention(dec_inp: list[list[float]], enc_inp: list[list[float]]) -> list[float]:
        q = [zcrmsnorm(matmul_row(row, ident), q_scale) for row in dec_inp]
        k = [zcrmsnorm(matmul_row(row, ident), k_scale) for row in enc_inp]
        v = [matmul_row(row, ident) for row in enc_inp]
        result = []
        scale = 1.0 / math.sqrt(2.0)
        for qi in range(len(q)):
            scores = [sum(q[qi][d] * k[ki][d] for d in range(2)) * scale for ki in range(len(k))]
            weights = softmax(scores)
            row = [
                sum(weights[ki] * v[ki][d] for ki in range(len(v)))
                for d in range(2)
            ]
            result.extend(row)
        return result

    expected_attention = self_attention(x)
    expected_decoder_self = self_attention(x, causal=True)
    gate = 1.0 / (1.0 + math.exp(-0.0))
    cross_encoder = [
        [2.0, 0.0],
        [0.0, 2.0],
    ]
    expected_decoder_cross = cross_attention(x, cross_encoder)
    decoder_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in x]
    decoder_self_for_block = self_attention(decoder_normed, causal=True)
    decoder_hidden = [
        x_i + gate * attn_i
        for x_i, attn_i in zip([v for row in x for v in row], decoder_self_for_block)
    ]
    decoder_hidden_rows = [decoder_hidden[i:i + 2] for i in range(0, len(decoder_hidden), 2)]
    decoder_cross_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in decoder_hidden_rows]
    decoder_cross_for_block = cross_attention(decoder_cross_normed, cross_encoder)
    expected_decoder_block = [
        h_i + gate * cross_i
        for h_i, cross_i in zip(decoder_hidden, decoder_cross_for_block)
    ]

    block_normed_x = [zcrmsnorm(row, [0.0, 0.0]) for row in x]
    expected_block_attention = self_attention(block_normed_x)
    expected_block = [
        x_i + gate * attn_i
        for x_i, attn_i in zip([v for row in x for v in row], expected_block_attention)
    ]

    token_embeddings = [
        [1.0, 2.0],
        [3.0, 4.0],
    ]
    embed_scale = math.sqrt(2.0)
    encoder_input = [[v * embed_scale for v in row] for row in token_embeddings]
    encoder_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in encoder_input]
    encoder_attn = self_attention(encoder_normed)
    encoder_block = [
        x_i + gate * attn_i
        for x_i, attn_i in zip([v for row in encoder_input for v in row], encoder_attn)
    ]
    encoder_rows = [encoder_block[i:i + 2] for i in range(0, len(encoder_block), 2)]
    expected_encoder = [
        v
        for row in encoder_rows
        for v in zcrmsnorm(row, [0.0, 0.0])
    ]

    decoder_tokens = [0, 1]
    decoder_input = [[v * embed_scale for v in token_embeddings[tok]] for tok in decoder_tokens]
    dec_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in decoder_input]
    dec_self = self_attention(dec_normed, causal=True)
    dec_hidden = [
        x_i + gate * attn_i
        for x_i, attn_i in zip([v for row in decoder_input for v in row], dec_self)
    ]
    dec_hidden_rows = [dec_hidden[i:i + 2] for i in range(0, len(dec_hidden), 2)]
    dec_cross_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in dec_hidden_rows]
    dec_cross = cross_attention(dec_cross_normed, cross_encoder)
    dec_block = [
        h_i + gate * cross_i
        for h_i, cross_i in zip(dec_hidden, dec_cross)
    ]
    dec_rows = [dec_block[i:i + 2] for i in range(0, len(dec_block), 2)]
    expected_decoder = [
        v
        for row in dec_rows
        for v in zcrmsnorm(row, [0.0, 0.0])
    ]
    forward_encoder_rows = [expected_encoder[i:i + 2] for i in range(0, len(expected_encoder), 2)]
    forward_dec_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in decoder_input]
    forward_dec_self = self_attention(forward_dec_normed, causal=True)
    forward_dec_hidden = [
        x_i + gate * attn_i
        for x_i, attn_i in zip([v for row in decoder_input for v in row], forward_dec_self)
    ]
    forward_dec_hidden_rows = [forward_dec_hidden[i:i + 2] for i in range(0, len(forward_dec_hidden), 2)]
    forward_dec_cross_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in forward_dec_hidden_rows]
    forward_dec_cross = cross_attention(forward_dec_cross_normed, forward_encoder_rows)
    forward_dec_block = [
        h_i + gate * cross_i
        for h_i, cross_i in zip(forward_dec_hidden, forward_dec_cross)
    ]
    forward_dec_rows = [forward_dec_block[i:i + 2] for i in range(0, len(forward_dec_block), 2)]
    forward_decoder = [
        v
        for row in forward_dec_rows
        for v in zcrmsnorm(row, [0.0, 0.0])
    ]
    decoder_hidden_rows = [forward_decoder[i:i + 2] for i in range(0, len(forward_decoder), 2)]
    expected_forward_logits = [
        dot
        for row in decoder_hidden_rows
        for dot in [
            row[0] * token_embeddings[0][0] + row[1] * token_embeddings[0][1],
            row[0] * token_embeddings[1][0] + row[1] * token_embeddings[1][1],
        ]
    ]

    def forward_logits_for(src_tokens: list[int], tgt_tokens: list[int]) -> list[float]:
        # Tiny fixture has one encoder and one decoder layer. Recompute the same
        # path used above, with src/tgt token choices parameterized.
        src_emb = [[v * embed_scale for v in token_embeddings[tok]] for tok in src_tokens]
        src_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in src_emb]
        src_attn = self_attention(src_normed)
        src_block = [
            x_i + gate * attn_i
            for x_i, attn_i in zip([v for row in src_emb for v in row], src_attn)
        ]
        src_rows = [src_block[i:i + 2] for i in range(0, len(src_block), 2)]
        src_encoder = [v for row in src_rows for v in zcrmsnorm(row, [0.0, 0.0])]
        src_encoder_rows = [src_encoder[i:i + 2] for i in range(0, len(src_encoder), 2)]

        tgt_emb = [[v * embed_scale for v in token_embeddings[tok]] for tok in tgt_tokens]
        tgt_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in tgt_emb]
        tgt_self = self_attention(tgt_normed, causal=True)
        tgt_hidden = [
            x_i + gate * attn_i
            for x_i, attn_i in zip([v for row in tgt_emb for v in row], tgt_self)
        ]
        tgt_hidden_rows = [tgt_hidden[i:i + 2] for i in range(0, len(tgt_hidden), 2)]
        tgt_cross_normed = [zcrmsnorm(row, [0.0, 0.0]) for row in tgt_hidden_rows]
        tgt_cross = cross_attention(tgt_cross_normed, src_encoder_rows)
        tgt_block = [
            h_i + gate * cross_i
            for h_i, cross_i in zip(tgt_hidden, tgt_cross)
        ]
        tgt_rows = [tgt_block[i:i + 2] for i in range(0, len(tgt_block), 2)]
        tgt_decoder = [v for row in tgt_rows for v in zcrmsnorm(row, [0.0, 0.0])]
        rows = [tgt_decoder[i:i + 2] for i in range(0, len(tgt_decoder), 2)]
        return [
            dot
            for row in rows
            for dot in [
                row[0] * token_embeddings[0][0] + row[1] * token_embeddings[0][1],
                row[0] * token_embeddings[1][0] + row[1] * token_embeddings[1][1],
            ]
        ]

    generation_src = [0, 1]
    generation_prompt = [0]
    expected_generation = generation_prompt[:]
    for _ in range(3):
        logits = forward_logits_for(generation_src, expected_generation)
        last = logits[-2:]
        expected_generation.append(0 if last[0] >= last[1] else 1)

    payload = {
        "seq_len": 2,
        "d_model": 2,
        "layer": 0,
        "input": [v for row in x for v in row],
        "expected": expected_attention,
        "expected_decoder_self": expected_decoder_self,
        "cross_encoder": [v for row in cross_encoder for v in row],
        "expected_decoder_cross": expected_decoder_cross,
        "expected_decoder_block": expected_decoder_block,
        "expected_block": expected_block,
        "encoder_tokens": [0, 1],
        "expected_encoder": expected_encoder,
        "decoder_tokens": decoder_tokens,
        "expected_decoder": expected_decoder,
        "expected_forward_logits": expected_forward_logits,
        "generation_src": generation_src,
        "generation_prompt": generation_prompt,
        "expected_generation": expected_generation,
        "tolerance": 1e-5,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, sort_keys=True, indent=2) + "\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
