## Plays retargeted Synty clips on a character's skin. Attach via attach();
## picks a directional run clip (forward / strafe / backpedal) from the body's
## velocity relative to its facing — run-and-gun characters face their target
## while moving any direction, so strafes carry the readability.
class_name CharacterAnimator
extends Node

const _Retarget = preload("res://scripts/world/anim_retarget.gd")

const _ANIM_ROOT := "res://assets/meshes/ANIMATION_Base_Locomotion_SourceFiles_v3/SourceFiles/Animations/Polygon/"
const CLIPS := {
	"masc": {
		"idle": _ANIM_ROOT + "Masculine/Idle/A_Idle_Standing_Masc.glb",
		"run_f": _ANIM_ROOT + "Masculine/Locomotion/Run/A_Run_F_Masc.glb",
		"run_l": _ANIM_ROOT + "Masculine/Locomotion/Run/A_Run_FwdStrafeL_Masc.glb",
		"run_r": _ANIM_ROOT + "Masculine/Locomotion/Run/A_Run_FwdStrafeR_Masc.glb",
		"run_b": _ANIM_ROOT + "Masculine/Locomotion/Run/A_Run_BckStrafeB_Masc.glb",
	},
	"femn": {
		"idle": _ANIM_ROOT + "Feminine/Idle/A_Idle_Standing_Femn.glb",
		"run_f": _ANIM_ROOT + "Feminine/Locomotion/Run/A_Run_F_Femn.glb",
		"run_l": _ANIM_ROOT + "Feminine/Locomotion/Run/A_Run_FwdStrafeL_Femn.glb",
		"run_r": _ANIM_ROOT + "Feminine/Locomotion/Run/A_Run_FwdStrafeR_Femn.glb",
		"run_b": _ANIM_ROOT + "Feminine/Locomotion/Run/A_Run_BckStrafeB_Femn.glb",
	},
}

## Sword Combat pack one-shots, shared by every humanoid. Hit-reacts and
## deaths are weapon-agnostic enough for gunfire; there is no gun animation
## pack on the asset server (known gap — shooting itself is procedural recoil
## + muzzle flash). Full res:// literals on purpose — fetch_assets.sh's
## used-only scan picks up complete assets/meshes paths anywhere in the project.
const COMBAT_CLIPS := {
	"hit": "res://assets/meshes/ANIMATION_Sword_Combat_SourceFiles_v5/SourceFiles/Animations/Polygon/Hit/HitReact/A_Hit_F_React_Sword.gltf",
	"death": "res://assets/meshes/ANIMATION_Sword_Combat_SourceFiles_v5/SourceFiles/Animations/Polygon/Death/A_Death_F_01_Sword.gltf",
}

const _RUN_THRESHOLD := 0.5  # m/s below which locomotion is idle

## Marks a skin whose 180° facing correction has been applied, and caches the
## animator built for it. Both guards keep attach() idempotent — the spin is a
## relative `+= PI`, so a second call would cancel it and render the character
## back-to-front (and stack a second AnimationPlayer on the skin).
const _SPUN_META := "gutshot_skin_spun"
const _ANIM_META := "gutshot_animator"

var _body: CharacterBody3D = null  # null → static idle (props/preview)
var _ap: AnimationPlayer
var _current := ""
var _oneshot_until_ms := 0  # locomotion won't stomp a playing combat clip

