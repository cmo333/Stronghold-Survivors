# Project

## Summary
Stronghold Survivors is a top-down survival defense game where progression is driven by building and upgrading a fortress in real time.

## Goals
- Scaffold the core loop: move, auto-attack, spawn, loot, build.
- Make upgrades feel loud, visible, and mechanical.
- Deliver a strong first-impression slice focused on maze building + siege pressure.

## Scope
- In scope:
- Godot 4.x prototype.
- Data-driven structure stats.
- Open map with freeform placement.
- Clear upgrade feedback and readable combat.
- Out of scope:
- Final art, full tech trees, meta progression.

## Decisions
- Godot 4.2 target.
- JSON-driven structure definitions.
- Placeholder shapes for rapid iteration.
- XP tech picks (choose 1 of 3), run-only progression.

## Philosophy (v2)
- Clarity first: screen readability beats density.
- Visible power: upgrades must change behavior or visuals.
- Rarity = impact: rare tiers are always more unique and stronger.
- Cohesion > content: fewer, tighter systems win.
- Tension preserved: power spikes without trivializing.
- Flow over friction: pickups support movement.
- Performance budgeted: hard caps on effects and projectiles.

## North Star (v2)
- By minute 5, you have shaped the map.
- By minute 15, the fortress is alive.
- The maze is your weapon; the gun is your lifeline.

## Status
- Prototype scaffolded with core systems.
