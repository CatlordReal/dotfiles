#!/usr/bin/env python3
"""Rasterise one image into an exact transparent PNG canvas for Kitty cells."""

import argparse
import gzip
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ElementTree


MAX_DIMENSION = 16_384
MAX_PIXELS = 64_000_000
MAX_SVG_HEADER = 1_048_576


class RenderError(Exception):
    pass


def run(command):
    try:
        return subprocess.run(command, check=True, text=True, capture_output=True)
    except FileNotFoundError as exc:
        raise RenderError("Required executable not found: %s" % command[0]) from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or exc.stdout.strip() or "command failed"
        raise RenderError("%s: %s" % (command[0], detail)) from exc


def positive_float(value, name):
    try:
        result = float(value)
    except ValueError as exc:
        raise RenderError("%s must be a finite positive number" % name) from exc
    if not math.isfinite(result) or result <= 0:
        raise RenderError("%s must be a finite positive number" % name)
    return result


def checked_dimensions(width, height, label):
    if (not math.isfinite(width) or not math.isfinite(height) or width <= 0 or height <= 0 or
            width > MAX_DIMENSION or height > MAX_DIMENSION or width * height > MAX_PIXELS):
        raise RenderError("%s exceeds %dx%d or %d pixels" % (
            label, MAX_DIMENSION, MAX_DIMENSION, MAX_PIXELS
        ))


def positive_dimensions(width, height, label):
    if not math.isfinite(width) or not math.isfinite(height) or width <= 0 or height <= 0:
        raise RenderError("%s dimensions must be finite and positive" % label)


def is_svg(source):
    if source.suffix.lower() in {".svg", ".svgz"}:
        return True
    try:
        with source.open("rb") as handle:
            prefix = handle.read(4096).lstrip().lower()
    except OSError as exc:
        raise RenderError("Cannot read source: %s" % exc) from exc
    return b"<svg" in prefix or prefix.startswith(b"<?xml") and b"svg" in prefix


def svg_length(value):
    if value is None:
        return None
    value = value.strip().lower()
    units = {"": 1, "px": 1, "in": 96, "cm": 96 / 2.54, "mm": 96 / 25.4,
             "pt": 96 / 72, "pc": 16}
    for unit in sorted(units, key=len, reverse=True):
        if value.endswith(unit) and value[:-len(unit) if unit else None].strip():
            try:
                number = float(value[:-len(unit) if unit else None])
            except ValueError:
                return None
            return number * units[unit] if math.isfinite(number) and number > 0 else None
    return None


def svg_size(source):
    try:
        opener = gzip.open if source.suffix.lower() == ".svgz" else open
        with opener(source, "rb") as handle:
            parser = ElementTree.XMLPullParser(events=("start",))
            root, total, previous = None, 0, b""
            while root is None and total < MAX_SVG_HEADER:
                chunk = handle.read(min(4096, MAX_SVG_HEADER - total))
                if not chunk:
                    break
                total += len(chunk)
                if b"\x00" in chunk:
                    raise RenderError("SVG metadata must use UTF-8 compatible XML")
                declaration = (previous + chunk).upper()
                if b"<!DOCTYPE" in declaration or b"<!ENTITY" in declaration:
                    raise RenderError("SVG DTD and entity declarations are not supported")
                previous = chunk[-16:]
                parser.feed(chunk)
                root = next((node for _, node in parser.read_events()), None)
            if root is None:
                raise RenderError("SVG root must occur within the first 1 MiB of decompressed data")
    except (OSError, EOFError, ElementTree.ParseError) as exc:
        raise RenderError("Could not read SVG metadata: %s" % exc) from exc
    if root.tag.rsplit("}", 1)[-1].lower() != "svg":
        raise RenderError("Source is not an SVG document")
    width, height = svg_length(root.get("width")), svg_length(root.get("height"))
    view_box = root.get("viewBox")
    try:
        _, _, view_width, view_height = [float(value) for value in view_box.replace(",", " ").split()]
        if not (math.isfinite(view_width) and math.isfinite(view_height) and view_width > 0 and view_height > 0):
            raise ValueError
    except (AttributeError, ValueError):
        view_width = view_height = None
    if width is None and height is None and view_width is not None:
        width, height = view_width, view_height
    if width is None and height is not None and view_width is not None:
        width = height * view_width / view_height
    if height is None and width is not None and view_width is not None:
        height = width * view_height / view_width
    if width is None or height is None:
        raise RenderError("SVG requires intrinsic width/height or a valid viewBox")
    positive_dimensions(width, height, "source")
    return width, height


