## Headless rig probe — run with:
##   godot --headless --script res://future/tests/harnesses/rig_probe.gd
## For each registered skin: prints the skeleton's rig family, and attaches
## the runtime animator to verify every clip retargets with real tracks.
## Prints "RIG_PROBE: ALL PASS" and exits 0 on success.
extends SceneTree

const Skins = preload("res://scripts/characters/skins.gd")
const Animator = preload("res://scripts/world/character_animator.gd")

func _init() -> void:
	var failures: Array[String] = []
	var all := {}
	all.merge(Skins.CREW)
	all.merge(Skins.ENEMIES)
	all.merge(Skins.MACHINES)
	for skin_name in all:
		var info: Dictionary = all[skin_name]
		var scene = load(info["path"])
		if scene == null:
			failures.append("%s: LOAD FAIL %s" % [skin_name, info["path"]])
			continue
		var body := CharacterBody3D.new()
		root.add_child(body)
		var skin: Node = scene.instantiate()
		skin.name = "Skin"
		body.add_child(skin)
		var skels: Array = skin.find_children("*", "Skeleton3D", true, false)
		if skels.is_empty():
			failures.append("%s: no Skeleton3D" % skin_name)
			body.free()
			continue
		var skel: Skeleton3D = skels[0]
		var rig := "unreal" if skel.find_bone("Pelvis") >= 0 else ("classic" if skel.find_bone("Hips") >= 0 else "UNKNOWN")
		print("=== %s  bones=%d rig=%s" % [skin_name, skel.get_bone_count(), rig])
		if rig == "UNKNOWN":
			var names := []
			for i in mini(skel.get_bone_count(), 12):
				names.append(skel.get_bone_name(i))
			failures.append("%s: unknown rig, bones: %s" % [skin_name, ", ".join(names)])
			body.free()
			continue
		var anim = Animator.attach(skin, body, info["set"])
		if anim == null:
			failures.append("%s: animator attach failed" % skin_name)
			body.free()
			continue
		var ap: AnimationPlayer = anim._ap
		var expected: Array = Animator.CLIPS[info["set"]].keys() + Animator.COMBAT_CLIPS.keys()
		for clip_name in expected:
			if not ap.has_animation(clip_name):
				failures.append("%s: clip missing: %s" % [skin_name, clip_name])
				continue
			var tracks := ap.get_animation(clip_name).get_track_count()
			print("    %-8s tracks=%d" % [clip_name, tracks])
			if tracks < 10:
				failures.append("%s: clip %s only %d tracks (retarget mismatch?)" % [skin_name, clip_name, tracks])
		body.free()
	if failures.is_empty():
		print("RIG_PROBE: ALL PASS")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		print("RIG_PROBE: %d FAILURES" % failures.size())
		quit(1)
