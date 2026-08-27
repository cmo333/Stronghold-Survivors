# North Star

> Rewritten 2026-08-16. The previous version described a game that no longer
> exists — it had you crash-landing on a planet and relocating zone-to-zone as
> it pushed back. Relocation was cut (the "RELOCATE!" banner instructed an
> action the game never implemented), the run became a single siege, and the
> fixed hero roster is now being replaced outright. What follows is the
> direction, not a description of the current build.

## Vision

**AVARICE is a roguelite about the Rift, told from a different mouth every time
you load it.**

The Rift is the plane the game is played on. It can be reached from anywhere —
another era, another point in space, another branch of the multiverse — and
every run opens by telling you how *this* arrival happened. You do not choose a
hero. You are rolled: a race, a body, a set of numbers, and the towers that race
knows how to build. Then you hold ground, and the way you hold it looks nothing
like the last run did.

## Core fantasy

You are not the same person twice. You are whatever the Rift pulled in this
time, working with whatever that culture understands about defending a place.
The world is assembled from what previous arrivals left behind, and you add to
it by dying.

## What a run is

A run is a **rolled object**, not a menu of choices:

- **an origin** — how you reached the Rift, narrated on arrival
- **a race** — appearance, stats, and the tower vocabulary you are limited to
- **a region** — the ground you hold, procedurally generated
- **modifiers** — what makes this particular place strange

Everything downstream reads from that roll. Two runs with the same seed are the
same run; that is a design requirement, not a nice-to-have, because it is the
only way procedural content stays testable in a project that measures instead
of assuming.

## Towers carry the world

**This is the pillar the rest hangs off.** A race is not a palette on the same
five turrets — it is a different theory of how to stop something from reaching
you, and the player reads that theory off the towers.

Identity comes from **shape, reach and cadence**, never from damage numbers:

- what shape the attack has — radius, cone, line, chain, lobbed, spawned unit,
  persistent ground, aura
- **how far, in tiles** (the build grid is 32px, so think and write in tiles)
- what cadence — continuous stream, per-shot, burst, periodic timer

The measurement that proves this matters: today every tower in the game reaches
between **5.1 and 9.6 tiles**. They differ by stats and by nothing a player can
see from across the map, which is exactly why they feel interchangeable. A
2-tile tentacle that blends whatever it can grab and a 3-tile flame jet that
cooks a corridor are two different games. That spread *is* the identity.

Capture format for new races and towers: `docs/RACE_BRIEF.md`.

## The world composes

Regions, enemies and bosses share one climate space (heat, light, wet, depth;
`docs/WORLD_FORMULA.md`). A region is a rolled primary biome plus compatible
accents — lava can host caves but never forest, forests take oceans and light,
the salvage deck mixes with nothing organic. Enemies belong where their ranges
overlap the world; **the boss is rolled from what the world could NOT have
produced**, so it reads as an intruder — distinct because it does not fit.

## The first race is the game you already have

**Corporate** — cyberpunk, chrome and wet neon — reached the Rift by pushing
cybernetics far enough to tap the consciousness of the world, and found it
inside. They did not travel to it. They noticed it, and monetised the noticing.

Everything built so far is the Corporate lens: the pixel art, the graveyard, the
current tower set. Nothing is superseded by this direction — it is
contextualised. The existing game becomes one faction's way of seeing the Rift
rather than the whole of it.

## Meaning is earned, not delivered

Lore arrives through **death**. Each loss leaves a fragment — what that runner
learned, saw, or got wrong — and the world assembles out of accumulated
fragments across many runs. The reference point is *Expedition 33*: you inherit
the memories of parties that failed before you, and the world gets larger every
time you lose.

This is the piece that makes the roguelite structure mean something rather than
just repeat.

## Pillars

- **Towers are the voice of a culture.** Shape and reach before stats.
- **Every load is a different story.** The arrival is narrated, not skipped.
- **You are dealt a hand, not given a menu.** Rolled, not chosen.
- **Dying grows the world.** Fragments accumulate.
- **Readable chaos.** Swarms are enormous, decisions stay clear.
- **Visible power.** Towers and FX must be loud enough to read at a glance.
- **Tension without cheapness.** You die from choices, not unreadable noise.

## Deliberately deferred

Named so they do not quietly become blockers:

- **A genuinely separate art style per race.** There are already 942 PNGs in one
  style (38% unreferenced), zero music tracks, and 36 synthesized placeholder
  SFX. A second complete visual identity is a full art production. Race variance
  starts as **palette, silhouette rule and FX vocabulary** — that reads as a
  different world at a fraction of the cost. Distinct styles come once a race has
  earned the investment.
- **Player-authored drone flight patterns.** A control surface. Auto-seek first.
- **Multiplayer / FFA.** ~2,000 lines of prototype code threaded through the core
  loop. Frozen, not finished, not removed.

## Non-goals

- Perfect realism.
- Overly complex tech trees.
- Visual noise at the expense of clarity.
- Content that is only reachable by reading a wiki.

## What still holds from before

The combat identity question is unresolved and predates this rewrite: the player
opens at 31.5 DPS against 8–11 for any tier-1 tower, so early on the player *is*
the damage engine while the design says the towers should be. Races make this
easier to answer, not harder — a race can be defined partly by where it sits on
that curve.
