#!/usr/bin/env python3
"""
Stronghold Survivors - Windows 4090 sprite/FX alpha batch pipeline.

Pipeline:
1) Optional external BiRefNet run (command template).
2) Build luma-derived alpha from source frame.
3) Merge alpha = max(biref_alpha, luma_alpha).
4) Optional downscale + palette reduction.
5) Export processed PNG sequence (+ optional sprite sheet).
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
from pathlib import Path
from typing import Iterable, List, Optional

from PIL import Image, ImageChops


VALID_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}


def natural_key(path: Path) -> List[object]:
    parts = re.split(r"(\d+)", path.name.lower())
    key: List[object] = []
    for p in parts:
        if p.isdigit():
            key.append(int(p))
        else:
            key.append(p)
    return key


def list_frames(folder: Path) -> List[Path]:
    return sorted(
        [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in VALID_EXTS],
        key=natural_key,
    )


def resolve_alpha_frame(biref_dir: Path, source_frame: Path) -> Optional[Path]:
    exact = biref_dir / source_frame.name
    if exact.exists():
        return exact
    stem = source_frame.stem
    for ext in [".png", ".webp", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"]:
        candidate = biref_dir / f"{stem}{ext}"
        if candidate.exists():
            return candidate
    return None


def alpha_from_image(img: Image.Image) -> Image.Image:
    if img.mode in ("RGBA", "LA"):
        return img.getchannel("A").convert("L")
    return img.convert("L")


def luma_alpha(
    src_rgb: Image.Image,
    threshold: int,
    gamma: float,
    gain: float,
) -> Image.Image:
    gray = src_rgb.convert("L")
    threshold = max(0, min(254, threshold))
    gamma = max(0.01, gamma)
    gain = max(0.01, gain)

    inv = float(255 - threshold)

    def curve(px: int) -> int:
        if px <= threshold:
            return 0
        normalized = (float(px) - float(threshold)) / inv
        mapped = pow(normalized, gamma) * 255.0 * gain
        return int(max(0.0, min(255.0, mapped)))

    return gray.point(curve, mode="L")


def palette_reduce(img: Image.Image, colors: int) -> Image.Image:
    colors = max(2, min(256, colors))
    pal = img.convert("RGBA").quantize(colors=colors, method=Image.MEDIANCUT)
    return pal.convert("RGBA")


def make_sheet(frames: List[Path], output_path: Path, cols: int) -> None:
    if not frames:
        return
    first = Image.open(frames[0]).convert("RGBA")
    fw, fh = first.size
    count = len(frames)
    cols = max(1, cols)
    rows = int(math.ceil(float(count) / float(cols)))

    sheet = Image.new("RGBA", (fw * cols, fh * rows), (0, 0, 0, 0))
    for i, frame_path in enumerate(frames):
        img = Image.open(frame_path).convert("RGBA")
        x = (i % cols) * fw
        y = (i // cols) * fh
        sheet.paste(img, (x, y))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def run() -> int:
    parser = argparse.ArgumentParser(description="BiRefNet + luma alpha batch for tower/FX frames.")
    parser.add_argument("--input", required=True, type=Path, help="Source frame directory.")
    parser.add_argument("--output", required=True, type=Path, help="Processed output frame directory.")
    parser.add_argument(
        "--biref-dir",
        type=Path,
        default=None,
        help="Directory containing BiRefNet alpha/matte outputs.",
    )
    parser.add_argument(
        "--run-birefnet-cmd",
        type=str,
        default="",
        help='Optional command template. Supports {input} and {output}. Example: "python inference.py --input {input} --output {output}"',
    )
    parser.add_argument("--luma-threshold", type=int, default=22, help="0-254 threshold for luma alpha.")
    parser.add_argument("--luma-gamma", type=float, default=1.15, help="Gamma curve for luma alpha.")
    parser.add_argument("--luma-gain", type=float, default=1.2, help="Gain multiplier for luma alpha.")
    parser.add_argument("--downscale", type=int, default=1, help="Integer downscale factor. 1 = unchanged.")
    parser.add_argument("--palette-colors", type=int, default=0, help="0 disables palette reduction.")
    parser.add_argument("--sheet-cols", type=int, default=0, help="If > 0, also export sprite sheet with this column count.")
    parser.add_argument("--sheet-output", type=Path, default=None, help="Optional sprite sheet output path.")

    args = parser.parse_args()

    source_dir: Path = args.input
    output_dir: Path = args.output
    source_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    frames = list_frames(source_dir)
    if not frames:
        raise SystemExit(f"No source frames found in: {source_dir}")

    biref_dir = args.biref_dir
    if args.run_birefnet_cmd.strip():
        if biref_dir is None:
            biref_dir = output_dir / "_biref_alpha"
        biref_dir.mkdir(parents=True, exist_ok=True)
        cmd = args.run_birefnet_cmd.format(input=str(source_dir), output=str(biref_dir))
        subprocess.run(cmd, shell=True, check=True)

    processed: List[Path] = []
    report = {
        "source_dir": str(source_dir),
        "output_dir": str(output_dir),
        "biref_dir": str(biref_dir) if biref_dir else None,
        "luma_threshold": args.luma_threshold,
        "luma_gamma": args.luma_gamma,
        "luma_gain": args.luma_gain,
        "downscale": args.downscale,
        "palette_colors": args.palette_colors,
        "processed_frames": [],
        "missing_biref_frames": [],
    }

    for source in frames:
        src_rgba = Image.open(source).convert("RGBA")
        luma = luma_alpha(src_rgba.convert("RGB"), args.luma_threshold, args.luma_gamma, args.luma_gain)

        biref_alpha = Image.new("L", src_rgba.size, 0)
        if biref_dir is not None:
            alpha_frame = resolve_alpha_frame(biref_dir, source)
            if alpha_frame is not None:
                matte_img = Image.open(alpha_frame)
                biref_alpha = alpha_from_image(matte_img).resize(src_rgba.size, Image.BILINEAR)
            else:
                report["missing_biref_frames"].append(source.name)

        final_alpha = ImageChops.lighter(biref_alpha, luma)
        out = src_rgba.copy()
        out.putalpha(final_alpha)

        if args.downscale > 1:
            w, h = out.size
            out = out.resize((max(1, w // args.downscale), max(1, h // args.downscale)), Image.NEAREST)

        if args.palette_colors and args.palette_colors > 0:
            out = palette_reduce(out, args.palette_colors)

        out_path = output_dir / f"{source.stem}.png"
        out.save(out_path)
        processed.append(out_path)
        report["processed_frames"].append(out_path.name)

    if args.sheet_cols > 0:
        if args.sheet_output is None:
            sheet_path = output_dir / "sheet.png"
        else:
            sheet_path = args.sheet_output
        make_sheet(processed, sheet_path, args.sheet_cols)
        report["sheet_output"] = str(sheet_path)
        report["sheet_cols"] = args.sheet_cols

    report_path = output_dir / "batch_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Processed {len(processed)} frames to {output_dir}")
    print(f"Report: {report_path}")
    if report["missing_biref_frames"]:
        print(f"Missing BiRefNet frames: {len(report['missing_biref_frames'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
