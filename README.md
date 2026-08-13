# Gutshot

A real-time tactical squad shooter set in grimdark cyberpunk hive cities — build your crew, gear up, and fight dirty.

- **Engine:** Godot 4.7 (Forward+)
- **Status:** Milestone 1 — playable skirmish
- **Docs:** See [docs/](docs/) for architecture, plan, narrative, and tasks.

## Quick Start

```bash
./fetch_assets.sh            # pull referenced Synty assets from the asset server
godot --headless --import    # first import
godot                        # play the skirmish
```

Controls: **WASD** move (camera-relative) · **mouse** aim · **LMB** on an enemy =
sticky target + auto-fire (hold LMB on ground to walk there) · **RMB** clear
target · **1/2/3** weapon slots (primary / pistol / grenades — with grenades
active, LMB lobs at the cursor) · **Tab** or portrait click switches crew ·
**wheel** zoom · **Esc** quit. Kill all hostiles before your crew drops.

Followers fight on their own — they take cover, pop out to burst, and flank,
leashed to whoever you're controlling.

### Tests

```bash
godot --headless res://future/tests/harnesses/m1_smoke.tscn        # end-to-end
godot --headless res://future/tests/harnesses/combat_smoke.tscn    # cover/accuracy
godot --headless res://future/tests/harnesses/ai_probe.tscn        # cover-seek/flank
godot --headless res://future/tests/harnesses/skirmish_smoke.tscn  # win/lose wiring
godot --headless res://future/tests/harnesses/resources_smoke.tscn # gear/abilities
godot --headless --script res://future/tests/harnesses/rig_probe.gd  # skins/anim
xvfb-run -a godot res://future/tests/harnesses/overview_shot.tscn  # screenshots
```

## Links

| Doc | Purpose |
|-----|---------|
| [docs/plan.md](docs/plan.md) | 4-phase development roadmap |
| [docs/architecture.md](docs/architecture.md) | Godot scene/system design |
| [docs/narrative.md](docs/narrative.md) | Setting and crew concept |
| [docs/tasks.md](docs/tasks.md) | Current task list |
