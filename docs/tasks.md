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
- [ ] Balance from human playtests (AI-vs-AI smoke wins too cleanly)
- [x] Proper gravity / falling feel, first pass: one Character.GRAVITY
      (24.0, ~2.5×), reduced air control + air drag on the player, landing
      thump SFX + dust above a fall-speed threshold
- [ ] Falling feel, later: fall damage thresholds, ledge coyote time,
      deliberate drop input vs soft edge resistance on catwalk decks
- [x] Characters can get boosted onto prop tops by capsule depenetration —
      anyone above the walkable plane snaps back to the nearest navmesh point
      (flat-arena guard; revisit for multi-floor)
- [x] Pressure HUD v1 ("HEAT"): thin top-center bar weighing enemy awareness
      states (fighting > suspicious > fleeing), easing cyan→red; hidden when
      the district is quiet
- [ ] Pressure v2 ideas: incoming-fire intensity, flank warnings, per-pack
      direction hints

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
- [ ] Proper patrol ROUTES (waypoint paths; IDLE wander + alert states are in)
- [x] Camera floor transitions: continuous camera follow kept; the
      FloorSystem reveal state is what transitions — floor above fades in
      across the last quarter of the climb (hidden <75%, solid by 95%),
      active floor flips with hysteresis (up at 90%, down at 60%), higher
      floors stay hidden, characters one floor up drawn only while a crew
      member has a line on them (overlook rule), lights/overhead bars fade
      with their floor
- [ ] Audio pass (AudioManager autoload, wayfarer `gen_audio.py` lineage)
- [x] Remove the "AREA CLEAR" end popup — victory now shows nothing; the
      site falls quiet and the crew travels out (SQUAD WIPED popup stays)
- [ ] Mission-complete feedback, the different way: HUD cue / objective
      ping / district-map state — design open
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
      objectives emit site_cleared. HEAT scoped to enemies within 40 m
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
- [ ] Progression follow-ups: boss/objective XP when those systems land,
      deeper per-member perk menus (role-exclusive picks), difficulty
      scaling against crew level
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

- [ ] **Demon hordes** — the cult's expendables: lots of weak melee/close
      rushers, high bodycount, spiced with a few strong bruisers. Needs a
      swarm-flavored brain variant (charge, no cover use, maybe simple
      flocking), a melee attack path (no melee system yet), performance check
      at 20-40 bodies (docs say GDExtension only if it actually bottlenecks),
      and horde-scale telegraphs so the strong ones read. Asset candidates
      (verified on the asset server): POLYGON_SciFi_Horror,
      POLYGON_CityZombies / BossZombies (horde bodies + big bruisers),
      POLYGON_Apocalypse.
- [x] **Space bandits** — SHIPPED as the district-wide bandit personality:
      every gang pack has morale and cracks EARLY (bandit nerve — packs
      break at 60% strength via `morale_break_frac`, flee, slink back),
      looted mixed guns (scrap pistols, looted rifles alongside SMGs), and
      shock-stick blade RUSHERS seeded in the street/exchange/depot packs —
      the first users of the melee path. Grenade-happiness still open.
- [ ] **Corporate security / military** — the scary ones: full use of the
      systems the player fights with. Shields (they already exist — just give
      them max_shield), tight pack discipline (bounding overwatch: one element
      suppresses the LKP while another flanks), disciplined trigger control,
      flashlight/vision-cone patrols on real routes, and their own medic or
      shield-restore support unit. Should feel like fighting a mirror of your
      own squad. Asset candidates (verified): POLYGON_Spy_Kit,
      POLYGON_BattleRoyale, POLYGON_Mech (heavy support walker?), with
      POLYGON_Military_Warehouse for their turf.
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
- [ ] **The cyber-ninja clan** — Little Japan's street authority (see
      docs/locations.md). Melee/mobility faction that weaponizes the
      awareness system from the other side: they break YOUR line of sight —
      smoke, dash gap-closers, rooftop routes — and strike from where your
      LKP on them is stale. Shurikens as silent PROJECTILE weapons (no
      hearing alert — the quiet counterpart to gunfire), katana melee (melee
      attack path shared with the demon-horde prereq), and clan honor rules:
      neutral-ish on their turf like the Assembly, but they never forget a
      slight (persistent standing, not per-mission aggro). Asset candidates
      (verified): SK_Chr_CyborgNinja_01 (SciFi_City), POLYGON_Samurai pack
      (ninja/warrior/sensei bodies), CyberCity katana + shuriken meshes, and
      the ANIMATION_Sword_Combat attack combos already fetched for
      hit/death clips.
