# Gutshot — Architecture

**As-built through Milestone 1** (playable skirmish). Where earlier planning
text and this doc disagree, this doc describes the build. See "M1 As-Built
Notes" and "Known Gaps / Decided-Out" at the bottom.

## Scene Hierarchy

```
GameWorld               (root — manages mission lifecycle, global signals)
  ├── TileMap / Level   (room geometry, navigation mesh baked here)
  ├── Squad             (player squad node — owns 4-6 Character children)
  │     └── Character   (one per crew member)
  ├── EnemySquad        (mirrors Squad structure for AI-controlled units)
  │     └── Character
  ├── ObjectiveManager  (tracks active objectives, emits mission_complete / mission_failed)
  ├── CameraRig         (isometric camera + floor-transition logic)
  └── HUD               (CanvasLayer — health bars, ability slots, squad portraits)
```

`Character` is the reusable unit scene for both player and enemy sides. Side is determined by a
`team` property, not by scene type.

---

## Ability System

Abilities are **not** hardcoded on characters. Instead:

- A `GearItem` is a `Resource` subclass. Each defines 1-2 `Ability` Resources in exported arrays.
- `Ability` is an abstract `Resource` with `activate(caster, target)`, `cooldown`, and `icon`.
- When a character equips a `GearItem`, its abilities are registered into the character's
  `action_slots` array (max 4 slots).
- The HUD reads `action_slots` to display ability buttons.
- New ability types: subclass `Ability`, override `activate()`. No changes to Character or HUD needed.

```
resources/
  gear/       GearItem .tres files
  abilities/  Ability script subclasses (.gd) and any .tres instances
```

---

## Navigation

- Uses **NavigationServer3D** with a baked `NavigationMesh` per floor.
- Characters request paths via `NavigationAgent3D` components.
- Floor transitions (stairs, ladders) use teleport waypoints between per-floor nav meshes.
- Line-of-sight checks: raycasting against a dedicated collision layer (layer 2 = cover/walls).

---

## Isometric Camera

- `CameraRig` is a `Node3D` with a `Camera3D` child angled at ~60 degrees.
- Camera follows the active character or squad centroid.
- Orthographic projection for clean iso look (no perspective distortion).
- Floor transitions: camera smoothly re-targets the new floor's centroid; geometry above the
  active floor is hidden via a `VisibilityNotifier` or manual layer toggle.

---

## Procedural Mission System (Phase 3)

Not implemented yet. Planned approach:

- **Room tiles**: each is a self-contained Godot scene (`.tscn`) with connection ports marked by
  `Marker3D` nodes named `port_north`, `port_south`, etc.
- **Assembler**: a `MissionGenerator` script selects tiles from a palette, snaps them together
  at runtime using port transforms, and bakes navigation.
- **Objectives**: `Objective` is a `Resource` subclass. Types: `ExtractionObjective`,
  `AssassinationObjective`, `DataHeistObjective`, `DefendObjective`. `ObjectiveManager` receives
  an array of Objectives at mission start.

---

## Performance Notes

- Squad scale is small (4-6 player + 8-16 enemies). Node-based architecture is fine — no ECS needed.
- If pathfinding or AI update loops become a bottleneck at larger enemy counts, extract to a
  **GDExtension** module. Do not pre-optimize.
- Heavy particle effects: use `GPUParticles3D`; cull aggressively with visibility ranges.

---

## Key Signals (cross-system)

| Signal | Emitter | Consumers |
|--------|---------|-----------|
| `character_died(character)` | Character | ObjectiveManager, HUD, EnemySquad AI |
| `ability_activated(character, ability)` | Character | HUD (cooldown display) |
| `objective_updated(objective)` | ObjectiveManager | HUD, GameWorld |
| `mission_complete` | ObjectiveManager | GameWorld (trigger end sequence) |
| `mission_failed` | ObjectiveManager | GameWorld |

---