## Build an animator under `skin` (a Synty character glTF instance).
## body: pass the CharacterBody3D to drive locomotion from velocity, or null.
## Safe to call more than once per skin — repeat calls return the first animator.
static func attach(skin: Node, body: CharacterBody3D = null, set_key: String = "masc") -> CharacterAnimator:
	if skin.has_meta(_ANIM_META):
		return skin.get_meta(_ANIM_META) as CharacterAnimator
	_orient_skin(skin)
	var skels: Array = skin.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	# Some packs (Gang_Warfare) ship an AnimationPlayer inside the skin glTF;
	# left active it fights ours for bone poses every frame.
	for existing in skin.find_children("*", "AnimationPlayer", true, false):
		(existing as AnimationPlayer).active = false
	var anim := CharacterAnimator.new()
	anim._body = body
	anim._ap = AnimationPlayer.new()
	skin.add_child(anim._ap)
	skin.add_child(anim)
	var skel_path := str(skin.get_path_to(skels[0]))
	var lib := AnimationLibrary.new()
	for clip_name in CLIPS[set_key]:
		var clip: Animation = _Retarget.load_clip(CLIPS[set_key][clip_name], skel_path, skels[0])
		if clip != null:
			lib.add_animation(clip_name, clip)
	for clip_name in COMBAT_CLIPS:
		var clip: Animation = _Retarget.load_clip(COMBAT_CLIPS[clip_name], skel_path, skels[0])
		if clip != null:
			lib.add_animation(clip_name, clip)
	anim._ap.add_animation_library("", lib)
	anim._play("idle")
	skin.set_meta(_ANIM_META, anim)
	return anim

## Fire-and-forget combat clip on a body's skin ("hit", "death"). Returns
## false when the body has no animator or the clip didn't load (callers keep
## their procedural fallback in that case). speed: playback multiplier.
## release_frac: fraction of the (scaled) clip after which locomotion may
## resume — the cancelable recovery window.
static func oneshot(body: Node, clip_name: String, speed: float = 1.0,
		release_frac: float = 1.0) -> bool:
	if body == null:
		return false
	var skin := body.get_node_or_null("Skin")
	if skin == null or not skin.has_meta(_ANIM_META):
		return false
	var anim := skin.get_meta(_ANIM_META) as CharacterAnimator
	if anim == null:
		return false
	return anim.play_oneshot(clip_name, speed, release_frac)

## Synty POLYGON meshes are authored facing +Z, but Godot's facing/movement
## convention is -Z forward. Left as-is the skin shows its back; spin it 180°
## so the visible front matches body facing. Guarded by meta so it lands
## exactly once even if attach() bails early below (a skin with no Skeleton3D
## still needs the correct facing).
static func _orient_skin(skin: Node) -> void:
	if not (skin is Node3D) or skin.has_meta(_SPUN_META):
		return
	(skin as Node3D).rotation.y += PI
	skin.set_meta(_SPUN_META, true)

func _process(_delta: float) -> void:
	if _body == null or Time.get_ticks_msec() < _oneshot_until_ms:
		return
	var vel := Vector2(_body.velocity.x, _body.velocity.z)
	if vel.length() < _RUN_THRESHOLD:
		_play("idle")
		return
	# Movement direction in the body's local frame; -Z is forward.
	var local := _body.global_transform.basis.inverse() * Vector3(vel.x, 0.0, vel.y)
	var angle := rad_to_deg(atan2(local.x, -local.z))  # 0 fwd, +90 right, ±180 back
	if absf(angle) <= 50.0:
		_play("run_f")
	elif absf(angle) >= 130.0:
		_play("run_b")
	elif angle > 0.0:
		_play("run_r")
	else:
		_play("run_l")

## Play a combat clip once, then let locomotion resume. "death" locks the
## animator on its final frame forever (the collapse owns what follows).
## Locomotion resumes after release_frac of the scaled clip — moving before
## the follow-through finishes is the recovery-cancel.
func play_oneshot(clip_name: String, speed: float = 1.0, release_frac: float = 1.0) -> bool:
	if _ap == null or not _ap.has_animation(clip_name):
		return false
	speed = maxf(speed, 0.05)
	var length := _ap.get_animation(clip_name).get_length() / speed
	_current = clip_name
	_ap.play(clip_name, 0.1, speed)
	if clip_name == "death":
		_oneshot_until_ms = Time.get_ticks_msec() + 3600 * 1000
	else:
		_oneshot_until_ms = Time.get_ticks_msec() + int(length * release_frac * 1000.0)
	return true

func _play(clip_name: String) -> void:
	if _current == clip_name or _ap == null or not _ap.has_animation(clip_name):
		return
	_current = clip_name
	_ap.play(clip_name, 0.2)
