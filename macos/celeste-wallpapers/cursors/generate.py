#!/usr/bin/env python3
"""Convert Cappuccino093's public-domain Windows cursor pack to Mousecape."""
import hashlib, json, plistlib, struct, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE, ASSETS, MAX_FRAMES = ROOT / "source", ROOT / "assets", 24
ROLES = {
    "arrow.cur": ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.coregraphics.ArrowCtx"],
    "ibeam.cur": ["com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS", "com.apple.coregraphics.IBeamXOR", "com.apple.cursor.26"],
    "link.ani": ["com.apple.cursor.2", "com.apple.cursor.13", "com.apple.cursor.12", "com.apple.cursor.11"],
    "cross.cur": ["com.apple.cursor.7", "com.apple.cursor.8", "com.apple.cursor.20"],
    "busy.ani": ["com.apple.cursor.4", "com.apple.coregraphics.Wait"],
    "unavail.cur": ["com.apple.cursor.3"],
    "ns.cur": ["com.apple.cursor.23", "com.apple.cursor.32"],
    "ew.cur": ["com.apple.cursor.19", "com.apple.cursor.28"],
    "nwse.cur": ["com.apple.cursor.34"], "nesw.cur": ["com.apple.cursor.30"],
    "move.cur": ["com.apple.coregraphics.Move"],
}

def u16(data, offset): return struct.unpack_from("<H", data, offset)[0]
def u32(data, offset): return struct.unpack_from("<I", data, offset)[0]

def decode_cur(data):
    if len(data) < 22 or data[:4] != b"\0\0\2\0" or u16(data, 4) != 1:
        raise ValueError("expected one-image CUR")
    width, height = data[6] or 256, data[7] or 256
    hotspot, size, offset = (u16(data, 10), u16(data, 12)), u32(data, 14), u32(data, 18)
    dib = data[offset:offset + size]
    if len(dib) != size or len(dib) < 40 or u32(dib, 0) != 40:
        raise ValueError("truncated or unsupported CUR bitmap")
    dib_width, doubled_height = struct.unpack_from("<ii", dib, 4)
    if (dib_width, doubled_height, u16(dib, 12), u16(dib, 14), u32(dib, 16)) != (width, height * 2, 1, 32, 0):
        raise ValueError("expected uncompressed 32-bit CUR bitmap")
    pixels = dib[40:40 + width * height * 4]
    if len(pixels) != width * height * 4: raise ValueError("truncated CUR pixels")
    rgba = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            source, target = (((height - 1 - y) * width + x) * 4, (y * width + x) * 4)
            b, g, r, a = pixels[source:source + 4]
            rgba[target:target + 4] = bytes((r, g, b, a))
    if not 0 <= hotspot[0] < width or not 0 <= hotspot[1] < height: raise ValueError("CUR hotspot outside image")
    return width, height, hotspot, bytes(rgba)

def riff_chunks(data, start, end):
    offset = start
    while offset + 8 <= end:
        kind, size = struct.unpack_from("<4sI", data, offset); body, limit = offset + 8, offset + 8 + size
        if limit > end: raise ValueError("truncated RIFF chunk")
        yield kind, data[body:limit]
        offset = limit + (size & 1)

