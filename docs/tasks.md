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
- [ ] Characters can get boosted onto prop tops by capsule depenetration
      during crowded pop-out shuffles — add a step-height/nav guard
- [ ] Design a "pressure" read to replace the removed hostiles counter —
      something diegetic about how much heat is bearing down on the squad
      (incoming-fire intensity, flank warnings, pack aggro state) rather than
      a raw enemy count

## Phase 2 — Multi-Floor Template Level (next)

- [ ] Two-floor hand-crafted level: stairs/ladder transitions between
      per-floor navmeshes (teleport waypoints per architecture.md)
- [ ] Destructible doors + breach points
- [ ] Elevation-aware LOS and cover
- [ ] Proper patrol ROUTES (waypoint paths; IDLE wander + alert states are in)
- [ ] Camera floor transitions; hide geometry above active floor
- [ ] Audio pass (AudioManager autoload, wayfarer `gen_audio.py` lineage)
- [ ] Main menu + pause; save/load stub honoring `GameState.debug_session`

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
- [ ] **Space bandits** — scrappy mid-tier raiders: current street-gang AI
      but with personality — looser packs, cowardice (morale breaks when the
      pack thins → flee/regroup instead of fighting to the last), looted mix
      of weapons, maybe grenade-happy. Mostly tuning + a morale layer on
      EnemyController. Asset candidates: POLYGON_Spy_Kit / Gang_Warfare /
      Sci-Fi Worlds gear.
- [ ] **Corporate security / military** — the scary ones: full use of the
      systems the player fights with. Shields (they already exist — just give
      them max_shield), tight pack discipline (bounding overwatch: one element
      suppresses the LKP while another flanks), disciplined trigger control,
      flashlight/vision-cone patrols on real routes, and their own medic or
      shield-restore support unit. Should feel like fighting a mirror of your
      own squad. Asset candidates (verified): POLYGON_Spy_Kit,
      POLYGON_BattleRoyale, POLYGON_Mech (heavy support walker?), with
      POLYGON_Military_Warehouse for their turf.
