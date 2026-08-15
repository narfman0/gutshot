## Headless pacing probe — run with:
##   godot --headless res://future/tests/harnesses/pacing_probe.tscn
##
## Progression numbers (XP_BASE/XP_EXPONENT, kill values, job payouts) are
## guesses until a human plays. This does not replace that — nothing tells
## you how a curve FEELS — but it stops tuning from being blind: it reads the
## district's ACTUAL roster and prints what the economy pays, how long each
## milestone takes, and what the alternatives would do.
##
## It reads the live world rather than hardcoding a model, so adding a pack
## or retuning a site's XP shows up here automatically instead of quietly
## invalidating the report.
##
## Two invariants it also ASSERTS, because they are design promises rather
## than taste:
##   - pushing into fresh content beats farming a respawning site
##   - the curve rises monotonically (no level cheaper than the one before)
extends Node

var _failures: Array[String] = []
var _world: GameWorld

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

## XP thresholds under arbitrary curve constants, so candidates can be
## compared without mutating GameState.
func _xp_to_next(level: int, base: float, expo: float) -> int:
	return int(round(base * pow(float(level), expo)))

func _threshold(level: int, base: float, expo: float) -> int:
	var total := 0
	for l in range(1, level):
		total += _xp_to_next(l, base, expo)
	return total

