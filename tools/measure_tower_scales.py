#!/usr/bin/env python3
"""Recompute per-tier tower sprite scales so every tower reads at the same size.

Towers use baked 8-direction art whose source images differ enormously — arrow
content is ~988x1147px while cannon is ~347x385. A shared scale value therefore
does NOT produce a shared on-screen size, and because each tower's art grows by
a different amount between tiers, a shared growth rate drifts apart on upgrade.

This measures the opaque bounds of every frame, takes the arrow turret as the
reference, and prints the scale each other tower needs per tier to match its
rendered silhouette height.

Usage:
    pip install pillow
    python3 tools/measure_tower_scales.py

Paste the printed arrays into DIRECTIONAL_BODY_SCALE_BY_TIER in
scripts/cannon_tower.gd and scripts/tesla_tower.gd.
"""
import glob
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow required:  pip install pillow")

ART_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "level1", "towers_directional")

REFERENCE = "arrow"
REFERENCE_BASE_SCALE = 0.070      # arrow_turret.gd DIRECTIONAL_BODY_SCALE
REFERENCE_TIER_GROWTH = 0.12      # arrow_turret.gd per-tier growth
TOWERS = ["arrow", "cannon", "tesla"]
TIERS = ["t1", "t2"]              # T3 reuses T2 art, scaled one step further


def max_content(tower: str, tier: str):
    """Largest opaque bounding box across all 8 headings for one tier."""
    widths, heights = [], []
    for path in glob.glob(os.path.join(ART_DIR, f"{tower}_{tier}_*.png")):
        alpha = Image.open(path).convert("RGBA").split()[3]
        bbox = alpha.getbbox()
        if bbox is None:
            continue
        widths.append(bbox[2] - bbox[0])
        heights.append(bbox[3] - bbox[1])
    if not widths:
        return None
    return max(widths), max(heights)


def main():
    ref = {t: max_content(REFERENCE, t) for t in TIERS}
    if any(v is None for v in ref.values()):
        sys.exit(f"Missing reference art for '{REFERENCE}' in {ART_DIR}")

    # Rendered height the reference occupies at each tier.
    targets = [
        ref["t1"][1] * REFERENCE_BASE_SCALE,
        ref["t2"][1] * REFERENCE_BASE_SCALE * (1 + REFERENCE_TIER_GROWTH),
        ref["t2"][1] * REFERENCE_BASE_SCALE * (1 + 2 * REFERENCE_TIER_GROWTH),
    ]
    print(f"Reference ({REFERENCE}) rendered height per tier: "
          f"{targets[0]:.1f} / {targets[1]:.1f} / {targets[2]:.1f} px\n")

    for tower in TOWERS:
        if tower == REFERENCE:
            continue
        t1, t2 = max_content(tower, "t1"), max_content(tower, "t2")
        if t1 is None or t2 is None:
            print(f"{tower}: missing art, skipped")
            continue
        src_heights = [t1[1], t2[1], t2[1]]
        scales = [targets[i] / src_heights[i] for i in range(3)]
        widths = [(t1[0], t2[0], t2[0])[i] * scales[i] for i in range(3)]
        print(f"{tower}:")
        print(f"  const DIRECTIONAL_BODY_SCALE_BY_TIER := "
              f"[{scales[0]:.4f}, {scales[1]:.4f}, {scales[2]:.4f}]")
        print(f"  -> renders {widths[0]:.0f}/{widths[1]:.0f}/{widths[2]:.0f} px wide "
              f"at matched heights\n")


if __name__ == "__main__":
    main()