def decode_ani(data):
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"ACON": raise ValueError("expected ANI RIFF container")
    header = rates = sequence = None; icons = []
    for kind, body in riff_chunks(data, 12, min(len(data), 8 + u32(data, 4))):
        if kind == b"anih": header = struct.unpack_from("<9I", body)
        elif kind == b"rate": rates = list(struct.unpack("<" + "I" * (len(body) // 4), body))
        elif kind == b"seq ": sequence = list(struct.unpack("<" + "I" * (len(body) // 4), body))
        elif kind == b"LIST" and body[:4] == b"fram": icons.extend(chunk for subkind, chunk in riff_chunks(body, 4, len(body)) if subkind == b"icon")
    if header is None or not icons: raise ValueError("ANI lacks header or frames")
    _, declared_frames, declared_steps, _, _, _, _, default_rate, flags = header
    if not flags & 1 or declared_frames != len(icons): raise ValueError("unsupported ANI frame layout")
    order = sequence if sequence is not None else list(range(len(icons)))
    if declared_steps and len(order) != declared_steps: raise ValueError("ANI sequence length mismatch")
    if not order or len(order) > MAX_FRAMES or any(index >= len(icons) for index in order): raise ValueError("ANI frame count outside Mousecape limit")
    decoded = [decode_cur(icons[index]) for index in order]; width, height, hotspot, _ = decoded[0]
    if any(frame[:3] != (width, height, hotspot) for frame in decoded): raise ValueError("ANI frame geometry or hotspot changes")
    frame_rates = rates if rates is not None else [default_rate] * len(order)
    if len(frame_rates) != len(order) or not frame_rates or len(set(frame_rates)) != 1 or frame_rates[0] == 0: raise ValueError("Mousecape requires one positive uniform ANI frame duration")
    return width, height, hotspot, [frame[3] for frame in decoded], frame_rates[0] / 60.0

def png(width, height, rgba):
    raw = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    def chunk(kind, body): return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")

def scale_and_stack(width, height, frames, scale):
    out_width = width * scale; out = bytearray(out_width * height * scale * len(frames) * 4)
    for frame_index, frame in enumerate(frames):
        for y in range(height):
            for x in range(width):
                pixel = frame[(y * width + x) * 4:(y * width + x + 1) * 4]
                for dy in range(scale):
                    for dx in range(scale):
                        target = (((frame_index * height * scale + y * scale + dy) * out_width) + x * scale + dx) * 4
                        out[target:target + 4] = pixel
    return png(out_width, height * scale * len(frames), bytes(out))

def contact_sheet(items):
    cell, columns = 72, 4; rows = (len(items) + columns - 1) // columns
    canvas = bytearray(cell * columns * cell * rows * 4)
    for index, (_, width, height, frame) in enumerate(items):
        ox, oy = (index % columns) * cell + (cell - width * 2) // 2, (index // columns) * cell + (cell - height * 2) // 2
        for y in range(height):
            for x in range(width):
                pixel = frame[(y * width + x) * 4:(y * width + x + 1) * 4]
                for dy in range(2):
                    for dx in range(2):
                        target = (((oy + y * 2 + dy) * cell * columns) + ox + x * 2 + dx) * 4
                        canvas[target:target + 4] = pixel
    return png(cell * columns, cell * rows, bytes(canvas))

expected = json.loads((SOURCE / "SHA256.json").read_text()); ASSETS.mkdir(exist_ok=True)
for filename, digest in expected.items():
    if hashlib.sha256((SOURCE / filename).read_bytes()).hexdigest() != digest:
        raise ValueError(f"hash mismatch: {filename}")
for old_preview in ASSETS.glob("*.png"):
    old_preview.unlink()
cursors, sheet = {}, []
for filename, identifiers in ROLES.items():
    data = (SOURCE / filename).read_bytes()
    if filename.endswith(".ani"): width, height, hotspot, frames, duration = decode_ani(data)
    else: width, height, hotspot, frame = decode_cur(data); frames, duration = [frame], 0.0
    if (width, height) != (32, 32): raise ValueError(f"unexpected dimensions: {filename}")
    one, two = scale_and_stack(width, height, frames, 1), scale_and_stack(width, height, frames, 2)
    stem = Path(filename).stem; (ASSETS / f"{stem}@1x.png").write_bytes(one); (ASSETS / f"{stem}@2x.png").write_bytes(two)
    entry = {"FrameCount": len(frames), "FrameDuration": duration, "HotSpotX": float(hotspot[0]), "HotSpotY": float(hotspot[1]), "PointsWide": float(width), "PointsHigh": float(height), "Representations": [one, two]}
    for identifier in identifiers: cursors[identifier] = entry
    sheet.append((stem, width, height, frames[0]))
(ASSETS / "contact-sheet.png").write_bytes(contact_sheet(sheet))
cape = {"Author": "Cappuccino093", "CapeName": "Celeste's Strawberries", "CapeVersion": 1.0, "Cloud": False, "HiDPI": True, "Identifier": "com.kianconti.celeste-strawberries", "MinimumVersion": 2.0, "Version": 2.0, "Cursors": cursors}
(ROOT / "Celeste.cape").write_bytes(plistlib.dumps(cape, fmt=plistlib.FMT_BINARY, sort_keys=True))
print(f"Converted {len(ROLES)} source cursors into {len(cursors)} identifiers")
