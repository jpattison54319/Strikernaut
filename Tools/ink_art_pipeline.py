#!/usr/bin/env python3
"""Deterministic Strikernaut inked-comic treatment for production raster art."""

from __future__ import annotations

import argparse
import hashlib
import math
import random
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


@dataclass(frozen=True)
class Preset:
    contrast: float
    saturation: float
    edge_threshold: int
    edge_strength: float
    hatch_strength: float
    grit_strength: float
    poster_bits: int


PRESETS = {
    "environment": Preset(1.18, 1.10, 31, 0.72, 0.28, 0.12, 6),
    "sprite": Preset(1.22, 1.14, 24, 0.88, 0.34, 0.08, 6),
    "projectile": Preset(1.26, 1.18, 20, 0.92, 0.22, 0.06, 6),
    "icon": Preset(1.20, 1.14, 27, 0.78, 0.24, 0.06, 6),
}


def stable_seed(path: Path) -> int:
    digest = hashlib.sha256(path.name.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], byteorder="big")


def classify(path: Path) -> str:
    name = path.stem
    if "AppIcon" in name:
        return "icon"
    if name.startswith("SoccerBall"):
        return "projectile"
    if name in {
        "MenuHero",
        "OnboardingHero",
        "GameplayArena",
        "MarsArena",
        "UpgradeBay",
        "AbilityMeteor",
        "AbilityMeteorImpact",
        "AbilityShockwave",
    }:
        return "environment"
    return "sprite"


