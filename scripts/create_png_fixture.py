"""Regenerate the tiny RGB PNG used by CLI and batch examples."""

from pathlib import Path
import struct
import zlib


def chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))


def main() -> None:
    rows = []
    for y in range(3):
        gray = [255 if (x == 1 and y == 1) else 0 for x in range(3)]
        rows.append(bytes([0] + [v for pixel in gray for v in (pixel, pixel, pixel)]))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 3, 3, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"".join(rows)))
        + chunk(b"IEND", b"")
    )
    Path(__file__).resolve().parents[1].joinpath("examples", "ring-image.png").write_bytes(png)


if __name__ == "__main__":
    main()
