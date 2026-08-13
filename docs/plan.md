# Gutshot — Development Plan

## Phase 1: Core Combat Loop

Goal: a playable skirmish on a single flat test map.

- Character movement (click-to-move, NavigationServer3D)
- Shooting (hitscan + projectile, cover system, line-of-sight)
- One active ability (e.g., grenade or dash) driven by the gear/ability Resource system
- Enemy AI that seeks cover and attempts flanking maneuvers
- Basic HUD: health bars, ability cooldown, squad portrait strip
- Win/lose condition (all enemies down / squad wiped)

Deliverable: a 5-minute playable combat encounter.

---

## Phase 2: Multi-Floor Template Level

Goal: vertical traversal and breach-and-clear feel.

- Two or more floors connected by stairs/ladders/vents
- Destructible doors, breach entry points
- Elevation-aware line-of-sight and cover
- Enemy patrol routes and alert states
- Isometric camera that handles floor transitions cleanly

Deliverable: a hand-crafted two-floor level playable start-to-finish.

---

## Phase 3: Procedural Missions

Goal: replayable content loop.

- Modular room tile system (corridor, hub, cover-heavy, open plaza)
- Runtime assembly of a mission map from tile palette + ruleset
- Objective Resource types: Extraction, Assassination, Data Heist, Defend
- XP and loot drops; gear unlocks between missions
- Simple mission briefing screen

Deliverable: 10+ procedurally varied missions with distinct objectives.

---

## Phase 4: Campaign + Story

Goal: a full narrative arc gating procedural content.

- 8-12 hand-crafted story missions with scripted events
- Crew relationship/loyalty system (light — not a dating sim)
- Antagonist escalation arc (cult + corporate backer)
- Persistent crew roster, injuries, gear loadouts between missions
- Main menu, save/load, credits

Deliverable: shippable campaign with beginning, middle, and end.