def diagonal_pattern(size: tuple[int, int], spacing: int, opposite: bool) -> Image.Image:
    width, height = size
    pattern = Image.new("L", size, 0)
    draw = ImageDraw.Draw(pattern)
    offset = width + height
    for start in range(-offset, offset * 2, spacing):
        if opposite:
            draw.line((start, 0, start - height, height), fill=255, width=max(1, spacing // 10))
        else:
            draw.line((start, 0, start + height, height), fill=255, width=max(1, spacing // 10))
    return pattern


def make_grit(size: tuple[int, int], seed: int, density: float) -> Image.Image:
    width, height = size
    rng = random.Random(seed)
    grit = Image.new("L", size, 0)
    draw = ImageDraw.Draw(grit)
    count = int(width * height * density)
    scale = max(1, round(min(width, height) / 512))
    for _ in range(count):
        x = rng.randrange(width)
        y = rng.randrange(height)
        radius = rng.choice((1, 1, 1, 2)) * scale
        value = rng.randrange(70, 155)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=value)
    return grit.filter(ImageFilter.GaussianBlur(radius=max(0.2, scale * 0.18)))


def color_grade(rgb: Image.Image, preset: Preset) -> Image.Image:
    graded = ImageOps.autocontrast(rgb, cutoff=0.6)
    graded = ImageEnhance.Contrast(graded).enhance(preset.contrast)
    graded = ImageEnhance.Color(graded).enhance(preset.saturation)
    graded = ImageOps.posterize(graded, preset.poster_bits)

    pixels = np.asarray(graded).astype(np.float32)
    luminance = pixels[..., 0] * 0.2126 + pixels[..., 1] * 0.7152 + pixels[..., 2] * 0.0722
    highlight = np.clip((luminance - 150.0) / 105.0, 0.0, 1.0)[..., None]
    paper = np.array([232.0, 224.0, 199.0], dtype=np.float32)
    pixels = pixels * (1.0 - highlight * 0.08) + paper * (highlight * 0.08)
    return Image.fromarray(np.uint8(np.clip(pixels, 0, 255)), "RGB")


def internal_edge_mask(rgb: Image.Image, threshold: int) -> Image.Image:
    softened = rgb.filter(ImageFilter.GaussianBlur(radius=max(0.65, min(rgb.size) / 900)))
    edges = softened.filter(ImageFilter.FIND_EDGES).convert("L")
    edges = ImageOps.autocontrast(edges, cutoff=1)
    return edges.point(lambda value: 0 if value < threshold else min(255, int((value - threshold) * 2.2)))


def shadow_mask(rgb: Image.Image, cutoff: int, softness: int = 54) -> Image.Image:
    luminance = ImageOps.grayscale(rgb)
    return luminance.point(
        lambda value: 0
        if value >= cutoff
        else min(255, int((cutoff - value) * 255 / max(1, softness)))
    )


def alpha_inner_edge(alpha: Image.Image, radius: int) -> Image.Image:
    kernel = max(3, radius * 2 + 1)
    eroded = alpha.filter(ImageFilter.MinFilter(kernel))
    return ImageChops.subtract(alpha, eroded)


def ink_image(source: Path, destination: Path, preset_name: str | None = None) -> None:
    original = Image.open(source).convert("RGBA")
    rgb = original.convert("RGB")
    alpha = original.getchannel("A")
    preset = PRESETS[preset_name or classify(source)]
    width, height = original.size
    scale = max(1, round(min(width, height) / 512))

    graded = color_grade(rgb, preset).convert("RGBA")
    graded.putalpha(alpha)

    edge_mask = internal_edge_mask(rgb, preset.edge_threshold)
    edge_mask = ImageChops.multiply(edge_mask, alpha)
    edge_mask = edge_mask.point(lambda value: int(value * preset.edge_strength))

    boundary = alpha_inner_edge(alpha, max(1, 2 * scale))
    edge_mask = ImageChops.lighter(edge_mask, boundary.point(lambda value: int(value * 0.92)))

    spacing = max(9, round(min(width, height) / 42))
    hatch = diagonal_pattern((width, height), spacing, opposite=False)
    deep_hatch = diagonal_pattern((width, height), spacing + max(3, spacing // 3), opposite=True)
    shadows = shadow_mask(rgb, cutoff=112)
    deepest = shadow_mask(rgb, cutoff=70, softness=38)
    hatch_mask = ImageChops.multiply(hatch, shadows)
    hatch_mask = ImageChops.lighter(
        hatch_mask,
        ImageChops.multiply(deep_hatch, deepest).point(lambda value: int(value * 0.72)),
    )
    hatch_mask = ImageChops.multiply(hatch_mask, alpha)
    hatch_mask = hatch_mask.point(lambda value: int(value * preset.hatch_strength))

    grit = make_grit((width, height), stable_seed(source), density=0.0016)
    grit = ImageChops.multiply(grit, shadow_mask(rgb, cutoff=155, softness=80))
    grit = ImageChops.multiply(grit, alpha)
    grit = grit.point(lambda value: int(value * preset.grit_strength))

    ink = Image.new("RGBA", original.size, (5, 7, 10, 255))
    treated = Image.composite(ink, graded, edge_mask)
    treated = Image.composite(ink, treated, hatch_mask)
    treated = Image.composite(ink, treated, grit)
    treated.putalpha(alpha)

    destination.parent.mkdir(parents=True, exist_ok=True)
    if alpha.getextrema() == (255, 255):
        treated.convert("RGB").save(destination, optimize=True)
    else:
        treated.save(destination, optimize=True)


def iter_assets(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*.png")
        if "ArtArchive" not in path.parts
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--preset", choices=sorted(PRESETS))
    parser.add_argument("--in-place", action="store_true")
    args = parser.parse_args()

    if args.source.is_dir():
        if not args.in_place and args.out is None:
            parser.error("directory conversion requires --in-place or --out")
        for source in iter_assets(args.source):
            destination = source if args.in_place else args.out / source.relative_to(args.source)
            ink_image(source, destination, args.preset)
            print(destination)
        return

    destination = args.source if args.in_place else args.out
    if destination is None:
        parser.error("file conversion requires --in-place or --out")
    ink_image(args.source, destination, args.preset)
    print(destination)


if __name__ == "__main__":
    main()