def native_size(source, svg):
    if svg:
        return svg_size(source)
    image = str(source) + "[0]"
    result = run(["magick", "identify", "-ping", "-format", "%w,%h", str(image)])
    try:
        width, height = (int(part) for part in result.stdout.split(",", 1))
    except ValueError as exc:
        raise RenderError("Could not determine source dimensions") from exc
    positive_dimensions(width, height, "source")
    checked_dimensions(width, height, "raster source")
    return width, height


def rounded(value):
    if not math.isfinite(value):
        raise RenderError("Scaled image dimensions must be finite")
    return int(math.floor(value + 0.5))


def placement(source_width, source_height, canvas_width, canvas_height, fit, scale,
              align_x, align_y):
    ratio_x = canvas_width / source_width
    ratio_y = canvas_height / source_height
    if fit == "contain":
        width = source_width * min(ratio_x, ratio_y) * scale
        height = source_height * min(ratio_x, ratio_y) * scale
    elif fit == "cover":
        width = source_width * max(ratio_x, ratio_y) * scale
        height = source_height * max(ratio_x, ratio_y) * scale
    elif fit == "fill":
        width = canvas_width * scale
        height = canvas_height * scale
    else:
        width = source_width * scale
        height = source_height * scale
    checked_dimensions(width, height, "scaled source")
    width, height = rounded(width), rounded(height)
    if width < 1 or height < 1:
        raise RenderError("Scaled image rounds below one pixel")
    checked_dimensions(width, height, "scaled source")
    x_factor = {"left": 0.0, "center": 0.5, "right": 1.0}[align_x]
    y_factor = {"top": 0.0, "center": 0.5, "bottom": 1.0}[align_y]
    x = rounded((canvas_width - width) * x_factor)
    y = rounded((canvas_height - height) * y_factor)
    return width, height, x, y


def render(source, output, width, height, fit, scale, align_x, align_y):
    checked_dimensions(width, height, "canvas")
    if not source.is_file():
        raise RenderError("Source is not a file: %s" % source)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="kitty-cells-render-") as directory:
        temporary = Path(directory)
        svg = is_svg(source)
        source_width, source_height = native_size(source, svg)
        image_width, image_height, x, y = placement(
            source_width, source_height, width, height, fit, scale, align_x, align_y
        )
        raster = temporary / "raster.png"
        if svg:
            run([
                "rsvg-convert", "--format", "png", "--width", str(image_width),
                "--height", str(image_height), "--output", str(raster), str(source),
            ])
        else:
            run([
                "magick", str(source) + "[0]", "-resize", "%dx%d!" % (image_width, image_height),
                str(raster),
            ])
        geometry = "%+d%+d" % (x, y)
        run([
            "magick", "-size", "%dx%d" % (width, height), "xc:none", str(raster),
            "-geometry", geometry, "-compose", "over", "-composite", "png32:" + str(output),
        ])
    return {
        "canvas": {"width": width, "height": height},
        "source": {"width": source_width, "height": source_height, "svg": svg},
        "placement": {"x": x, "y": y, "width": image_width, "height": image_height},
    }


def parse_arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--width", required=True)
    parser.add_argument("--height", required=True)
    parser.add_argument("--fit", choices=("contain", "cover", "fill", "none"), default="contain")
    parser.add_argument("--scale", default="1")
    parser.add_argument("--align-x", choices=("left", "center", "right"), default="center")
    parser.add_argument("--align-y", choices=("top", "center", "bottom"), default="center")
    return parser.parse_args()


def main():
    try:
        args = parse_arguments()
        width = positive_float(args.width, "width")
        height = positive_float(args.height, "height")
        if width != width.__floor__() or height != height.__floor__():
            raise RenderError("width and height must be whole pixels")
        geometry = render(
            Path(args.source), Path(args.output), int(width), int(height), args.fit,
            positive_float(args.scale, "scale"), args.align_x, args.align_y,
        )
        print(json.dumps(geometry, separators=(",", ":")))
        return 0
    except (RenderError, OSError) as exc:
        print("render.py: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
