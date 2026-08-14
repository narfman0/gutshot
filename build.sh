#!/usr/bin/env bash
# One-shot, idempotent build: everything between "git clone" and "godot".
#
#   ./build.sh          # audio → assets → import; safe to re-run any time,
#                       # each step skips work that's already done
#   ./build.sh test     # build, then run every headless harness (exit 1 on
#                       # first failure) — the pre-commit sanity check
#
# Steps:
#   1. tools/gen_audio.py   — regenerated only when the script is newer than
#                             its outputs (WAVs are committed, so normally a
#                             no-op)
#   2. fetch_assets.sh      — used-only closure fetch from the asset server;
#                             skips files already present
#   3. godot --headless --import
set -euo pipefail
cd "$(dirname "$0")"

# ── 1. Placeholder audio ─────────────────────────────────────────────────────
if [[ ! -f assets/audio/sfx_impact.wav || tools/gen_audio.py -nt assets/audio/sfx_impact.wav ]]; then
	echo "== gen_audio"
	python3 tools/gen_audio.py
else
	echo "== gen_audio (up to date)"
fi

# ── 2. Synty assets ──────────────────────────────────────────────────────────
echo "== fetch_assets"
./fetch_assets.sh

# ── 3. Godot import ──────────────────────────────────────────────────────────
echo "== import"
godot --headless --import >/dev/null 2>&1 || true
echo "Build ready. Run: godot"

# ── Optional: headless test suite ────────────────────────────────────────────
if [[ "${1:-}" == "test" ]]; then
	echo "== tests"
	for t in resources_smoke combat_smoke ai_probe district_world_smoke district_combat_smoke district_respawn_smoke district_pursuit_smoke district_progression_smoke; do
		echo "-- $t"
		if ! out=$(godot --headless "res://future/tests/harnesses/$t.tscn" 2>&1); then
			echo "$out" | grep -E "FAIL|FAILURES" || echo "$out" | tail -5
			echo "FAILED: $t"
			exit 1
		fi
		echo "$out" | grep -E "ALL PASS"
	done
	echo "-- rig_probe"
	godot --headless --script res://future/tests/harnesses/rig_probe.gd 2>/dev/null \
		| grep -E "ALL PASS" || { echo "FAILED: rig_probe"; exit 1; }
	echo "All suites pass."
fi
