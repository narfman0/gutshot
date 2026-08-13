# Locations — the Vantag District

One locale, tightly connected — the game's sense of place comes from a few
adjacent sites the crew can move between quickly, not from a sprawling map.
All names are working names.

## The district at a glance

A mid-spire commercial district in the hive city: the **Vantag Corporation
tower** dominates it, with its logistics warehouse and a robotics fabrication
level in the tower's shadow. The crew's hideout sits in the margins between
them. Vantag is the corporate backer from the narrative — and somewhere in
the tower's upper floors, the cult they funded has opened something.

```
                    ┌────────────────────┐
                    │  VANTAG TOWER      │  upper floors: THE PORTAL
                    │  (corporate spire) │  mid floors: offices, security
                    │                    │  lobby: public, watched
                    └──────┬──────┬──────┘
              skybridge ───┘      └── freight elevator
                    │                     │
        ┌───────────┴────────┐   ┌────────┴───────────┐
        │  DEPOT 9           │   │  FAB LEVEL         │
        │  (warehouse)       │───│  (robotics lab)    │
        │  bandit-run        │ ^ │  Assembly turf     │
        └───────────┬────────┘ │ └────────────────────┘
                    │    freight tunnel
              transit stop
                    │
              ┌─────┴─────┐
              │  HIDEOUT  │  (safe room — mission select, loadouts)
              └───────────┘
```

## Sites

### Vantag Tower (corporate spire)
The vertical showpiece — Phase 2's multi-floor tech is built FOR this place.
- **Lobby/atrium**: public floors, corporate security posture (patrols,
  cameras); going loud here burns the district.
- **Mid floors**: offices and security levels — corp security faction at
  full discipline, breach-able doors, elevation LOS.
- **Upper floors**: the cult's portal site. The higher you climb, the less
  corporate it gets — security gives way to cultists, then to demon hordes
  pouring from the breach. The tower's own staff are barricaded in pockets.
- The tower is where all three hostile pressures meet: corp security
  guarding it, the cult inside it, hordes leaking out of it.

### Depot 9 (warehouse)
Vantag's logistics warehouse, quietly ceded to space-bandit crews who move
"lost" cargo. Ground-level sprawl: container mazes (cover-rich), catwalks
(elevation), loading docks (vehicle-scale doors = breach points).
- Bandit faction turf; morale fights — thin a crew and the rest scatter
  into the stacks.
- Natural first Phase-2 level: single floor + catwalks exercises breach
  doors and elevation LOS before the tower demands full multi-floor.

### Fab Level (robotics lab)
A fabrication and maintenance level where the Assembly (the semi-sentient
machine faction) has consolidated. Clean-room corridors, assembly lines,
charging alcoves. Neutral turf: machines posture and escort trespassers out;
violence only if provoked — but Vantag wants the level "audited" and the
cult wants its fabricators, so provocation is coming from all sides.
- The three-way-fight sandbox: bait corp security or hordes into machine
  territory and let the district sort itself out.

### The Hideout (safe room)
A bolt-hole in the district margins — the narrative's "one safe place".
Mission select (district map), loadout swaps, later: crew conversations,
injuries, progression. No combat systems load here.

## Quick travel

Distances are diegetic but travel is instant — pick a destination, fade,
arrive (SceneManager.change_level + LEVELS registry already does exactly
this; add one entry per site).

- **District map** in the hideout = mission/site select.
- **In-fiction connectors** double as level entrances/exits AND mid-mission
  shortcuts once unlocked: the skybridge (tower ↔ depot roof), the freight
  elevator (tower sub-level ↔ fab level), the freight tunnel (depot ↔ fab).
- Connectors are gameplay, not just doors: a crew being overrun in the
  depot can fall back through the freight tunnel into Assembly turf — and
  whatever chases them becomes the machines' problem.
- Later (Phase 3), procedural missions draw their tile palettes from
  whichever site hosts them, so generated content stays in-district.

## Implementation order

1. **Depot 9** — first hand-crafted Phase-2 level (breach doors, catwalk
   elevation, bandit morale fights).
2. **Hideout + district map** — trivial scene + UI; makes the locality real
   the moment there are two sites to pick between.
3. **Fab Level** — flat but faction-novel (needs the faction/hostility
   refactor from docs/tasks.md).
4. **Vantag Tower** — the capstone: full multi-floor, all factions, portal
   finale. Likely several sub-scenes (lobby / mid / upper) linked by the
   elevator rather than one giant scene.
