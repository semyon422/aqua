#!/usr/bin/env python3
"""Generate real-checkpoint golden data for encoder self-attention layer 0."""

from __future__ import annotations

import argparse
import json
import math
import pickle
from pathlib import Path

import numpy as np
import sentencepiece as spm


def zcrmsnorm_heads(x: np.ndarray, scale: np.ndarray, eps: float = 1e-6) -> np.ndarray:
    # x: [T, H, D], scale: [D]
    rms = np.sqrt(np.mean(x.astype(np.float32) ** 2, axis=-1, keepdims=True) + eps)
    return ((1.0 + scale.astype(np.float32)[None, None, :]) * x.astype(np.float32) / rms).astype(np.float32)


def zcrmsnorm_model(x: np.ndarray, scale: np.ndarray, eps: float = 1e-6) -> np.ndarray:
    rms = np.sqrt(np.mean(x.astype(np.float32) ** 2, axis=-1, keepdims=True) + eps)
    return ((1.0 + scale.astype(np.float32)[None, :]) * x.astype(np.float32) / rms).astype(np.float32)


def rope(x: np.ndarray, theta: float) -> np.ndarray:
    # x: [T, H, D]
    t, _, head_dim = x.shape
    half = head_dim // 2
    freqs = 1.0 / (theta ** (np.arange(0, head_dim, 2, dtype=np.float32) / head_dim))
    pos = np.arange(t, dtype=np.float32)
    angles = np.outer(pos, freqs)
    cos = np.cos(angles).astype(np.float32)[:, None, :]
    sin = np.sin(angles).astype(np.float32)[:, None, :]
    x1 = x[:, :, :half]
    x2 = x[:, :, half:]
    return np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin], axis=-1).astype(np.float32)


