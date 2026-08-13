# AGENTS.md — Gutshot

## What this project is

Real-time tactical squad shooter, isometric view, Godot 4. Squads of 4-6 characters in a
grimdark cyberpunk hive-city setting. Gear items define abilities. Campaign + procedural
missions. No destructible buildings in v1.

## Workspace layout

```
gutshot/
  docs/          Source of truth — architecture, plan, narrative, tasks
  scenes/        Godot scenes (.tscn)
  scripts/       GDScript (.gd)
  resources/     Godot Resources (.tres) — gear, abilities, objectives
  assets/        Art, audio, shaders
```

## Key conventions

- **GDScript** for all game logic.
- **GDExtension** only for perf-critical paths (pathfinding hot loops, heavy simulation).
- **docs/architecture.md** is authoritative for system design — read it before adding a new system.
- **docs/tasks.md** is the active task list — check it before starting work.
- Scene hierarchy: `GameWorld → Squad → Character`. Do not flatten this without updating architecture.md.
- Abilities are defined as `Resource` subclasses on gear items, not hardcoded on characters.
- No destructible buildings in v1 — do not add that system.

## Coding agent guidance

1. Check `docs/architecture.md` before adding any new system or scene structure.
2. New gear/ability types go in `resources/` as `.tres` files backed by a typed Resource script.
3. Keep scenes focused — one scene per logical unit (Character, Room, Squad, etc.).
4. Prefer signals over direct node references for cross-system communication.