## What Is Explicitly Out of Scope (v1)

- Multiplayer (v2)
- Destructible buildings / terrain deformation
- Physics-driven ragdolls (use death animations)
- Dynamic lighting changes mid-mission (baked lightmaps only)

---

## M1 As-Built Notes

### Control model (user decisions, locked)
- **WASD + mouse aim, run-and-gun.** The active character moves camera-relative
  (`scripts/characters/player_controller.gd`), Doom-snappy (max speed in ~a
  frame, hard stop) — WASD is the ONLY movement, there is no click-to-move.
  **Hold LMB** on an enemy to fire (release stops; the cursor re-picks while
  held so dragging retargets); RMB clears the target.
- **Keys 1/2/3 are weapon slots** (primary / secondary / heavy-or-device), not
  character hotkeys. **Tab cycles the active character**; HUD portraits click.
- **Followers are autonomous**: they trail the leader out of combat and fight
  through the same `CombatBrain` as enemies, leashed to the leader
  (`scripts/characters/squad_follow.gd`).

### Combat model
- **Accuracy per shot** = weapon `base_accuracy` × `moving_accuracy_mult`
  (while the shooter moves) × cover tier × range falloff
  (`scripts/combat/shooter.gd`). There is **no hard range cap** — `fire_range`
  is the optimal range, with hyperbolic falloff beyond it (2× range → half
  accuracy, floored at 5%). Misses render as deflected tracers; hits land
  instantly for hitscan.
- **Return fire is guaranteed**: every shot taken (hit or miss, any distance)
  calls `target.notify_shot_at(shooter)` → the target's controller pins the
  shooter as its threat for `CombatBrain.THREAT_PIN_SECS`, overriding the
  engage-range gate. This is the seed of the future awareness system —
  "they know exactly where the shot came from, for a while".
- **Tiered cover by exposed body** (`scripts/combat/cover.gd`): rays from the
  shooter's muzzle to five body sample points (`CoverPoints` markers on
  character.tscn: head/chest/pelvis/shoulders). Unblocked fraction > 0.75 →
  exposed; 0.25–0.75 → half cover (−50% hit chance); ≤ 0.25 → full cover, no
  shot. Grenades ignore cover on purpose — they're the counterplay.
- **Health model** (`scripts/characters/character.gd`): crew carry a
  regenerating **shield layer** (absorbs damage first; regens
  `SHIELD_REGEN_RATE`/s after `SHIELD_REGEN_DELAY` seconds without taking
  fire). HP underneath never regenerates in-mission. Enemies have no shields.
  At 0 HP crew go **DOWN** instead of dying — a living squadmate standing
  within `REVIVE_RADIUS` for `REVIVE_SECS` brings them back at
  `REVIVE_HP_FRAC` HP with empty shields. All crew down = mission failed
  (nobody left standing to revive). Enemies just die.
- **Shared combat AI** (`scripts/combat/combat_brain.gd`), used by followers
  AND enemies: pick a cover ring point that breaks LOS to the threat → hold →
  pop out and burst → duck back; flank ~90° when no damage lands for a few
  seconds. `scripts/combat/enemy_controller.gd` is a thin aggro/pack wrapper.
- **Movement is manual waypoint-following** over
  `NavigationServer3D.map_get_path` — NavigationAgent3D's per-frame
  next-position oscillated when driven with velocity + move_and_slide.

### Runtime navmesh
`scripts/world/nav_runtime.gd` bakes from static colliders in the
`navigation_mesh_source_group` group and registers the mesh via a
**server-level region** — on 4.7.1 an in-place `bake_navigation_mesh()` does
not reliably push polygons into the map through the NavigationRegion3D node.