def softmax(x: np.ndarray, axis: int = -1) -> np.ndarray:
    x = x.astype(np.float32)
    x = x - np.max(x, axis=axis, keepdims=True)
    e = np.exp(x)
    return (e / np.sum(e, axis=axis, keepdims=True)).astype(np.float32)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", default="checkpoints/needle.pkl", type=Path)
    parser.add_argument("--output", default="lua/build/golden_real_encoder_self_attention.json", type=Path)
    parser.add_argument("--tokenizer", default="../needle/tokenizer/needle.model", type=Path)
    parser.add_argument("--tokens", default="4,5", help="comma-separated token ids used as attention input")
    args = parser.parse_args()

    with args.checkpoint.open("rb") as f:
        data = pickle.load(f)
    params = data["params"]
    cfg = data["config"]

    tokens = [int(x) for x in args.tokens.split(",") if x]
    emb = np.asarray(params["embedding"]["embedding"], dtype=np.float32)
    x = emb[tokens].astype(np.float32)

    d_model = int(cfg["d_model"])
    num_heads = int(cfg["num_heads"])
    num_kv_heads = int(cfg["num_kv_heads"])
    head_dim = d_model // num_heads
    kv_dim = num_kv_heads * head_dim
    theta = float(cfg["rope_theta"])
    layer = 0

    enc_layers = params["encoder"]["layers"]["EncoderBlock_0"]

    def self_attention(inp: np.ndarray, layer_index: int) -> np.ndarray:
        attn = enc_layers["self_attn"]
        q_kernel = np.asarray(attn["q_proj"]["kernel"][layer_index], dtype=np.float32)
        k_kernel = np.asarray(attn["k_proj"]["kernel"][layer_index], dtype=np.float32)
        v_kernel = np.asarray(attn["v_proj"]["kernel"][layer_index], dtype=np.float32)
        out_kernel = np.asarray(attn["out_proj"]["kernel"][layer_index], dtype=np.float32)
        q_scale = np.asarray(attn["q_norm"]["scale"][layer_index], dtype=np.float32)
        k_scale = np.asarray(attn["k_norm"]["scale"][layer_index], dtype=np.float32)
        q = inp @ q_kernel
        k = inp @ k_kernel
        v = inp @ v_kernel

        q_len = inp.shape[0]
        q = q.reshape(q_len, num_heads, head_dim)
        k = k.reshape(inp.shape[0], num_kv_heads, head_dim)
        v = v.reshape(inp.shape[0], num_kv_heads, head_dim)

        q = zcrmsnorm_heads(q, q_scale)
        k = zcrmsnorm_heads(k, k_scale)
        q = rope(q, theta)
        k = rope(k, theta)

        repeats = num_heads // num_kv_heads
        k = np.repeat(k, repeats, axis=1)
        v = np.repeat(v, repeats, axis=1)

        qh = np.transpose(q, (1, 0, 2))  # [H, T, D]
        kh = np.transpose(k, (1, 0, 2))
        vh = np.transpose(v, (1, 0, 2))
        scores = np.matmul(qh, np.transpose(kh, (0, 2, 1))) / math.sqrt(head_dim)
        weights = softmax(scores, axis=-1)
        out = np.matmul(weights, vh)  # [H, T, D]
        out = np.transpose(out, (1, 0, 2)).reshape(q_len, d_model)
        return out @ out_kernel

    def decoder_self_attention(inp: np.ndarray, layer_index: int, causal: bool = True) -> np.ndarray:
        dec_attn = params["decoder"]["layers"]["DecoderBlock_0"]["self_attn"]
        q_kernel = np.asarray(dec_attn["q_proj"]["kernel"][layer_index], dtype=np.float32)
        k_kernel = np.asarray(dec_attn["k_proj"]["kernel"][layer_index], dtype=np.float32)
        v_kernel = np.asarray(dec_attn["v_proj"]["kernel"][layer_index], dtype=np.float32)
        out_kernel = np.asarray(dec_attn["out_proj"]["kernel"][layer_index], dtype=np.float32)
        q_scale = np.asarray(dec_attn["q_norm"]["scale"][layer_index], dtype=np.float32)
        k_scale = np.asarray(dec_attn["k_norm"]["scale"][layer_index], dtype=np.float32)

        q = inp @ q_kernel
        k = inp @ k_kernel
        v = inp @ v_kernel
        q_len = inp.shape[0]
        q = q.reshape(q_len, num_heads, head_dim)
        k = k.reshape(inp.shape[0], num_kv_heads, head_dim)
        v = v.reshape(inp.shape[0], num_kv_heads, head_dim)
        q = zcrmsnorm_heads(q, q_scale)
        k = zcrmsnorm_heads(k, k_scale)
        q = rope(q, theta)
        k = rope(k, theta)
        repeats = num_heads // num_kv_heads
        k = np.repeat(k, repeats, axis=1)
        v = np.repeat(v, repeats, axis=1)

        qh = np.transpose(q, (1, 0, 2))
        kh = np.transpose(k, (1, 0, 2))
        vh = np.transpose(v, (1, 0, 2))
        scores = np.matmul(qh, np.transpose(kh, (0, 2, 1))) / math.sqrt(head_dim)
        if causal:
            mask = np.tril(np.ones((q_len, q_len), dtype=bool))
            scores = np.where(mask[None, :, :], scores, -np.finfo(np.float32).max)
        weights = softmax(scores, axis=-1)
        out = np.matmul(weights, vh)
        out = np.transpose(out, (1, 0, 2)).reshape(q_len, d_model)
        return out @ out_kernel

    def decoder_cross_attention(inp: np.ndarray, enc: np.ndarray, layer_index: int) -> np.ndarray:
        cross = params["decoder"]["layers"]["DecoderBlock_0"]["cross_attn"]
        q_kernel = np.asarray(cross["q_proj"]["kernel"][layer_index], dtype=np.float32)
        k_kernel = np.asarray(cross["k_proj"]["kernel"][layer_index], dtype=np.float32)
        v_kernel = np.asarray(cross["v_proj"]["kernel"][layer_index], dtype=np.float32)
        out_kernel = np.asarray(cross["out_proj"]["kernel"][layer_index], dtype=np.float32)
        q_scale = np.asarray(cross["q_norm"]["scale"][layer_index], dtype=np.float32)
        k_scale = np.asarray(cross["k_norm"]["scale"][layer_index], dtype=np.float32)
        q = inp @ q_kernel
        k = enc @ k_kernel
        v = enc @ v_kernel
        q_len = inp.shape[0]
        q = q.reshape(q_len, num_heads, head_dim)
        k = k.reshape(enc.shape[0], num_kv_heads, head_dim)
        v = v.reshape(enc.shape[0], num_kv_heads, head_dim)
        q = zcrmsnorm_heads(q, q_scale)
        k = zcrmsnorm_heads(k, k_scale)
        repeats = num_heads // num_kv_heads
        k = np.repeat(k, repeats, axis=1)
        v = np.repeat(v, repeats, axis=1)
        qh = np.transpose(q, (1, 0, 2))
        kh = np.transpose(k, (1, 0, 2))
        vh = np.transpose(v, (1, 0, 2))
        scores = np.matmul(qh, np.transpose(kh, (0, 2, 1))) / math.sqrt(head_dim)
        weights = softmax(scores, axis=-1)
        out = np.matmul(weights, vh)
        out = np.transpose(out, (1, 0, 2)).reshape(q_len, d_model)
        return out @ out_kernel

    def decoder_block(inp: np.ndarray, enc: np.ndarray, layer_index: int) -> np.ndarray:
        dec_layers = params["decoder"]["layers"]["DecoderBlock_0"]
        self_norm_scale = np.asarray(dec_layers["ZCRMSNorm_0"]["scale"][layer_index], dtype=np.float32)
        cross_norm_scale = np.asarray(dec_layers["ZCRMSNorm_1"]["scale"][layer_index], dtype=np.float32)
        self_gate_raw = float(np.asarray(dec_layers["self_attn_gate"], dtype=np.float32)[layer_index])
        cross_gate_raw = float(np.asarray(dec_layers["cross_attn_gate"], dtype=np.float32)[layer_index])
        self_normed = zcrmsnorm_model(inp, self_norm_scale)
        self_out = decoder_self_attention(self_normed, layer_index, causal=True)
        self_gate = 1.0 / (1.0 + math.exp(-self_gate_raw))
        hidden = inp + self_gate * self_out
        cross_normed = zcrmsnorm_model(hidden, cross_norm_scale)
        cross_out = decoder_cross_attention(cross_normed, enc, layer_index)
        cross_gate = 1.0 / (1.0 + math.exp(-cross_gate_raw))
        return hidden + cross_gate * cross_out

    def encoder_block(inp: np.ndarray, layer_index: int) -> np.ndarray:
        block_norm_scale = np.asarray(enc_layers["ZCRMSNorm_0"]["scale"][layer_index], dtype=np.float32)
        attn_gate_raw = float(np.asarray(enc_layers["attn_gate"], dtype=np.float32)[layer_index])
        normed = zcrmsnorm_model(inp, block_norm_scale)
        projected = self_attention(normed, layer_index)
        gate = 1.0 / (1.0 + math.exp(-attn_gate_raw))
        return inp + gate * projected

    projected = self_attention(x, layer)
    decoder_self = decoder_self_attention(x, layer, causal=True)
    block_norm_scale = np.asarray(enc_layers["ZCRMSNorm_0"]["scale"][layer], dtype=np.float32)
    attn_gate_raw = float(np.asarray(enc_layers["attn_gate"], dtype=np.float32)[layer])
    normed_x = zcrmsnorm_model(x, block_norm_scale)
    block_attention = self_attention(normed_x, layer)
    gate = 1.0 / (1.0 + math.exp(-attn_gate_raw))
    block_out = x + gate * block_attention
    logits = block_out @ emb.T

    encoder = x * math.sqrt(d_model)
    for layer_index in range(int(cfg["num_encoder_layers"])):
        encoder = encoder_block(encoder, layer_index)
    final_scale = np.asarray(params["encoder"]["final_norm"]["scale"], dtype=np.float32)
    encoder = zcrmsnorm_model(encoder, final_scale)
    decoder_cross = decoder_cross_attention(x, encoder, layer)
    decoder_block_out = decoder_block(x, encoder, layer)
    decoder = x * math.sqrt(d_model)
    for layer_index in range(int(cfg["num_decoder_layers"])):
        decoder = decoder_block(decoder, encoder, layer_index)
    decoder_final_scale = np.asarray(params["decoder"]["ZCRMSNorm_0"]["scale"], dtype=np.float32)
    decoder = zcrmsnorm_model(decoder, decoder_final_scale)
    forward_logits = decoder @ emb.T

    def encode_token_ids(token_ids: list[int]) -> np.ndarray:
        arr = emb[token_ids].astype(np.float32) * math.sqrt(d_model)
        for layer_index in range(int(cfg["num_encoder_layers"])):
            arr = encoder_block(arr, layer_index)
        return zcrmsnorm_model(arr, final_scale)

    def decode_token_ids(token_ids: list[int], enc: np.ndarray) -> np.ndarray:
        arr = emb[token_ids].astype(np.float32) * math.sqrt(d_model)
        for layer_index in range(int(cfg["num_decoder_layers"])):
            arr = decoder_block(arr, enc, layer_index)
        return zcrmsnorm_model(arr, decoder_final_scale)

    def forward_token_ids(src_ids: list[int], tgt_ids: list[int]) -> np.ndarray:
        enc = encode_token_ids(src_ids)
        dec = decode_token_ids(tgt_ids, enc)
        return dec @ emb.T

    sp = spm.SentencePieceProcessor()
    sp.Load(str(args.tokenizer))
    generation_query = "weather in Paris"
    generation_tools = "[]"
    generation_max_new = 2
    q_ids = list(sp.Encode(generation_query, out_type=int))
    tool_ids = list(sp.Encode(generation_tools, out_type=int))
    generation_src_ids = q_ids + [5] + tool_ids
    generation_ids = [1]
    for _ in range(generation_max_new):
        gen_logits = forward_token_ids(generation_src_ids, generation_ids)
        next_id = int(np.argmax(gen_logits[-1]))
        generation_ids.append(next_id)
        if next_id == 1:
            break
    generation_text = sp.Decode(generation_ids[1:])

    payload = {
        "checkpoint": str(args.checkpoint),
        "tokens": tokens,
        "layer": layer,
        "seq_len": len(tokens),
        "d_model": d_model,
        "input": x.reshape(-1).astype(float).tolist(),
        "expected": projected.reshape(-1).astype(float).tolist(),
        "expected_decoder_self": decoder_self.reshape(-1).astype(float).tolist(),
        "expected_decoder_cross": decoder_cross.reshape(-1).astype(float).tolist(),
        "expected_decoder_block": decoder_block_out.reshape(-1).astype(float).tolist(),
        "expected_decoder": decoder.reshape(-1).astype(float).tolist(),
        "expected_forward_logits": forward_logits.reshape(-1).astype(float).tolist(),
        "generation_query": generation_query,
        "generation_tools": generation_tools,
        "generation_max_new": generation_max_new,
        "expected_generation_ids": generation_ids,
        "expected_generation_text": generation_text,
        "expected_block": block_out.reshape(-1).astype(float).tolist(),
        "expected_logits": logits.reshape(-1).astype(float).tolist(),
        "expected_encoder": encoder.reshape(-1).astype(float).tolist(),
        # The C path uses float32 accumulation and f16->f32 checkpoint values.
        "tolerance": 3e-3,
        "logit_tolerance": 3e-2,
        "cross_tolerance": 6e-3,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, sort_keys=True, indent=2) + "\n")
    print(f"wrote {args.output}")
    print(f"  values: {projected.size}")
    print(f"  first4 attention: {' '.join(f'{x:.9g}' for x in projected.reshape(-1)[:4])}")
    print(f"  first4 decoder self: {' '.join(f'{x:.9g}' for x in decoder_self.reshape(-1)[:4])}")
    print(f"  first4 decoder cross: {' '.join(f'{x:.9g}' for x in decoder_cross.reshape(-1)[:4])}")
    print(f"  first4 decoder block: {' '.join(f'{x:.9g}' for x in decoder_block_out.reshape(-1)[:4])}")
    print(f"  first4 decoder: {' '.join(f'{x:.9g}' for x in decoder.reshape(-1)[:4])}")
    print(f"  first4 forward logits: {' '.join(f'{x:.9g}' for x in forward_logits.reshape(-1)[:4])}")
    print(f"  generation ids: {' '.join(str(x) for x in generation_ids)}")
    print(f"  first4 block: {' '.join(f'{x:.9g}' for x in block_out.reshape(-1)[:4])}")
    print(f"  first4 logits: {' '.join(f'{x:.9g}' for x in logits.reshape(-1)[:4])}")
    print(f"  first4 encoder: {' '.join(f'{x:.9g}' for x in encoder.reshape(-1)[:4])}")


if __name__ == "__main__":
    main()
