# Tasks

## Phase 1 — Core Combat Loop ✅ (M1 complete)

- [x] Project bootstrap: Godot 4.7, asset-server `fetch_assets.sh` (cooked +
      raw trees), Synty import fixes (`strip_lods.gd`, `patch_gltf_materials.py`)
- [x] Character scene + runtime animator/retarget (4-dir strafe locomotion,
      hit/death oneshots), 8 skins probed (`rig_probe`)
- [x] Gear/ability Resource system per architecture.md (3-slot loadout,
      `action_slots`, frag grenade ability, .tres set)
- [x] Shooting: hitscan + projectile, per-shot accuracy, run-and-gun penalty,
      tracers/muzzle flash/damage numbers/juice
- [x] Tiered cover: 5-point body exposure raycasts (exposed / half / full)
- [x] WASD player controller, sticky aim, weapon slots 1/2/3, Tab switching
- [x] Shared CombatBrain (cover-seek → hold → pop-out burst → flank) for
      followers AND enemies; pack aggro
- [x] Skirmish arena (50×50, CyberCity props), runtime navmesh, boundary walls,
      iso camera (wide zoom clamp), win/lose overlay
- [x] HUD from INTERFACE_SciFi_Soldier_HUD sprites: portraits (shield +
      status-row stubs), weapon bar with matching icons, overhead bars,
      hostiles counter
- [x] Headless harness suite + Xvfb screenshot gallery; balance pass

### Post-M1 feel patches (done)
- [x] Doom-snappy WASD-only movement (click-to-move removed), hold-LMB fire
- [x] Range falloff instead of hard range cap; guaranteed return fire
      (shot_at → threat pin)
- [x] Crew shields (regen out of combat) + downed/revive instead of death

### Polish sprint (done)
- [x] Placeholder audio: gen_audio.py + AudioManager (shots, impacts, shields,
      reload, explosion, telegraph, down/revive, city ambient)
- [x] Magazines + reload (auto on empty, R manual, HUD ammo + reload sweep)
- [x] Weapons attached to hands (BoneAttachment3D, scale-corrected)
- [x] Enemy + follower grenade usage (frag dug-in targets before flanking)
- [x] Vertical squash experiment (Character.VERTICAL_SQUASH = 0.8)
- [x] Medic heal gun (auto-medic follower AI + player heal targeting)
- [x] Awareness system: IDLE wander → SUSPICIOUS noise investigation → FIGHT
      with last-known-position aiming, suppressive fire at stale LKPs, pack
      alert sharing, lost-track stand-down

### M1 polish backlog (nice-to-have, not blocking)
- [ ] Weapon grip orientation tuning (currently held at the side; fine at
      gameplay zoom)
- [x] Aim-at-cursor firing (LMB fires immediately toward the cursor, cone
      soft-acquire; gunfire alerts enemies in earshot)
- [ ] Balance from human playtests (AI-vs-AI smoke wins too cleanly). The
      pacing_probe harness now reports the economy so tuning is not blind —
      but it cannot tell you how anything FEELS. Two findings already
      waiting on a human call, see below
- [x] Proper gravity / falling feel, first pass: one Character.GRAVITY
      (24.0, ~2.5×), reduced air control + air drag on the player, landing
      thump SFX + dust above a fall-speed threshold
- [ ] Falling feel, later: fall damage thresholds, ledge coyote time,
      deliberate drop input vs soft edge resistance on catwalk decks
- [x] Characters can get boosted onto prop tops by capsule depenetration —
      anyone above the walkable plane snaps back to the nearest navmesh point
      (flat-arena guard; revisit for multi-floor)
- [~] Pressure HUD ("HEAT") — built, then REMOVED (2026-08-14). A weighted
      awareness meter told the player what the fight already tells them,
      and in the seamless district it was on almost permanently. If threat
      readability comes back, it should be diegetic (per-pack direction
      cues, incoming-fire intensity), not a global bar

## Playtest feedback — 2026-08-15 (first human play session)

The first real playtest. Every item below is observed behaviour, not theory;
the diagnosis after each is from reading the code afterwards, so it is a
starting point rather than a verdict.

