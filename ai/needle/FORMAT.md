# Needle Runtime Asset Format

Runtime model files use a simple little-endian binary container. The format is intentionally sequential so the C loader can validate it without dependencies.

## Header

```text
magic[8]          "NDLRTM1\0"
u32 format_version
u32 flags         reserved, must be 0 for v1
u64 metadata_len
u64 tokenizer_len
u64 tensor_count
```

All integers are little-endian.

## Payload

```text
metadata_json[metadata_len]
tokenizer_bytes[tokenizer_len]

repeat tensor_count:
  u16 name_len
  u16 dtype
  u32 ndim
  u64 shape[ndim]
  u64 data_nbytes
  name_bytes[name_len]
  raw_tensor_bytes[data_nbytes]
```

## Dtype Values

```text
1 = f32
2 = f16
3 = bf16
4 = i8
5 = i32
6 = u8
```

## Metadata

The metadata block is UTF-8 JSON. The C runtime treats it as opaque text at this stage, while Lua/Python tools may inspect it.

Expected top-level fields:

```json
{
  "format": "NDLRTM1",
  "format_version": 1,
  "source_checkpoint": "checkpoints/needle.pkl",
  "source_checkpoint_sha256": "...",
  "config": {},
  "tokenizer": {
    "path": "needle/tokenizer/needle.model",
    "nbytes": 0,
    "sha256": "..."
  },
  "tensors": [
    {
      "name": "embedding/embedding",
      "dtype": "f16",
      "shape": [8192, 512],
      "nbytes": 8388608,
      "sha256": "..."
    }
  ]
}
```

## Notes

- Python pickle is never read by the C runtime.
- Tensor names use `/`-separated parameter tree paths.
- v1 stores tensors exactly as exported, usually float16 for the current Needle checkpoint.
- The model container may embed a tokenizer block. For dependency-free tokenization, that block should use `NDLTOK1`.
- Later versions may add alignment and quantized blocks.

## Tokenizer Format

`NDLTOK1` is a dependency-free export of the SentencePiece BPE model.

```text
magic[8]          "NDLTOK1\0"
u32 version       1
u32 flags         reserved, must be 0
u32 vocab_size
u32 unk_id
u32 bos_id
u32 eos_id
u32 pad_id
u32 tool_call_id
u32 tools_id
u64 string_bytes

repeat vocab_size:
  u32 offset
  u32 byte_len
  f32 score
  u16 type
  u16 reserved

strings[string_bytes]
```

Piece types mirror SentencePiece:

```text
1 = normal
2 = unknown
3 = control
4 = user-defined
6 = byte
```

The v1 C tokenizer implements the Needle model settings: identity normalization, dummy prefix, extra whitespace removal, whitespace escaping with `▁`, byte fallback, and BPE pair merging by score.