### Asset pipeline (wayfarer lineage)
- `fetch_assets.sh` used-only closure fetch from the asset server
  (`ASSET_SERVER` env override). Reference forms: full `res://assets/meshes/…`
  or `res://assets/ui/…` literals anywhere (UI paths map to the server's raw
  tree), `_ANIM_ROOT + "…"` in character_animator.gd, dir-const+basename
  pairs. **Always write full literals** — prefix-const concatenations are
  invisible to the scanner.
- `scripts/import/strip_lods.gd` (project-wide import script) drops Synty
  `_LOD1+` siblings; `tools/patch_gltf_materials.py` fixes alphaMode /
  texture-index / emissive bugs post-fetch.
- Cooked Synty glTFs keep **centimetre vertex data corrected by a scaled child
  node** — never use a raw `mesh.get_aabb()` without carrying the
  MeshInstance3D transform chain (see `GameWorld._add_aabb_collider`).
- Animation: runtime `AnimationPlayer` + retarget (`character_animator.gd`,
  `anim_retarget.gd`), no AnimationTree. All 8 M1 skins (Gang_Warfare crew,
  City_Characters enemies) share the 55-bone "unreal" rig; clips retarget from
  the classic Polygon rig reference. Gang_Warfare skins ship an embedded
  AnimationPlayer that `attach()` deactivates. 4-direction strafe locomotion
  (run_f/l/r/b) keys off velocity in the body's local frame.

### HUD
`scripts/ui/hud.gd` builds everything from the INTERFACE_SciFi_Soldier_HUD
sprite pack (fetched from the server's raw tree) + `UITheme`. Portraits show
the live **shield segment** above health plus a **status-effect icon row**
(still a stub — reserved for status effects). Weapon icons match the
CyberCity meshes 1:1 (`ICON_SM_Wep_*_SciFiCyberCity.png`). Downed crew get a
world-space DOWN / REVIVING % label.

---

## Tuning Knobs

| What | Where |
|------|-------|
| Player speed / accel / sprint | `player_controller.gd` consts |
| AI cover search, hold/pop cadence, burst size, flank trigger/arc | `combat_brain.gd` consts (top of file) |
| Follower leash + engage distance | `squad_follow.gd` consts |
| Enemy aggro radius / packs | `EnemyController` exports, spawn table in `game_world.gd` |
| Weapon damage / accuracy / rates | `resources/gear/*.tres` (enemies use `enemy_smg.tres`) |
| Grenade radius / fuse / damage | `resources/abilities/frag_grenade.tres` |
| Cover tier thresholds | `cover.gd` consts |
| Camera zoom clamp / follow speed | `game_world.gd` camera consts |
| Arena layout, cover placement, spawns | `game_world.gd` `COVER_LAYOUT` / `CREW_SPAWNS` / `ENEMY_SPAWNS` |

## Known Gaps / Decided-Out (M1)

- **No gun animation pack on the asset server** — shooting is muzzle flash +
  tracer only; hit/death clips retarget from the Sword Combat pack. Revisit if
  a rifle animation pack lands.
- Status effects are still a HUD stub (empty icon row on portraits).
- Downed crew can't be executed — enemies and grenades ignore bodies at
  0 HP, so downing is strictly recoverable until the whole squad drops.
- Enemies idle until aggro — patrol routes / alert states are Phase 2.
- Weapon meshes are not yet attached to character hands (icons + tracers carry
  the read); needs a bone-attachment pass.
- GDScript lambdas capture locals **by value** — signal-outcome flags in
  harnesses must be instance vars (see `skirmish_smoke.gd`).

## Testing

Headless suites under `future/tests/harnesses/` (the `future/` dir is
`.gdignore`d out of the game): `rig_probe` (runs via `--script`),
`resources_smoke`, `combat_smoke`, `ai_probe`, `skirmish_smoke`, `m1_smoke` —
each prints `NAME: ALL PASS` and exits 0/1. `overview_shot` screenshots the
live skirmish under Xvfb into `.screenshots/`. Boot any scene standalone and a
debug squad spawns with `GameState.debug_session = true` so future persistence
never touches real saves.