- [ ] **Factions fight the moment the game opens.** They should be quiet and
      docile in general, and start trouble only when something causes it.
      Cause is structural rather than a bug: `Factions._BASE_HOSTILE` puts
      GANGS at war with CORP and CLAN from boot, every pack has an
      `aggro_radius` that engages on sight, and Little Japan deliberately
      ships a standing three-way (clan patrol vs gang shakedown). So the
      district is mid-fight before the player does anything. Wants a real
      decision: either factions start neutral and base hostility becomes
      something the world EARNS, or packs need a "don't start it" posture
      that only breaks when provoked or when the player is seen
- [ ] **Gunshots carry through walls and across sites**, pulling enemies —
      and reaching into the hideout. `Shooter._alert_hearing()` alerts every
      hostile within `HEARING_RADIUS` (14 m) on straight-line DISTANCE with
      no occlusion test at all, so a wall, a building or a site boundary
      stops nothing. Wants an LOS/occlusion check (or a muffling factor
      through COVER geometry), and the hideout should probably be deaf to
      the outside world regardless
- [x] **Render all floors** — done by DELETING the reveal/translucency
      system outright (your call: all floors, both camera modes). FloorSystem
      and the now-dead `floor_heights()` hook are gone; multi-floor sites are
      always drawn whole. The combat smoke now asserts the opposite of what
      it used to: no geometry in the Exchange may be faded or hidden, from
      the ground floor OR the gallery, so nothing can quietly start hiding
      things again.
      WATCH FOR: the reveal existed so the iso camera could see under a
      deck. If standing beneath the Exchange mezzanine now hides the crew,
      the fix is camera-side (raise the angle, or cull only what sits
      between camera and player) rather than bringing translucency back
- [ ] **The party does not reliably follow.** They should generally follow
      whoever the player is controlling. `SquadFollow._in_combat()` returns
      true if ANY hostile is within `ENGAGE_DIST` (16 m) of the follower OR
      the leader, and also whenever `brain.threat` is pinned at any distance
      — and in a district where gangs are hostile on sight, that is almost
      always true, so followers fight instead of following and get left
      behind. Wants following to win more often: a tighter engage distance,
      a leash to the leader that overrides combat past some range, or
      "follow unless actually being shot at"
- [ ] **Shooting does not always fire when clicked.** Two halves:
      (a) ISO — clicking should always send a round toward the click even
      with no target. The wild-shot fallback exists, but only when the cone
      acquires NOBODY; if it acquires an enemy who is in full cover,
      `try_fire` refuses via `can_fire` → `Cover.can_hit` and the click is
      swallowed silently. Fall back to `fire_wild` whenever `try_fire`
      returns false.
      (b) OTS — should fire immediately on click and keep firing while held
      until the magazine is empty. Same swallowed-click cause, plus worth
      checking the captured-mouse input path delivers the press promptly

## Phase 2 — Multi-Floor Template Level (next)

See docs/locations.md — the Vantag District: tower (portal), Depot 9
(warehouse), Fab Level (robotics lab), hideout, with instant travel between
sites via the SceneManager registry. Depot 9 is the first hand-crafted level.

- [x] Depot 9 (warehouse): container aisles, catwalk-over-the-wall elevation
      (one navmesh, ramps), two breach doors (shoot/blast → navmesh rebake),
      bandit packs with patrol routes + morale breaks, transit pads to/from
      the street (GameWorld refactored into base + per-level subclasses)
- [x] Depot 9 dressing pass: roller-door meshes on the breach doors (damage
      strip glows toward failure), catwalk railings, sodium interior light
      mood; usability: pause menu (Esc), site-name label, crosshair cursor,
      active-character-only transit pads, followers auto-revive downed mates
- [x] Lighting pass, first slice: SSAO + filmic tonemap globally, per-level
      depth fog (dusty depot, night haze street, smoky hideout), practical
      lights pinned to things (vending storefront glow, under-catwalk strips,
      aisle sodium pools, hideout lamps), red warning lamps on sealed breach
      doors that die with the door
- [ ] Lighting pass, later: shadow budget beyond the sun, light cookies/IES
      looks, occlusion culling check, darkness as gameplay (sight ranges
      shrink in unlit aisles?)
- [x] Hideout (safe room: warm light, no enemies, map console) + district
      map overlay — M anywhere, console walk-up, travel to unlocked sites;
      locked entries tease Little Japan / Fab Level / Tower
- [x] Main menu (boot scene: title, Enter the District → hideout, Quit)
- [x] Faction refactor: Factions hostility matrix (base war + runtime
      provocation, reset per site), all binary-team math swept; damage
      between neutral factions provokes; player cone targets hostiles first
      with deliberate-neutral fallback; HUD heat/overheads faction-aware;
      ObjectiveManager `required` flag so neutrals never gate missions
