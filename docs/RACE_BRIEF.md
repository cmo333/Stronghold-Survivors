# Race brief — the capture format

How to get a race out of your head and into the game with the fewest round
trips. Dump ideas in **any order, any format** — voice-note prose is fine. This
document is the shape they get slotted into, not a form you have to fill in.

Filled-in example first (Corporate), blank template after.

---

## Why towers carry the world

The single most useful measurement taken so far:

| tower | reach, tier 1 → 3 |
|---|---|
| arrow turret | 6.4 → 9.6 tiles |
| cannon tower | 6.1 → 7.7 |
| tesla tower | 5.8 → 7.4 |
| spike burst | 5.1 → 5.9 |
| flamethrower | 5.3 → 6.1 |

**Every tower in the game reaches between 5 and 10 tiles.** They differ by
damage numbers, not by how much space they own. That is the whole reason they
read as interchangeable, and it is why "towers give the world its identity" is
the right instinct: identity comes from **shape, reach and cadence**, not stats.

A 2-tile tentacle and a 3-tile flame jet would be the first towers in this game
that occupy space differently from each other. That difference is the design.

**So the first three questions about any tower are:**

1. **What shape does the attack have?** (radius / cone / line / lobbed / chain /
   spawns a unit / persistent ground / aura)
2. **How far, in TILES?** The build grid is 32px, so 1 tile = 32px. Think in
   tiles — the code should too, and does not yet.
3. **What cadence?** (continuous stream / per-shot / burst / periodic timer /
   always-on)

Flavour, name and art come after those three, because those three are what the
player actually feels.

---

## What the engine can already express

Worth knowing before designing, so ideas land as tuning rather than as new
systems:

| shape | status | where |
|---|---|---|
| projectile, pierces N bodies | **exists** | `arrow_turret` |
| radius splash + ground burn pools | **exists** | `cannon_tower` |
| chain lightning to N targets | **exists** | `tesla_tower` |
| **cone with tunable angle** | **exists** | `flamethrower_tower` (`flame_cone_deg`, `_apply_cone_damage`) |
| persistent ground AoE | **exists** | hellfire pools, storm field |
| spawns allied units that chase | **exists** | `shrine` / Stargate, `ally.gd` |
| unit tint / recolour by config | **exists** | `ally.gd` `tint` |
| **range expressed in tiles** | **missing** | everything is raw pixels |
| **spawned unit that flies a pattern** | **missing** | allies chase, they do not patrol |
| **timed map-wide sweep** | **missing** | no precedent |
| **very short reach as an identity** (1–3 tiles) | **missing** | nothing is under 5 tiles |

So of the three Corporate towers described so far: the tentacle is buildable
today, the flame jet is a re-tune of a cone that already exists, and the airport
is genuinely new code. That is a healthy ratio.

---

## FILLED EXAMPLE — Corporate

### Identity

- **Name:** Corporate
- **Register:** cyberpunk. Chrome, wet neon, corporate signage.
- **How they reached the Rift:** manipulated cybernetics far enough to tap the
  consciousness of the world, and found the Rift inside it. They did not travel
  to it. They *noticed* it, and then monetised the noticing.
- **What this means about them:** the Rift is an asset class. Everything they
  build is instrumented, branded and depreciating.

### Visual language

- **This is the race the game already looks like.** The existing pixel art, the
  graveyard, the current tower set — all of it is the Corporate lens. Nothing
  built so far is thrown away; it is contextualised.
- *(to fill: palette, silhouette rules, FX vocabulary, UI frame, music register)*

### Towers

**Tentacle Node**
- Shape: radius splash, centred on the tower
- Reach: **2 tiles** fully upgraded (the shortest thing in the game by 3x)
- Cadence: continuous grabs
- Identity: metallic tentacles. Heavy splash to pay for the terrible reach —
  it is a blender you have to lure things into, not a turret.
- Engine: buildable today (`damage_enemies_in_radius` at 64px). The identity is
  in the animation and the conspicuously short ring.

**Flame Jet**
- Shape: cone, narrow
- Reach: **3 tiles** in a line
- Cadence: continuous stream
- Effects: heavy fire damage, applies burn damage-over-time
- Engine: `flamethrower_tower` already has a tunable cone. This is a re-tune
  plus a burn hookup, not new code.

**Airport**
- Shape: spawns aerial drones that beam **straight down** beneath themselves
- Reach: the drone's flight covers ground the tower does not
- Cadence: drones persist; behaviour per pattern
- **Open question:** player-chosen flight pattern (Bloons-style) versus drones
  that auto-seek enemies. Second thought was auto-seek. *Pattern selection is a
  UI feature and a control surface; auto-seek is a targeting change. Auto-seek
  first is cheaper and provable, pattern selection can come after if the drones
  earn it.*
- **Fully upgraded (expensive):** bombers that run a sweep every 30 seconds
- Engine: genuinely new — allies chase, they do not patrol, and nothing does a
  timed map-wide sweep

### Still needed for Corporate

- What are they *bad* at? (a race that is only good at things is a reskin)
- Palette / FX vocabulary / music register
- Death fragments: what does a Corporate corpse tell the next runner?

---

## BLANK TEMPLATE — one per race

### Identity
- **Name:**
- **Register:** (one line — the genre or feeling)
- **How they reached the Rift:** (this becomes the arrival text pool, so more
  than one version of the story is useful)
- **What this means about them:** (the attitude that explains their tech)

### Visual language
- **Palette:**
- **Silhouette rule:** (what shape reads as "them" at 32px)
- **FX vocabulary:** (what their damage looks like — sparks? spores? light?)
- **Music register:**

### Towers — 3 to 5, each answering shape / reach / cadence first
- **Name:**
  - Shape:
  - Reach (tiles):
  - Cadence:
  - Effects / status:
  - What upgrading changes: (reach? shape? adds a mechanic? — changing the
    *shape* on upgrade is more interesting than changing the number)
  - Identity in one line:

### Balance shape
- **Good at:**
- **Bad at:** (required — this is what stops races being reskins)

### Lore
- Death fragments: 3–5 lines a dead runner of this race would leave behind

---

## How to dump

Do not fill this in as a form. Say it however it comes out — the Corporate
section above was written from one paragraph of stream-of-consciousness and a
list of three towers. What makes it cheap to absorb is answering **shape, reach
in tiles, and cadence** somewhere in the telling. Everything else can be vague
and get sharpened later.

If an idea needs a system that does not exist yet, say it anyway — the table
above exists so the cost is visible, not so ideas get filtered.