func _ready() -> void:
	GameState.squad = []
	GameState.debug_session = true  # never touch a real save slot
	GameState.start_site = "hideout"
	GameState.xp = 0
	GameState.crew_level = 1
	GameState.talents = {}
	GameState.cleared_sites = []
	_world = load("res://scenes/district.tscn").instantiate()
	add_child(_world)
	for i in 600:
		await get_tree().physics_frame
		if GameState.squad.size() == 4:
			break
	if GameState.squad.size() != 4:
		printerr("FAIL: crew never spawned — world boot broken")
		print("PACING_PROBE: 1 FAILURES")
		get_tree().quit(1)
		return
	for i in 20:
		await get_tree().physics_frame

	# ── What the district actually pays ──────────────────────────────────
	var per_site := {}   # site_id → {bodies, kill_xp}
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		var ec := node as EnemyController
		if ec == null or not is_instance_valid(ec.body):
			continue
		var site := _site_of(ec.body)
		var entry: Dictionary = per_site.get_or_add(site, {"bodies": 0, "kill_xp": 0})
		entry["bodies"] += 1
		entry["kill_xp"] += int(ec.body.get_meta("xp_value", 10))

	print("\n=== DISTRICT ECONOMY (live roster) ===")
	print("%-14s %7s %9s %11s %11s" % ["site", "bodies", "kills xp",
		"1st clear", "repeat"])
	var total_first := 0
	var site_ids: Array = per_site.keys()
	site_ids.sort()
	for site in site_ids:
		var e: Dictionary = per_site[site]
		var first: int = int(e["kill_xp"]) + GameWorld.FIRST_CLEAR_XP
		var repeat: int = int(float(e["kill_xp"]) * 0.5)
		total_first += first
		print("%-14s %7d %9d %11d %11d" % [site, int(e["bodies"]),
			int(e["kill_xp"]), first, repeat])
	print("%-14s %7s %9s %11d" % ["ALL SITES", "", "", total_first])

	var job_xp := 0
	for id in Jobs.CATALOG:
		job_xp += int(Jobs.CATALOG[id].get("xp", 0))
	print("jobs on the board: %d, paying %d total (avg %d)"
		% [Jobs.CATALOG.size(), job_xp, job_xp / maxi(1, Jobs.CATALOG.size())])

	# ── Session profiles ─────────────────────────────────────────────────
	# Rough shapes of an hour's play. The point is relative, not absolute.
	var avg_first := int(float(total_first) / maxf(1.0, float(per_site.size())))
	var avg_repeat := 0
	for site in site_ids:
		avg_repeat += int(float(per_site[site]["kill_xp"]) * 0.5)
	@warning_ignore("integer_division")
	avg_repeat = avg_repeat / maxi(1, per_site.size())
	var avg_job := job_xp / maxi(1, Jobs.CATALOG.size())

	var profiles := {
		"push (fresh site + job)": avg_first + avg_job,
		"explore (two fresh sites)": avg_first * 2,
		"farm (three repeat clears)": avg_repeat * 3,
	}
	print("\n=== SESSION PROFILES (xp per session) ===")
	for name in profiles:
		print("  %-28s %6d" % [name, int(profiles[name])])

	# ── Milestones under the live curve ──────────────────────────────────
	var base := GameState.XP_BASE
	var expo := GameState.XP_EXPONENT
	var push: int = int(profiles["push (fresh site + job)"])
	print("\n=== MILESTONES (live curve: base %.0f, exp %.2f) ===" % [base, expo])
	print("%-8s %10s %12s %14s" % ["level", "step xp", "total xp", "push sessions"])
	for lvl in [2, 5, 12, 22, 35, GameState.LEVEL_CAP]:
		var total := _threshold(lvl, base, expo)
		var tier := ""
		for t in Talents.TIER_LEVEL:
			if int(Talents.TIER_LEVEL[t]) == lvl:
				tier = "  ← tier %d opens" % int(t)
		print("%-8d %10d %12d %14.1f%s" % [lvl, _xp_to_next(lvl - 1, base, expo),
			total, float(total) / maxf(1.0, float(push)), tier])

	# ── Where a real player actually ENDS UP ─────────────────────────────
	# The number that decides whether a tier gate is reachable content or
	# decoration. Tier levels should sit where players will actually be.
	print("\n=== LEVEL REACHED AFTER N PUSH SESSIONS (live curve) ===")
	for sessions in [1, 5, 10, 20, 40, 80]:
		var pool: int = push * int(sessions)
		var lvl := 1
		while lvl < GameState.LEVEL_CAP and pool >= _threshold(lvl + 1, base, expo):
			lvl += 1
		var open_tiers := 0
		for t in Talents.TIER_LEVEL:
			if lvl >= int(Talents.TIER_LEVEL[t]):
				open_tiers += 1
		print("  %3d sessions (%7d xp) → level %2d, %d of %d tiers open"
			% [sessions, pool, lvl, open_tiers, Talents.TIER_LEVEL.size()])

	# ── Candidate curves ─────────────────────────────────────────────────
	print("\n=== CURVE CANDIDATES (push sessions to reach level N) ===")
	print("%-16s %8s %8s %8s %8s" % ["base / exp", "L5", "L12", "L22", "L50"])
	for cand in [[base, expo], [15.0, 1.6], [25.0, 1.45], [40.0, 1.6], [25.0, 1.75]]:
		var b: float = cand[0]
		var e: float = cand[1]
		print("%-16s %8.1f %8.1f %8.1f %8.1f%s" % [
			"%.0f / %.2f" % [b, e],
			float(_threshold(5, b, e)) / push, float(_threshold(12, b, e)) / push,
			float(_threshold(22, b, e)) / push, float(_threshold(50, b, e)) / push,
			"   (live)" if is_equal_approx(b, base) and is_equal_approx(e, expo) else ""])

	# ── Invariants ───────────────────────────────────────────────────────
	_check(avg_job > avg_repeat,
		"a job (%d) pays better than re-farming a cleared site (%d) — pushing must beat grinding"
		% [avg_job, avg_repeat])
	_check(avg_first > avg_repeat,
		"a first clear (%d) beats a repeat clear (%d)" % [avg_first, avg_repeat])
	var rising := true
	for l in range(1, GameState.LEVEL_CAP - 1):
		if _xp_to_next(l + 1, base, expo) < _xp_to_next(l, base, expo):
			rising = false
	_check(rising, "the curve never gets cheaper as it climbs")
	_check(GameState.talent_points_total() == 0 or GameState.crew_level > 1,
		"a level-1 crew has no points to spend")

	print("")
	if _failures.is_empty():
		print("PACING_PROBE: ALL PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("PACING_PROBE: %d FAILURES" % _failures.size())
		get_tree().quit(1)

## Which site's bounds a body stands in ("" for corridors).
func _site_of(body: Character) -> String:
	var p := Vector2(body.global_position.x, body.global_position.z)
	for chunk in _world.get_node("Level").get_children():
		if chunk is SiteChunk and (chunk as SiteChunk).bounds_rect().grow(2.0).has_point(p):
			return (chunk as SiteChunk).site_id()
	return "(corridor)"
