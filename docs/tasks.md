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

### M1 polish backlog (nice-to-have, not blocking)
- [ ] Weapon grip orientation tuning (currently held at the side; fine at
      gameplay zoom)
- [ ] Aim-at-cursor facing while firing on the move (currently faces target)
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
- [ ] Enemy patrol routes + alert states (extend EnemyController IDLE)
- [ ] Camera floor transitions; hide geometry above active floor
- [ ] Audio pass (AudioManager autoload, wayfarer `gen_audio.py` lineage)
- [ ] Main menu + pause; save/load stub honoring `GameState.debug_session`
