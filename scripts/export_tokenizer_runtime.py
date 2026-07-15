#!/usr/bin/env python3
"""Export Needle's SentencePiece tokenizer into NDLTOK1."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

import sentencepiece as spm
import sentencepiece.sentencepiece_model_pb2 as sp_pb


MAGIC = b"NDLTOK1\0"
VERSION = 1


def export_tokenizer(model_path: Path, output: Path) -> bytes:
    raw = model_path.read_bytes()
    model = sp_pb.ModelProto()
    model.ParseFromString(raw)

    sp = spm.SentencePieceProcessor()
    sp.Load(str(model_path))

    pieces = []
    strings = bytearray()
    for piece in model.pieces:
        data = piece.piece.encode("utf-8")
        offset = len(strings)
        strings.extend(data)
        pieces.append((offset, len(data), float(piece.score), int(piece.type)))

    out = bytearray()
    out.extend(MAGIC)
    out.extend(
        struct.pack(
            "<IIIIIIIIIQ",
            VERSION,
            0,
            len(pieces),
            sp.unk_id(),
            sp.bos_id(),
            sp.eos_id(),
            sp.pad_id(),
            sp.PieceToId("<tool_call>"),
            sp.PieceToId("<tools>"),
            len(strings),
        )
    )
    for offset, byte_len, score, typ in pieces:
        out.extend(struct.pack("<IIfHH", offset, byte_len, score, typ, 0))
    out.extend(strings)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(out)
    print(f"wrote {output}")
    print(f"  vocab: {len(pieces)}")
    print(f"  strings: {len(strings):,} bytes")
    print(f"  total: {len(out):,} bytes")
    return bytes(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="needle/tokenizer/needle.model", type=Path)
    parser.add_argument("--output", default="lua/build/tokenizer.ndltok", type=Path)
    args = parser.parse_args()
    export_tokenizer(args.model, args.output)


if __name__ == "__main__":
    main()
