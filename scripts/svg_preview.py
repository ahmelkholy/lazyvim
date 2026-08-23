#!/usr/bin/env python3
"""Render a bounded SVG preview with ANSI half-block pixels."""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

BACKGROUND = (26, 27, 38)

QUADRANTS = {
    0: " ",
    1: "▗",
    2: "▖",
    3: "▄",
    4: "▝",
    5: "▐",
    6: "▞",
    7: "▟",
    8: "▘",
    9: "▚",
    10: "▌",
    11: "▙",
    12: "▀",
    13: "▜",
    14: "▛",
    15: "█",
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("width", type=int)
    parser.add_argument("height", type=int)
    return parser.parse_args()


def convert(path: Path, width: int, pixel_height: int) -> bytes:
    converter = shutil.which("rsvg-convert")
    if converter is None:
        raise RuntimeError("rsvg-convert is required for SVG preview")

    result = subprocess.run(
        [
            converter,
            "--width",
            str(width),
            "--height",
            str(pixel_height),
            "--keep-aspect-ratio",
            "--background-color",
            "#1a1b26",
            str(path),
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=12,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(message or "rsvg-convert failed")

    return result.stdout


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    corner_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= corner_distance:
        return left
    if above_distance <= corner_distance:
        return above
    return upper_left


def decode_png(data: bytes) -> tuple[int, int, list[list[tuple[int, int, int]]]]:
    """Decode the small non-interlaced PNG emitted by librsvg."""
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError("rsvg-convert did not return a PNG")

    width = height = bit_depth = color_type = interlace = 0
    compressed = bytearray()
    offset = 8
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break

    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if not width or not height or bit_depth != 8 or interlace != 0 or not channels:
        raise RuntimeError("unsupported PNG output from rsvg-convert")

    raw = zlib.decompress(compressed)
    stride = width * channels
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise RuntimeError("incomplete PNG output from rsvg-convert")

    rows: list[list[tuple[int, int, int]]] = []
    previous = bytearray(stride)
    position = 0
    for _ in range(height):
        filter_type = raw[position]
        position += 1
        scanline = bytearray(raw[position : position + stride])
        position += stride
        for index in range(stride):
            left = scanline[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                scanline[index] = (scanline[index] + left) & 255
            elif filter_type == 2:
                scanline[index] = (scanline[index] + above) & 255
            elif filter_type == 3:
                scanline[index] = (scanline[index] + ((left + above) // 2)) & 255
            elif filter_type == 4:
                scanline[index] = (scanline[index] + paeth(left, above, upper_left)) & 255
            elif filter_type != 0:
                raise RuntimeError("unsupported PNG scanline filter")

        row: list[tuple[int, int, int]] = []
        for column in range(width):
            start = column * channels
            if color_type == 0:
                red = green = blue = scanline[start]
                alpha = 255
            elif color_type == 2:
                red, green, blue = scanline[start : start + 3]
                alpha = 255
            elif color_type == 4:
                red = green = blue = scanline[start]
                alpha = scanline[start + 1]
            else:
                red, green, blue, alpha = scanline[start : start + 4]
            if alpha < 255:
                red = (red * alpha + BACKGROUND[0] * (255 - alpha)) // 255
                green = (green * alpha + BACKGROUND[1] * (255 - alpha)) // 255
                blue = (blue * alpha + BACKGROUND[2] * (255 - alpha)) // 255
            row.append((red, green, blue))
        rows.append(row)
        previous = scanline
    return width, height, rows


def canvas(
    image: tuple[int, int, list[list[tuple[int, int, int]]]], width: int, pixel_height: int
) -> list[list[tuple[int, int, int]]]:
    image_width, image_height, pixels = image
    result = [[BACKGROUND for _ in range(width)] for _ in range(pixel_height)]
    left = max(0, (width - image_width) // 2)
    top = max(0, (pixel_height - image_height) // 2)
    for row in range(min(image_height, pixel_height)):
        for column in range(min(image_width, width)):
            result[top + row][left + column] = pixels[row][column]
    return result


def color(value: tuple[int, int, int]) -> tuple[int, int, int]:
    # Small quantization substantially reduces escape sequences while keeping
    # antialiased SVG edges visually smooth in a terminal.
    return tuple(min(255, (channel // 4) * 4) for channel in value)


def distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((left[index] - right[index]) ** 2 for index in range(3))


def average(values: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    return tuple(sum(value[index] for value in values) // len(values) for index in range(3))


def quadrant(
    pixels: list[tuple[int, int, int]],
) -> tuple[str, tuple[int, int, int], tuple[int, int, int]]:
    """Represent four SVG pixels with a two-color Unicode quadrant cell."""
    first = pixels[0]
    second = max(pixels[1:], key=lambda candidate: distance(first, candidate))
    if distance(first, second) < 36:
        uniform = color(average(pixels))
        return " ", uniform, uniform

    foreground, background = first, second
    foreground_group: list[tuple[int, int, int]] = []
    background_group: list[tuple[int, int, int]] = []
    assignments: list[bool] = []
    for _ in range(2):
        assignments = [distance(pixel, foreground) <= distance(pixel, background) for pixel in pixels]
        foreground_group = [pixel for pixel, selected in zip(pixels, assignments, strict=True) if selected]
        background_group = [pixel for pixel, selected in zip(pixels, assignments, strict=True) if not selected]
        if foreground_group:
            foreground = average(foreground_group)
        if background_group:
            background = average(background_group)

    weights = (8, 4, 2, 1)
    mask = sum(weight for weight, selected in zip(weights, assignments, strict=True) if selected)
    if mask.bit_count() > 2:
        mask = 15 - mask
        foreground, background = background, foreground
    return QUADRANTS[mask], color(foreground), color(background)


def render(image: list[list[tuple[int, int, int]]], rows: int) -> None:
    output: list[str] = ["\x1b[?25l\x1b[2J\x1b[H"]
    columns = len(image[0]) // 2
    for row in range(rows):
        foreground: tuple[int, int, int] | None = None
        background: tuple[int, int, int] | None = None
        parts: list[str] = []
        top = row * 2
        bottom = min(top + 1, len(image) - 1)
        for column in range(columns):
            left = column * 2
            right = left + 1
            character, next_foreground, next_background = quadrant(
                [
                    image[top][left],
                    image[top][right],
                    image[bottom][left],
                    image[bottom][right],
                ]
            )
            if next_foreground != foreground:
                parts.append("\x1b[38;2;%d;%d;%dm" % next_foreground)
                foreground = next_foreground
            if next_background != background:
                parts.append("\x1b[48;2;%d;%d;%dm" % next_background)
                background = next_background
            parts.append(character)
        parts.append("\x1b[0m")
        output.append("".join(parts))
        if row + 1 < rows:
            output.append("\r\n")
    output.append("\x1b[0m")
    sys.stdout.write("".join(output))
    sys.stdout.flush()


def main() -> int:
    options = arguments()
    width = max(16, min(options.width, 140))
    rows = max(6, min(options.height, 50))
    if not options.path.is_file():
        print(f"SVG file does not exist: {options.path}", file=sys.stderr)
        return 1
    if options.path.stat().st_size > 16 * 1024 * 1024:
        print("SVG preview is limited to 16 MB source files", file=sys.stderr)
        return 1

    try:
        pixel_width = width * 2
        image = canvas(decode_png(convert(options.path, pixel_width, rows * 2)), pixel_width, rows * 2)
        render(image, rows)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"SVG preview failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