- [x] Fab Level: the Assembly v1 — neutral machine custodians (Arc Cutter
      lasers, patrols, no morale), a fabricator sanctum with trespass
      warning → provocation, bandit salvage crew as the objective, freight
      tunnel from Depot 9; district map unlocked
- [x] Multi-floor hand-crafted level — went straight to THREE floors: the
      Exchange (shuttered market hall): ground trading floor, mezzanine
      gallery with guards firing down over the rails, closed-off counting
      house up top. ONE navmesh spans all floors via ramp stairs (the
      catwalk recipe scaled up — teleport waypoints never needed)
- [ ] Destructible doors + breach points (Depot 9 has them; generalize)
- [x] Elevation-aware LOS and cover: walkable decks/ramps carry GROUND|COVER
      so floor slabs block sight and shots between floors
- [x] Patrol routes: waypoint paths existed and were used by depot/exchange/
      fab/tower/Little Japan, but read like wind-up toys — nobody ever
      stopped. Guards now DWELL at each post (jittered 0.6–1.6× so pack-mates
      sharing a route fall out of lockstep) and SWEEP their gaze across an
      arc while held, and coming off a fight they resume at the NEAREST post
      instead of walking the whole loop back to the index they abandoned.
      The street's ground packs got beats too — one walker per pack, the rest
      anchored, because a gang HOLDS a corner rather than marching it
- [x] Camera floor transitions: continuous camera follow kept; the
      FloorSystem reveal state is what transitions — floor above fades in
      across the last quarter of the climb (hidden <75%, solid by 95%),
      active floor flips with hysteresis (up at 90%, down at 60%), higher
      floors stay hidden, characters one floor up drawn only while a crew
      member has a line on them (overlook rule), lights/overhead bars fade
      with their floor
- [x] Audio pass v1 — real recordings replace most of the placeholder tones.
      The asset server turned out to hold a 1,342-file Kenney audio library
      nobody had touched; fetch_assets.sh grew an audio prefix and now pulls
      99 samples. New SoundBank maps a logical cue to SEVERAL real files and
      AudioManager picks one at random — the fatiguing thing about
      placeholder audio was never fidelity, it was the same impact firing
      forty times a fight. Gunfire deliberately STAYS synthesized (the
      library is sci-fi, with no ballistic recordings) but gained three
      jittered variants apiece. Impacts now split metal from flesh, breach
      doors ring and blow, the active character has footsteps (only the
      active one — the mix is non-positional, thirty sets of boots is mud),
      and the ASSEMBLY SPEAKS: synth-voice warnings ("lower your weapon")
      before it escalates, engagement calls after — a posture that was in
      the design and inaudible until now. audio_probe guards it, since the
      samples are fetched and gitignored
- [x] Remove the "AREA CLEAR" end popup — victory now shows nothing; the
      site falls quiet and the crew travels out (SQUAD WIPED popup stays)
- [x] Mission-complete feedback — answered by jobs: delivery at the hideout
      flashes the contract paid, landing on the player's own action rather
      than as a popup over the bodies. Clearing a SITE still says nothing,
      deliberately: sites repopulate, so they are terrain rather than an
      achievement
- [x] Seamless district: ONE world scene (district.tscn) — sites are @tool
      SiteChunk scenes instanced at editor transforms (open a site scene or
      the district in the editor and see it built), walled connector
      corridors between gates, travel on foot only, district map turned
      informational. Navmesh: one region per site/corridor via
      filter_baking_aabb (~45 ms total; a monolithic bake took minutes),
      stitched by the map's edge-connection margin; breach rebakes are
      site-scoped and threaded. Crew spawns once; site tracking drives the
      HUD label, autosave (save shape unchanged), env mood lerp, and the
      hideout rest (heal + provocation reset — grudges now reset on rest,
      not travel). Cleared sites repopulate after ~5 s vacant; per-site
      objectives emit site_cleared
- [x] Corridor dressing: per-connector identities (alley / arcade / service
      passage / freight tunnel) — visible walls (tall camera-far side, low
      curb camera-near so the iso view stays open), junk-prop cover along
      the edges, overhead beams on covered styles, per-style floor/light/
      strip colors, destination signs at each mouth
