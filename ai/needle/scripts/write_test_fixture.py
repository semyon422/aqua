#!/usr/bin/env python3
"""Write a tiny Needle runtime-format fixture for loader tests."""

from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path


MAGIC = b"NDLRTM1\0"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: write_test_fixture.py OUTPUT")

    output = Path(sys.argv[1])
    def f32_tensor(name, shape, values):
        return {
            "name": name,
            "dtype": "f32",
            "dtype_id": 1,
            "shape": shape,
            "raw": struct.pack("<" + "f" * len(values), *values),
        }

    tensors = [
        {
            "name": "embedding/embedding",
            "dtype": "f32",
            "dtype_id": 1,
            "shape": [2, 2],
            "raw": struct.pack("<ffff", 1.0, 2.0, 3.0, 4.0),
        },
        f32_tensor("encoder/layers/EncoderBlock_0/self_attn/q_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/self_attn/k_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/self_attn/v_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/self_attn/out_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/self_attn/q_norm/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/self_attn/k_norm/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/ZCRMSNorm_0/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("encoder/layers/EncoderBlock_0/attn_gate", [1], [0.0]),
        f32_tensor("encoder/final_norm/scale", [2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn/q_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn/k_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn/v_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn/out_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn/q_norm/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn/k_norm/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn/q_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn/k_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn/v_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn/out_proj/kernel", [1, 2, 2], [1.0, 0.0, 0.0, 1.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn/q_norm/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn/k_norm/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/ZCRMSNorm_0/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/ZCRMSNorm_1/scale", [1, 2], [0.0, 0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/self_attn_gate", [1], [0.0]),
        f32_tensor("decoder/layers/DecoderBlock_0/cross_attn_gate", [1], [0.0]),
        f32_tensor("decoder/ZCRMSNorm_0/scale", [2], [0.0, 0.0]),
        {
            "name": "log_temp",
            "dtype": "f16",
            "dtype_id": 2,
            "shape": [],
            "raw": b"\x00\x3c",
        },
    ]
    tokenizer = b"tiny-tokenizer"
    metadata = {
        "format": "NDLRTM1",
        "format_version": 1,
        "config": {
            "vocab_size": 2,
            "d_model": 2,
            "num_heads": 1,
            "num_kv_heads": 1,
            "num_encoder_layers": 1,
            "num_decoder_layers": 1,
            "d_ff": 4,
            "max_seq_len": 8,
            "pad_token_id": 0,
            "rope_theta": 10000.0,
            "dtype": "float32",
            "activation": "swiglu",
            "num_memory_slots": 0,
            "dropout_rate": 0.0,
            "contrastive_dim": 2,
            "enable_speech": False,
            "no_feedforward": True,
        },
        "tokenizer": {"nbytes": len(tokenizer), "sha256": sha256(tokenizer)},
        "tensor_count": len(tensors),
        "tensor_data_bytes": sum(len(t["raw"]) for t in tensors),
        "tensors": [
            {
                "name": t["name"],
                "dtype": t["dtype"],
                "shape": t["shape"],
                "nbytes": len(t["raw"]),
                "sha256": sha256(t["raw"]),
            }
            for t in tensors
        ],
    }
    metadata_bytes = json.dumps(metadata, sort_keys=True, separators=(",", ":")).encode("utf-8")

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<IIQQQ", 1, 0, len(metadata_bytes), len(tokenizer), len(tensors)))
        f.write(metadata_bytes)
        f.write(tokenizer)
        for t in tensors:
            name = t["name"].encode("utf-8")
            f.write(struct.pack("<HHI", len(name), t["dtype_id"], len(t["shape"])))
            for dim in t["shape"]:
                f.write(struct.pack("<Q", dim))
            f.write(struct.pack("<Q", len(t["raw"])))
            f.write(name)
            f.write(t["raw"])


if __name__ == "__main__":
    main()
