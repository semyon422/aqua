#!/usr/bin/env python3
"""Export a Needle pickle checkpoint into the dependency-free runtime format."""

from __future__ import annotations

import argparse
import hashlib
import json
import pickle
import struct
from pathlib import Path
from typing import Any

import jax
import numpy as np

from export_tokenizer_runtime import export_tokenizer


MAGIC = b"NDLRTM1\0"
FORMAT_VERSION = 1

DTYPE_TO_ID = {
    "float32": 1,
    "float16": 2,
    "bfloat16": 3,
    "int8": 4,
    "int32": 5,
    "uint8": 6,
}

DTYPE_TO_NAME = {
    "float32": "f32",
    "float16": "f16",
    "bfloat16": "bf16",
    "int8": "i8",
    "int32": "i32",
    "uint8": "u8",
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def clean_key(part: Any) -> str:
    if hasattr(part, "key"):
        return str(part.key)
    if hasattr(part, "idx"):
        return str(part.idx)
    return str(part).strip("[]'")


def tensor_name(path: tuple[Any, ...]) -> str:
    return "/".join(clean_key(part) for part in path)


def dtype_key(arr: np.ndarray) -> str:
    name = str(arr.dtype)
    if name not in DTYPE_TO_ID:
        raise ValueError(f"unsupported dtype {name}")
    return name


def contiguous_bytes(arr: np.ndarray) -> bytes:
    arr = np.ascontiguousarray(arr)
    if arr.dtype.byteorder == ">":
        arr = arr.byteswap().newbyteorder("<")
    return arr.tobytes(order="C")


def is_quantizable_kernel(name: str, arr: np.ndarray) -> bool:
    return name.endswith("/kernel") and arr.ndim >= 2 and np.issubdtype(arr.dtype, np.floating)


def quantize_int8_per_output_channel(name: str, arr: np.ndarray) -> list[dict[str, Any]]:
    arr_f32 = np.asarray(arr, dtype=np.float32)
    in_dim = arr_f32.shape[-2]
    out_dim = arr_f32.shape[-1]
    flat = arr_f32.reshape((-1, in_dim, out_dim))
    scales = np.empty((flat.shape[0], out_dim), dtype=np.float32)
    q = np.empty(flat.shape, dtype=np.int8)
    for prefix in range(flat.shape[0]):
        for out_ch in range(out_dim):
            column = flat[prefix, :, out_ch]
            max_abs = float(np.max(np.abs(column)))
            scale = max_abs / 127.0 if max_abs > 0.0 else 1.0
            scales[prefix, out_ch] = scale
            q[:, :, :][prefix, :, out_ch] = np.clip(np.rint(column / scale), -127, 127).astype(np.int8)

    q = q.reshape(arr_f32.shape)
    scale_shape = list(arr_f32.shape[:-2]) + [out_dim]
    scales = scales.reshape(scale_shape)
    return [
        {
            "name": name + ".q8",
            "dtype_key": "int8",
            "dtype": DTYPE_TO_NAME["int8"],
            "dtype_id": DTYPE_TO_ID["int8"],
            "shape": list(q.shape),
            "ndim": q.ndim,
            "nbytes": q.nbytes,
            "sha256": sha256_bytes(contiguous_bytes(q)),
            "raw": contiguous_bytes(q),
            "quantized_from": name,
        },
        {
            "name": name + ".q8_scale",
            "dtype_key": "float32",
            "dtype": DTYPE_TO_NAME["float32"],
            "dtype_id": DTYPE_TO_ID["float32"],
            "shape": list(scales.shape),
            "ndim": scales.ndim,
            "nbytes": scales.nbytes,
            "sha256": sha256_bytes(contiguous_bytes(scales)),
            "raw": contiguous_bytes(scales),
            "quantized_from": name,
        },
    ]


def collect_tensors(params: Any, quantize_int8: bool = False, strip_quantized_float_kernels: bool = False) -> list[dict[str, Any]]:
    tensors: list[dict[str, Any]] = []

    def visit(path: tuple[Any, ...], leaf: Any) -> None:
        arr = np.asarray(leaf)
        name = tensor_name(path)
        key = dtype_key(arr)
        quantizable = quantize_int8 and is_quantizable_kernel(name, arr)
        raw = b"\0" if quantizable and strip_quantized_float_kernels else contiguous_bytes(arr)
        tensors.append(
            {
                "name": name,
                "dtype_key": key,
                "dtype": DTYPE_TO_NAME[key],
                "dtype_id": DTYPE_TO_ID[key],
                "shape": list(arr.shape),
                "ndim": arr.ndim,
                "nbytes": len(raw),
                "sha256": sha256_bytes(raw),
                "raw": raw,
                **({"stripped_quantized_float": True} if quantizable and strip_quantized_float_kernels else {}),
            }
        )
        if quantizable:
            tensors.extend(quantize_int8_per_output_channel(name, arr))

    jax.tree_util.tree_map_with_path(lambda path, leaf: visit(path, leaf), params)
    tensors.sort(key=lambda item: item["name"])
    return tensors


def export_runtime(
    checkpoint: Path,
    output: Path,
    tokenizer: Path | None,
    quantize_int8: bool = False,
    strip_quantized_float_kernels: bool = False,
) -> None:
    with checkpoint.open("rb") as f:
        data = pickle.load(f)

    params = data["params"]
    config = data["config"]
    if strip_quantized_float_kernels and not quantize_int8:
        raise ValueError("--strip-quantized-float-kernels requires --quantize-int8")
    tensors = collect_tensors(
        params,
        quantize_int8=quantize_int8,
        strip_quantized_float_kernels=strip_quantized_float_kernels,
    )

    tokenizer_bytes = b""
    tokenizer_meta = None
    if tokenizer is not None:
        tmp_tok = output.with_suffix(".tokenizer.tmp")
        tokenizer_bytes = export_tokenizer(tokenizer, tmp_tok)
        try:
            tmp_tok.unlink()
        except FileNotFoundError:
            pass
        tokenizer_meta = {
            "path": str(tokenizer),
            "nbytes": len(tokenizer_bytes),
            "sha256": sha256_bytes(tokenizer_bytes),
            "format": "NDLTOK1",
        }

    metadata = {
        "format": "NDLRTM1",
        "format_version": FORMAT_VERSION,
        "source_checkpoint": str(checkpoint),
        "source_checkpoint_sha256": sha256_file(checkpoint),
        "config": config,
        "tokenizer": tokenizer_meta,
        "quantization": {
            "enabled": quantize_int8,
            "format": "q8_symmetric_per_output_channel" if quantize_int8 else None,
            "weight_suffix": ".q8",
            "scale_suffix": ".q8_scale",
            "stripped_float_kernels": strip_quantized_float_kernels,
        },
        "tensor_count": len(tensors),
        "tensor_data_bytes": sum(t["nbytes"] for t in tensors),
        "tensors": [
            {
                "name": t["name"],
                "dtype": t["dtype"],
                "shape": t["shape"],
                "nbytes": t["nbytes"],
                "sha256": t["sha256"],
                **({"quantized_from": t["quantized_from"]} if "quantized_from" in t else {}),
                **({"stripped_quantized_float": True} if t.get("stripped_quantized_float") else {}),
            }
            for t in tensors
        ],
    }
    metadata_bytes = json.dumps(metadata, sort_keys=True, separators=(",", ":")).encode("utf-8")

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<IIQQQ", FORMAT_VERSION, 0, len(metadata_bytes), len(tokenizer_bytes), len(tensors)))
        f.write(metadata_bytes)
        f.write(tokenizer_bytes)

        for t in tensors:
            name = t["name"].encode("utf-8")
            if len(name) > 0xFFFF:
                raise ValueError(f"tensor name too long: {t['name']}")
            if t["ndim"] > 32:
                raise ValueError(f"tensor has too many dimensions: {t['name']}")
            f.write(struct.pack("<HHI", len(name), t["dtype_id"], t["ndim"]))
            for dim in t["shape"]:
                f.write(struct.pack("<Q", int(dim)))
            f.write(struct.pack("<Q", t["nbytes"]))
            f.write(name)
            f.write(t["raw"])

    print(f"wrote {output}")
    print(f"  tensors: {len(tensors)}")
    print(f"  tensor bytes: {sum(t['nbytes'] for t in tensors):,}")
    print(f"  tokenizer bytes: {len(tokenizer_bytes):,}")
    print(f"  metadata bytes: {len(metadata_bytes):,}")
    if quantize_int8:
        q_count = sum(1 for t in tensors if t["name"].endswith(".q8"))
        stripped_count = sum(1 for t in tensors if t.get("stripped_quantized_float"))
        print(f"  q8 kernels: {q_count}")
        print(f"  stripped float kernels: {stripped_count}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", default="checkpoints/needle.pkl", type=Path)
    parser.add_argument("--output", default="lua/build/needle.bin", type=Path)
    parser.add_argument("--tokenizer", default="needle/tokenizer/needle.model", type=Path)
    parser.add_argument("--no-tokenizer", action="store_true")
    parser.add_argument("--quantize-int8", action="store_true", help="add int8 per-output-channel kernel tensors")
    parser.add_argument(
        "--strip-quantized-float-kernels",
        action="store_true",
        help="replace float payloads for quantized kernels with one-byte placeholders",
    )
    args = parser.parse_args()

    tokenizer = None if args.no_tokenizer else args.tokenizer
    if tokenizer is not None and not tokenizer.exists():
        raise FileNotFoundError(tokenizer)
    export_runtime(
        args.checkpoint,
        args.output,
        tokenizer,
        quantize_int8=args.quantize_int8,
        strip_quantized_float_kernels=args.strip_quantized_float_kernels,
    )


if __name__ == "__main__":
    main()