- [x] Zone ambience: one synthesized bed per site mood (city / hideout room
      tone / exchange hall wind / depot machinery / fab machine hum),
      SiteChunk.ambient() hook, AudioManager two-player crossfade on site
      entry (corridors keep the last site's bed, like the HUD label)
- [x] Connector gameplay — the district reacts: fighting packs with
      `pursue` (default) break the spawn leash and chase the crew through
      corridors into other sites; losing the track ends the chase and they
      walk home across the district. Defensive packs (vault crew, the
      Assembly) hold their ground. Turf law: gunfire inside the fab's
      sanctum guard ring (14 m) heats the SHOOTER'S faction toward
      provocation — CEASE FIRE warning first, sporadic fire decays — so a
      clever crew can bait a gang pack into machine turf and walk away from
      the three-way fight (district_pursuit_smoke proves the whole play).
      Global `GameState.shot_fired` signal is the district's ears
- [x] Melee attack path: GearItem MELEE fire mode — reach-gated swings
      (fire_range = arm's length), no ammo, sword-pack attack anim, swing/
      slash sfx, and QUIET by design: steel never trips hearing alerts,
      shot_fired, or turf heat (the ninja identity, pre-built). CombatBrain
      melee tick = run the threat down at 1.35× and swing (the demon-horde
      recipe). Gear: scrap_blade (shock stick), katana (for the clan later).
      Unblocks: demon hordes, cyber-ninja clan, Little Japan
- [x] Progression v1 — squad XP pool per crew-credited kill (last_attacker
      tracking; grenades credit the thrower), machines pay double, respawned
      packs pay half per repop generation (pushing new always beats farming
      the refill), first-clear milestone 120 XP once per run per site. One
      crew level (cap 10, 200×level thresholds): +6 hp / +4 shield lands
      LIVE on level-up, but perk PICKS spend only at the hideout console
      (TrainingPanel takes the console over while picks are owed; map stays
      on M). Perks are chunky per-member choices (Perks registry: Capacitor
      Rig, Scar Tissue, Dead Eye, Quick Hands, Combat Stims). HUD XP line
      under the site label with the TRAIN nudge; save v2 persists
      xp/level/perks/cleared (v1 saves load as fresh level 1)
- [x] Little Japan — the market street: stall rows, shrine + torii approach,
      shop-roof tier, hologram cherry tree, dense neon (麺/酒/刀/薬), a
      crowd-murmur+shrine-bell ambient bed, and the district's first
      CIVILIANS (Factions.CIVIL, unarmed, they scatter). Encounter is a
      standing three-way: clan patrol + roof watch + sensei vs a gang
      shakedown at the south stalls, with the crew free to pick a side
- [x] Jobs v1 — RETRIEVAL contracts, the district's reason to exist: a job
      board on the hideout console (perk picks still take priority; the map
      stays on M), three contracts (chop shop ledger / depot manifest /
      the clan swordsmith's blade), one live at a time. The take is a
      glowing pickup inside an add_room interior — only the ACTIVE character
      can lift it, so a follower pathing through a doorway can never start
      the job for you. Lifting it puts the owner's people within 70 m onto
      the carrier every 2 s (the word going out; the existing pursuit AI
      does the chasing), and the hideout is the ONLY place that banks it —
      which is also the only place that heals, so the run home is the job.
      Delivery pays 150–240 XP and lands the mission-complete beat where
      the crew is safe rather than as a popup over the bodies. Save v3
      persists the live contract + finished ones
- [x] Jobs v2 — all four verbs, six contracts, one board. HIT (a named mark
      with a nameplate and a detail, at the Exchange), SABOTAGE (an Assembly
      fabricator core that takes bullets AND grenades, in the Fab sanctum),
      ESCORT (a Vantag informant who follows the crew home and whose death
      LOSES the contract, out of the Tower lobby) alongside the three
      retrieval jobs. Every type reuses the same `carrying` flag as
      "objective done, now get home and get paid", so the hunt, the banking
      and the HUD all work unchanged — the verbs differ only in what STARTS
      the run home. Sabotage extends BreachDoor so both existing damage
      paths hurt it for free. Three of the six are owned by NEUTRAL factions
      (clan/Assembly/corp), which is where the "you just made an enemy"
      beat actually lands
- [x] Abilities in the tree — the KIT line, running the full height of the
      tree so every tier hands over a VERB rather than a number: Smoke Screen
      (t2), Focus Fire (t3), Combat Stim (t4), EMP Charge (t5), alongside
      Demolitions. Cast on a new Q/E/F/C kit bar (gear stays on 1/2/3 — gear
      is what you carry, kit is what you learned) with live cooldowns in the
      HUD. Deliberately DECIDED AGAINST credits/a fence: a currency with no
      sink is a second XP bar, and XP stays the single progression currency
      that jobs pay into
- [ ] Jobs follow-ups (no economy): chained/multi-stage contracts, jobs that
      expire if you dawdle, rival crews racing you to the same take
- [ ] Gear is still not a player choice — the crew loadout is hardcoded at
      spawn (gunner/rifle, medic/heal gun, everyone else smg+pistol+belt) and
      6 of the 16 GearItems are enemy-only. The katana, ninjato and shuriken
      the clan monopolises are player-viable already. A loadout screen at the
      hideout would open a system that is built and currently invisible
- [x] Progression v2 — the CREW TREE replaces per-member perks. One shared
      trunk, one point pool (2 per crew level), no member picker: nodes buff
      the whole crew and the identity nodes are role-tagged (Point Man
      trains the leader, Field Surgeon the medic) but cost the same pool.
      Depth via MILESTONE gating — tiers open at crew level 1/5/12/22/35 —
      plus per-node prerequisites, which are independent locks. Level cap
      10 → 50 on a curve that slows hard (25 XP for level 2, ~995 for 11,
      ~12,655 for 50); flat per-level HP/shield shrunk to 2.0/1.5 since the
      tree now carries growth. Panel scrolls, shows locked tiers with their
      unlock level, prints WHY a node is blocked, and has a "spend it for
      me" escape hatch. Save v4
- [x] Tier gates pulled to 1/4/8/14/22 — pacing_probe showed tier 4 (was
      level 22) and tier 5 (was 35) were unreachable, making two of five
      tiers decoration. Now 2 tiers open in the first session, 3 by ~5,
      4 by ~20, all 5 by ~80. The XP curve stays steep; the gates moved to
      meet it
- [x] Job payouts re-based on a RULE rather than feel: verb difficulty
      (retrieval 300 / hit 340 / sabotage 360 / escort 400) plus 40 when the
      owner is a neutral faction you have to make an enemy of, plus 20 for
      the clan blade's unforgivable honor grudge. Average job 357 against an
      average first clear of 274, so a session on the board (629) now beats
      one spent clearing another site (546) which beats farming respawns
      (228). pacing_probe asserts that ordering so it cannot silently regress
- [ ] Site XP spread is wide and unexamined: Little Japan pays 478 on first
      clear against Depot 9's 200. Defensible (it is the densest, hardest
      site, and its clan units are worth 30 apiece) but it skews every
      average in the probe. Worth a deliberate pass
- [ ] Progression follow-ups: difficulty scaling against crew level; more
      capstones that grant ABILITIES rather than stats (Demolitions
      Training is the only one today); per-node icons; a respec at the
      hideout. The XP curve and node values are UNPLAYTESTED — tune
      XP_BASE/XP_EXPONENT in GameState
- [x] World + aesthetic polish round v1 — the district no longer floats in
      void: dark city underlay + a skyline ring of background towers beyond
      the walls; sites got VISIBLE perimeter walls (tall camera-far, low
      curb camera-near, per-site tones), pavement seam grids + grime
      stains, and identity dressing — street (food truck, SUV, streetlamps,
      dying neon: 麺 NOODLES / MOTEL / バー BAR), hideout (workbench,
      table+chair, STAY LOW sign), exchange (stall carts, junk, the dead
      hologram cherry tree), depot (hauler truck, wall pipes, antennas,
      DEPOT 9 stencil), fab (holo fixtures, tended hologram tree, clean
      signage). Idle life: flickering neon (deterministic tick) + steam
      vents. SiteChunk grew add_decor/add_neon_sign/add_steam + a raw-cm
      glTF corrector (Buildings-tree meshes ship uncorrected — a "tower"
      measures 1.5 km). Chase AI fix rode along: cover only matters inside
      engage range — pursuers close the gap instead of camping
- [x] Vantag Tower — LOBBY slice, styled on THE lobby scene: marble column
      grid (real chewable cover), polished floor (ground_roughness hook),
      security desk, metal-detector arch, sealed elevator bank, VANTAG
      signage, and a formal mezzanine balcony at 4 m (FloorSystem) with
      marble balustrade + twin staircases. Corp-lite security: "suit" skin
      (Apocalypse business male), spawn-entry `shield` key (30), no morale,
      no pursuit — they hold the lobby. Plaza corridor from the street
      (swept, white-lit, no junk), ambient_lobby bed (HVAC + glassy
      chimes). Upper floors stay sealed — the campaign's problem
- [x] OTS camera evaluation mode (V toggles): perspective over-the-shoulder
      camera with mouse-look, manual spring arm (ray-clamped against
      GROUND|COVER), center reticle (the crosshair texture pinned
      mid-screen while the mouse is captured), aim = camera-center ray.
      Combat resolution IDENTICAL in both modes — same cone acquire, same
      accuracy × cover model — so the fun comparison is camera-only. Pause
      releases/restores mouse capture. If OTS wins, true reticle-ballistic
      shooting becomes a deliberate design decision (it would delete the
      cover/accuracy model)
- [x] Procedural sky: ProceduralSkyMaterial night gradient (violet zenith,
      light-pollution horizon), sun disk off, per-site sky_energy() lerped
      with the mood tween — the OTS camera made the black void overhead
      impossible to ignore. Asset-server panoramas were evaluated and
      rejected (sky_gloom_01 is a flat daylight gradient)
- [x] Ground materials: one procedural shader for every walkable surface
      (slabs + grout, fbm grime, ridged cracks, puddle mask driving
      roughness/specular), per-site ground_params() so each floor has its
      own identity, corridors included; SSR on so neon reflects in the wet.
      Replaced the flat plane + seam boxes + decal blobs that made every
      site read the same
- [ ] Ground v2 ideas: normal-map perturbation on grout/puddle edges,
      painted floor markings (depot hazard stripes, tower inlay), footprint
      or blood decals that accumulate during a fight
- [x] Real buildings: SiteChunk.buildings() places WHOLE structures with
      AABB colliders (COVER layer + navmesh carve), each region using its
      own architectural vocabulary — cyber tenements/bank/chopshop on the
      street, plastered dobei walls + temple archway (deliberately LOW) in
      Little Japan, industrial sheds + power block at the depot, mid-rise
      neighbours around the exchange, clean modular blocks at the fab,
      corporate towers standing back from Vantag, and two backs-of-buildings
      squeezing the hideout. Facades sit outside the wall line, clear of
      every gate mouth, so playable space and corridors are untouched
- [x] Enterable interiors: SiteChunk.add_room builds walled rooms with a
      single DOORWAY on the site's own floor — three solid walls, a split
      front wall, a lintel, interior lamp and a shop sign; walls are COVER +
      navmesh sources, so the door is the only way in for bullets, sight
      lines AND pathfinding. Shipped: chop shop + noodle bar on the street,
      swordsmith + tea house in Little Japan, the foreman's office at the
      depot. Open-topped on purpose (a roof would blind the iso camera).
      World smoke asserts both halves: pathable through the door, and the
      back corner genuinely out of sight from the street
- [x] Buildings v2 finished: corridors are ALLEYS — each style flanks its
      run with buildings from its own palette, so a connector reads as a gap
      between structures instead of a trench; the street gained a
      fire-escape ROOFLINE (walkway + stairs + rail, with a gang lookout who
      owns the crossroads from up there, on a FloorSystem tier); and
      shopfront BAYS (pillar pair + awning + lamp) give cover you can back
      into along the street and market frontages
- [ ] Asset cook fix (UPSTREAM, outside this repo): the cook drops most of
      each pack's textures and loses material→texture bindings — see
      docs/architecture.md §Asset pipeline. Downstream consequence today:
      Military_Warehouse shipping containers and roller doors render FLAT
      WHITE (no atlas exists to attach), and SciFi_City Background_*
      buildings are unusable. Repo-side option if the cook can't be fixed:
      pull the specific textures from the RAW tree (served) and add a
      per-mesh texture manifest to patch_gltf_materials.py
- [ ] Buildings v3 ideas: alley depth between structures
      (corridors as real gaps rather than trenches), rooftop routes onto the
      facades, ground-floor shopfront bays as cover
- [ ] Polish round v2 ideas: facade pieces on the tall walls, ground
      texture decals (real textures over seam boxes), animated holograms,
      district-edge fog wall, rain
- [ ] Seamless-district follow-ups: spatial pruning for hostiles_of/hearing
      scans if rosters grow past dozens
- [x] Save/load stub: crew hp/shields carried between sites (hideout heals),
      autosave on arrival, Continue on the main menu; debug/harness runs can
      never write a real slot (GameState.run_active gate + scratch-slot tests)

## Deferred — enemy factions

Distinct enemy types with their own AI feel, not just stat swaps. Each maps
onto the narrative's antagonist structure (cult muscle + corporate backer)
and onto systems that already exist (CombatBrain, awareness, packs).

- [x] **Demon hordes** — SHIPPED as The Spawn (Factions.HORDE, at war
      with EVERYTHING): breach the tower's Level 4 seal (now a heavy
      BreachDoor) and 24 husks — the tower's own staff, turned
      (CityZombies suits/bellboys) — pour out in four waves, capped by two
      ZombieBoss BRUTES (320 hp, heavy claws, and a Telegraph-circle SLAM
      ability off their gear — dodge or eat 45). Swarm brain = the melee
      charge tick; pursue on, no morale — they flood downstairs after you.
      Vantag Security becomes the containment team; the exec-floor
      three-way is the show. Perf check PASSED: 16.6 ms avg physics frame
      with 26 extra bodies live (no GDExtension needed). Horde kills pay
      5 XP (brutes 60); wiping the release clears the tower.
- [x] **Space bandits** — SHIPPED as the district-wide bandit personality:
      every gang pack has morale and cracks EARLY (bandit nerve — packs
      break at 60% strength via `morale_break_frac`, flee, slink back),
      looted mixed guns (scrap pistols, looted rifles alongside SMGs), and
      shock-stick blade RUSHERS seeded in the street/exchange/depot packs —
      the first users of the melee path. Grenade-happiness still open.
- [x] **Corporate security** — SHIPPED as Vantag Security (Factions.CORP):
      neutral to the crew (the lobby is public), base-hostile to gangs.
      Shields on every suit, bounding overwatch (`disciplined` — half the
      pack suppresses the LKP in cadenced bursts while half advances, roles
      swap every 6 s), and a shield-MENDER support unit (restores_shield
      heal beam, shepherds the pack in or out of fights). Provocation on
      their terms: gunfire in the tower (one warning, then the room) or
      climbing past the lobby (grace, then SECURITY RESPONSE). No morale,
      no pursuit — they hold the building. Still open: vision-cone patrols,
      heavy support walker (POLYGON_Mech), response teams beyond the tower.
- [~] **The Assembly (v1 SHIPPED on the Fab Level; below is the full
      vision)** — semi-sentient machine society —
      neutral-alignment robots, not anyone's foot soldiers. Territorial, not
      hostile: they hold zones (salvage fields, maintenance levels), warn
      trespassers off (posturing/escort behavior before violence), and only
      escalate when provoked — attacked, or their territory shot up. Once
      provoked they fight ANYONE in the zone, cult and corpo included, which
      is the fun: a mission can tip into a three-way fight, or a clever crew
      can bait the other faction into machine turf. No shields but no morale
      either — machines don't rout, they calculate (disengage when losing the
      math, return with more units). Distinct sound/read: no voice, servo +
      chirp SFX, drone spotters feeding LKPs to walker guns.
      **Engineering prerequisite**: the team system is binary today (`team`
      0/1, `1 - team` math, `team_N` groups everywhere) — a third faction
      needs a faction id + hostility-matrix refactor of Character,
      CombatBrain, Projectile, and the group names first.
      Asset candidates (verified): POLYGON_Scifi_Space skinned robots
      (SK_Chr_BR_War_Robot_01, SK_Chr_RobotFemale_01), drone props in
      CyberCity/SciFiWorlds for spotters, POLYGON_Mech for the heavies.
- [x] **The cyber-ninja clan** — SHIPPED with Little Japan. Factions.CLAN:
      neutral to the crew, base-hostile to the gangs. SILENT shurikens
      (GearItem.silent — no hearing alert, no shot_fired, no turf heat),
      ninjato/katana melee, rooftop watch on the FloorSystem tier, and
      VANISH: hurt a ninja and they drop a SmokeBomb — a real COVER-layer
      volume, so it blinds player and AI alike through the existing LOS
      raycasts — then dash-flank out of it, leaving your last-known
      position on them stale. HONOR: Factions.note_attack routes CLAN
      through provoke_lasting, and the hideout rest never forgives it.
