"""Generate biome art through a paid image API, from the derived briefs.

    set OPENAI_API_KEY=sk-...           (PowerShell: $env:OPENAI_API_KEY="sk-...")
    py -m pip install pillow
    py tools/art/rift_generate.py lava_fields          # one biome
    py tools/art/rift_generate.py --all                # every briefed biome
    py tools/art/rift_generate.py lava_fields --dry    # print prompts, no calls

Pipeline per asset: ask gpt-image-1 for a 1024x1024 render of the brief's
prompt, then downscale to 32x32 with NEAREST so the result is honest chunky
pixels rather than smoothed mush. Output lands in assets/gen/<biome>/ --
deliberately NOT in the shipped asset folders. Promotion into the game
(ground.gd LEVEL_TERRAIN + flipping the biome's `wired` flag in rift.json)
stays a reviewed, human step: generated art gets looked at before the roll
is allowed to build a world out of it.

The prompts come from the same code path as the written briefs
(rift_biome_prompts.py), so what you read in docs/art_briefs/ is exactly
what gets sent.
"""

import base64
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
import rift_biome_prompts as briefs  # noqa: E402

API_URL = "https://api.openai.com/v1/images/generations"
MODEL = "gpt-image-1"


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(2)


def assets_for(biome):
    """(filename, prompt, transparent) for every asset in the biome's kit."""
    kit = briefs.BIOME_KIT.get(biome["id"])
    if kit is None:
        return []
    climate = briefs.climate_language(biome["axes"], kit.get("depth"))
    out = []
    for key, desc in zip(["grass", "mud", "stone"], kit["slots"]):
        for variant in ("a", "b"):
            fname = f"tile_{biome['id']}_{key}_{variant}_32_v001.png"
            out.append((fname, briefs.tile_prompt(biome, desc, climate), False))
    for i, desc in enumerate(kit["props"], 1):
        fname = f"prop_{biome['id']}_{i:02d}_32_v001.png"
        out.append((fname, briefs.prop_prompt(biome, desc, climate), True))
    return out


def generate(prompt, api_key, transparent):
    body = {
        "model": MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "n": 1,
    }
    if transparent:
        body["background"] = "transparent"
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        payload = json.loads(resp.read())
    return base64.b64decode(payload["data"][0]["b64_json"])


def downscale_to_32(png_bytes, out_path):
    from PIL import Image
    import io
    img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    img.resize((32, 32), Image.NEAREST).save(out_path)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv
    do_all = "--all" in sys.argv
    data = json.loads(briefs.DATA.read_text(encoding="utf-8"))
    biomes = [b for b in data.get("biomes", []) if b["id"] in briefs.BIOME_KIT]
    if not do_all:
        if not args:
            die(f"name a biome ({', '.join(sorted(briefs.BIOME_KIT))}) or pass --all")
        biomes = [b for b in biomes if b["id"] in args]
        if not biomes:
            die(f"no briefed biome named {args}")

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not dry:
        if not api_key:
            die("OPENAI_API_KEY is not set (use --dry to preview prompts without it)")
        try:
            import PIL  # noqa: F401
        except ImportError:
            die("Pillow is required for the 32px downscale: py -m pip install pillow")

    for biome in biomes:
        out_dir = briefs.REPO / "assets" / "gen" / biome["id"]
        for fname, prompt, transparent in assets_for(biome):
            if dry:
                print(f"--- {fname}\n{prompt}\n")
                continue
            out_dir.mkdir(parents=True, exist_ok=True)
            target = out_dir / fname
            if target.exists():
                print(f"skip (exists): {target.relative_to(briefs.REPO)}")
                continue
            print(f"generating {fname} ...")
            png = generate(prompt, api_key, transparent)
            downscale_to_32(png, target)
            print(f"  -> {target.relative_to(briefs.REPO)}")


if __name__ == "__main__":
    main()
