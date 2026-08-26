"""Turn data/rift.json biome definitions into concrete art briefs.

    py tools/art/rift_biome_prompts.py            # writes docs/art_briefs/*.md

Every biome's climate ranges (heat/light/wet/depth, 0..3) become palette and
lighting language, so the art direction is DERIVED from the same numbers the
compatibility formula runs on -- a biome cannot drift into looking like
something it is not allowed to mix with. The output is one brief per biome:
the exact file list the game expects (matching ground.gd's naming), and one
finished prompt per asset, ready for tools/art/rift_generate.py or for
pasting into any image tool by hand.

No dependencies; runs on bare Python. Deterministic: same rift.json, same
briefs, so the briefs are diffable and belong in git.
"""

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DATA = REPO / "data" / "rift.json"
OUT = REPO / "docs" / "art_briefs"

# The shared constraints every tile prompt carries. 32px, top-down, seamless,
# and in the game's established register.
BASE_STYLE = (
    "32x32 pixel art terrain tile, strict top-down view, seamless and "
    "tileable on all four edges, no border, no vignette, chunky pixels, "
    "dark-fantasy arcade palette, muted background detail that reads as "
    "texture rather than objects, consistent with retro 16-bit game art"
)

PROP_STYLE = (
    "32x32 pixel art game prop on a fully transparent background, single "
    "object, strict top-down-oblique view as in classic 16-bit RPGs, chunky "
    "pixels, dark outline with a violet bias (#120d18), light from the upper "
    "left, dark-fantasy arcade palette"
)

HEAT = {
    0: "frozen; blue-shifted shadows, frost in every crack",
    1: "cool; muted temperature, grey-blue undertones",
    2: "warm; earthy midtones, faint amber undertones",
    3: "molten; incandescent orange-white fissures, heat-blackened rock",
}
LIGHT = {
    0: "abyssal; almost unlit, forms read by rim light only",
    1: "dim; twilight values, deep shadows",
    2: "lit; even readable illumination",
    3: "radiant; overexposed highlights, bleached tops, hard tiny shadows",
}
WET = {
    0: "bone dry; dust, cracks, nothing reflective",
    1: "damp; darkened patches, occasional glisten",
    2: "soaked; standing puddles, wet-edge highlights",
    3: "submerged; everything under a shallow water layer, caustic ripples",
}
DEPTH = {
    0: "open to sky or void; hard directional light, long sightlines",
    1: "surface; natural horizon lighting",
    2: "underground; enclosed, light sources are local and scarce",
    3: "abyssal; crushing dark, bioluminescent accents only",
}

# What the three ground.gd terrain slots mean for each biome, plus four props.
# Slots map onto LEVEL_TERRAIN's grass/mud/stone keys in that order.
BIOME_KIT = {
    "lava_fields": {
        "depth": 1,
        "slots": ["cooled basalt crust", "cracked slag with glowing seams", "raw molten crust, incandescent"],
        "props": ["obsidian spire", "half-sunk charred ribcage", "vent chimney leaking smoke", "cooled lava boulder"],
    },
    "forest": {
        "slots": ["mossy forest floor", "root-laced dark earth", "lichen-covered stone"],
        "props": ["gnarled tree stump", "giant luminous mushroom", "fallen mossy log", "stone waymarker overgrown with vines"],
    },
    "ocean": {
        "slots": ["wet tidal sand", "shallow standing water over sand", "barnacled wet rock"],
        "props": ["beached ancient anchor", "cluster of coral", "half-buried ship rib", "tide pool with faint glow"],
    },
    "caves": {
        "depth": 2,
        "slots": ["smooth cave floor", "gravel and rubble floor", "ridged flowstone"],
        "props": ["stalagmite cluster", "glowing crystal outcrop", "collapsed mine support", "underground pool rim"],
    },
    "luminous_plains": {
        "slots": ["bleached radiant grass", "sun-cracked pale clay", "white sunstruck stone"],
        "props": ["obelisk casting a hard tiny shadow", "field of white flowers", "bleached animal skull, large", "shimmering heat-mirage stone ring"],
    },
}


def midpoint(rng):
    return round((int(rng[0]) + int(rng[1])) / 2)


def climate_language(axes, depth_override=None):
    # A range says where a biome CAN live; the brief wants where it PRESENTS.
    # Lava spans depth [1,2] (surface flows and magma tubes) but presents as a
    # surface; caves span the same interval and present underground. The kit
    # may pin presentation depth; every other axis presents at its midpoint.
    depth = midpoint(axes["depth"]) if depth_override is None else depth_override
    return "; ".join([
        HEAT[midpoint(axes["heat"])],
        LIGHT[midpoint(axes["light"])],
        WET[midpoint(axes["wet"])],
        DEPTH[depth],
    ])


def tile_prompt(biome, slot_desc, climate):
    return (
        f"{BASE_STYLE}. Terrain: {slot_desc}, in the biome '{biome['name']}' "
        f"({biome['blurb']}). Climate: {climate}."
    )


def prop_prompt(biome, prop_desc, climate):
    return (
        f"{PROP_STYLE}. Object: {prop_desc}, belonging to the biome "
        f"'{biome['name']}' ({biome['blurb']}). Climate: {climate}."
    )


def brief_for(biome):
    bid = biome["id"]
    kit = BIOME_KIT.get(bid)
    if kit is None:
        return None
    climate = climate_language(biome["axes"], kit.get("depth"))
    lines = [
        f"# Art brief — {biome['name']} (`{bid}`)",
        "",
        f"> {biome['blurb']}",
        "",
        f"Axes: heat {biome['axes']['heat']}  light {biome['axes']['light']}  "
        f"wet {biome['axes']['wet']}  depth {biome['axes']['depth']}",
        "",
        f"Climate language (derived): {climate}",
        "",
        "Generated by tools/art/rift_biome_prompts.py from data/rift.json —",
        "edit the data or the generator, not this file.",
        "",
        "## Terrain tiles (2 variants x 3 slots, matching ground.gd)",
        "",
    ]
    slot_keys = ["grass", "mud", "stone"]
    for key, desc in zip(slot_keys, kit["slots"]):
        for variant in ("a", "b"):
            fname = f"tile_{bid}_{key}_{variant}_32_v001.png"
            lines += [f"### `{fname}`", "", "```", tile_prompt(biome, desc, climate), "```", ""]
    lines += ["## Props (32px, transparent background)", ""]
    for i, desc in enumerate(kit["props"], 1):
        fname = f"prop_{bid}_{i:02d}_32_v001.png"
        lines += [f"### `{fname}`", "", "```", prop_prompt(biome, desc, climate), "```", ""]
    return "\n".join(lines)


def main():
    data = json.loads(DATA.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for biome in data.get("biomes", []):
        brief = brief_for(biome)
        if brief is None:
            continue
        path = OUT / f"{biome['id']}.md"
        path.write_text(brief, encoding="utf-8", newline="\n")
        written.append(path.name)
    index = ["# Art briefs", "", "One per unwired biome, derived from data/rift.json.", ""]
    index += [f"- [{n}]({n})" for n in sorted(written)]
    (OUT / "README.md").write_text("\n".join(index) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(written)} briefs to {OUT}")


if __name__ == "__main__":
    main()
