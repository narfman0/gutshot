## Headless audio probe — run with:
##   godot --headless --script res://future/tests/harnesses/audio_probe.gd
##
## The sound bank points at .ogg files fetched from the asset server and
## .gitignore'd, so a checkout that skipped fetch_assets.sh would quietly
## fall back to placeholder tones with nothing to say so. This checks that
## every banked cue actually resolves, that variants exist (one variant is a
## bank entry that buys nothing), and that every cue the game fires has SOME
## stream behind it.
extends SceneTree

## Every cue name passed to AudioManager.play_sfx anywhere in the game.
## Kept by hand on purpose: if you add a cue and forget this list, the probe
## can't catch a typo'd name, which is exactly the failure it exists for.
const FIRED := [
	"impact", "impact_metal", "shield_hit", "explosion", "reload", "switch",
	"heal", "land", "down", "revive", "telegraph", "swing", "slash",
	"levelup", "footstep", "door_open", "machine_warn", "machine_engage",
	"shot_smg", "shot_rifle", "shot_pistol", "shot_laser",
]

func _init() -> void:
	var failures: Array[String] = []
	var banked := 0
	var files := 0
	var missing: Array[String] = []

	for cue in SoundBank.CUES:
		banked += 1
		var list: Array = SoundBank.CUES[cue]
		if list.size() < 2:
			failures.append("cue '%s' has %d variant — a bank entry with one file buys nothing"
				% [cue, list.size()])
		for path in list:
			files += 1
			if not ResourceLoader.exists(str(path)):
				missing.append("%s → %s" % [cue, path])

	# Every cue the game fires must resolve to a banked variant OR a
	# synthesized WAV. Anything else is a silent cue in a shipped build.
	for cue in FIRED:
		var ok := false
		if SoundBank.has(str(cue)):
			var pick := SoundBank.pick(str(cue))
			ok = pick != "" and ResourceLoader.exists(pick)
		if not ok:
			ok = ResourceLoader.exists("res://assets/audio/sfx_%s.wav" % cue)
		if not ok:
			failures.append("cue '%s' resolves to NOTHING — it would play silence" % cue)

	print("audio: %d banked cues, %d sample files, %d cues fired by the game"
		% [banked, files, FIRED.size()])
	if not missing.is_empty():
		printerr("MISSING SAMPLES (run ./fetch_assets.sh):")
		for m in missing:
			printerr("   " + m)
		failures.append("%d banked sample(s) missing from disk" % missing.size())

	if failures.is_empty():
		print("AUDIO_PROBE: ALL PASS")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		print("AUDIO_PROBE: %d FAILURES" % failures.size())
		quit(1)
