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
        └───────────┬────────┘ │ └────────┬───────────┘
                    │    freight tunnel   │ service stairs
                    │                     │
        ┌───────────┴─────────────────────┴───────────┐
        │  LITTLE JAPAN (street level, under the      │
        │  tower's shadow — markets, neon, the clan)  │
        └───────────┬─────────────────────────────────┘
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
- Turf law (BUILT): gunfire inside the fabricator's guard ring provokes
  the Assembly against the shooter's faction — one CEASE FIRE warning,
  then the floor turns. Works on the gangs too: lure a pursuing pack in,
  let them shoot, walk away.

### The Exchange (market hall)
A shuttered vertical market hall in the district margins, bandit-run since
the traders pulled out. Three floors under one roof — the multi-floor tech
proving ground before the tower demands it at scale:
- **Trading floor**: abandoned stalls and freight, cover-rich, open atrium
  overhead.
- **Mezzanine gallery**: a U of decks hugging the walls, guards firing down
  over the railings at anything on the floor. Ramp stairs at the west and
  east walls.
- **The counting house**: a walled room over the north gallery — where the
  take is. Closed off, hidden from below until you climb.
- Bandit turf (morale fights); the counting-house crew is cornered and
  doesn't test morale.

### Little Japan (street level)
The street level under the tower's shadow: noodle stalls, neon signage,
arcades, shrine alleys — the POLYGON_CyberCity pack's Japanese-cyberpunk
identity used at full strength (its prop set IS this place; katanas and
shurikens ship in its weapons folder). Everyone passes through here — it's
the district's crossroads and the closest thing to civilian ground.
- Home turf of a **cyber-ninja clan** (see docs/tasks.md factions): they run
  protection over the street and tolerate the crew — until crossed. Dense
  alleys, market stalls (half cover everywhere), rooftop lines the clan uses
  and you mostly can't.
- Street fights here are knife-range and messy: tight LOS, crowds of cover,
  verticality overhead that belongs to somebody else.
- Connects everywhere: transit stop to the hideout, street entrances to the
  tower lobby and Depot 9, service stairs down from the Fab Level.

### The Hideout (safe room)
A bolt-hole in the district margins — the narrative's "one safe place".
Mission select (district map), loadout swaps, later: crew conversations,
injuries, progression. No combat systems load here.

## Quick travel

The district is ONE seamless world (scenes/district.tscn) — travel is on
foot through walled connector corridors between the sites' gates:

    hideout ── alley ── street ── arcade ── exchange ──── depot
                                                            │
                                                     freight tunnel
                                                            │
                                                           fab

- **District map** (M anywhere, or the hideout console) is informational:
  where you are, what each site holds. No teleporting.
- Cleared sites REPOPULATE once the crew has been gone a beat — the
  district refills behind you. The hideout is the one site that never does;
  entering it rests the crew (full heal, grudges forgiven).
- **Future in-fiction connectors** for the sealed sites: the skybridge
  (tower ↔ depot roof), the freight elevator (tower sub-level ↔ fab level).
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
3. **Fab Level** — SHIPPED: neutral Assembly custodians, sanctum trespass
   rules, bandit salvage crew objective, freight tunnel from Depot 9.
4. **The Exchange** — SHIPPED: the three-floor testbed (mezzanine gallery
   overwatch, closed counting house) that proved the FloorSystem reveal
   state and single-navmesh ramp stairs.
5. **Vantag Tower** — LOBBY SHIPPED (the Matrix-lobby slice: marble column
   grid, security desk, sealed elevator bank, mezzanine balcony with
   corp-lite suit guards; plaza corridor up from the street). The capstone
   still to come: the floors above the sealed elevators — full multi-floor,
   all factions, portal finale.
