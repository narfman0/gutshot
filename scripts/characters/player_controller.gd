## Direct control for the active squad member — WASD run-and-gun.
## WASD is the ONLY movement (camera-relative, Doom-snappy). Hold LMB to fire
## toward the cursor immediately: the shot soft-acquires whichever enemy sits
## in a narrow cone along the aim line (the accuracy/cover model resolves it),
## and with nobody on the line the round still goes downrange. The heal gun
## acquires squadmates the same way; the grenade slot lobs at the cursor
## point. 1/2/3 switch weapon slots, R reloads.
class_name PlayerController
extends Node

const SPEED := 9.5
const SPRINT_MUL := 1.5
const ACCEL := 900.0        # max speed in a frame or two — think Doom
const STOP_ACCEL := 900.0   # and stop just as hard
const AIR_ACCEL := 160.0    # limited steering mid-air — momentum carries you
const AIR_DRAG := 30.0      # and letting go doesn't brake a fall
const AIM_CONE_DEG := 14.0  # soft-acquire half-angle around the aim line
## Footsteps ride on distance travelled, not a timer, so they stay in step
## with the legs at every speed instead of drifting when you sprint. Only the
## ACTIVE character makes them: the mix is non-positional, so thirty sets of
## boots would be mud rather than presence.
const STRIDE_METRES := 2.3

var enabled := false:
	set(value):
		enabled = value
		if not enabled:
			_lmb_held = false

var body: Character
var shooter: Shooter

var _lmb_held := false
var _mouse_pos := Vector2.ZERO

func _ready() -> void:
	body = get_parent() as Character
	shooter = body.get_node("Shooter")

var _stride := 0.0

func _physics_process(delta: float) -> void:
	if not enabled or body == null or not body.is_alive():
		return
	_tick_footsteps(delta)

	if not body.is_on_floor():
		body.velocity.y -= Character.GRAVITY * delta

	var stick := _read_input()
	var speed := SPEED * (SPRINT_MUL if Input.is_action_pressed("sprint") else 1.0) \
		* body.effect_speed_mult()
	var grounded := body.is_on_floor()
	if stick.length_squared() > 0.01:
		var dir := _camera_relative(stick)
		var accel := ACCEL if grounded else AIR_ACCEL
		body.velocity.x = move_toward(body.velocity.x, dir.x * speed, accel * delta)
		body.velocity.z = move_toward(body.velocity.z, dir.z * speed, accel * delta)
	else:
		var brake := STOP_ACCEL if grounded else AIR_DRAG
		body.velocity.x = move_toward(body.velocity.x, 0.0, brake * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, brake * delta)
	body.move_and_slide()

	var gear := body.active_gear()
	if _lmb_held and gear != null and gear.fire_mode != GearItem.FireMode.THROWN:
		var aim := _aim_point()
		_face(aim)
		if gear.heals:
			var ally := _acquire_in_cone(body.team, aim)
			if ally != null:
				shooter.try_heal(ally)
		else:
			# A click ALWAYS sends a round. Acquiring somebody is a bonus, not
			# a precondition: try_fire refuses when the target is in full
			# cover (Cover.can_hit), and the old code let that swallow the
			# shot entirely — you clicked at a man behind a crate and nothing
			# happened. fire_wild does its own rate/reload/ammo gating, so
			# falling through to it can't break the fire rate.
			var enemy := _acquire_hostile_in_cone(aim)
			if enemy == null or not shooter.try_fire(enemy):
				shooter.fire_wild(aim)
	elif Vector2(body.velocity.x, body.velocity.z).length() > 0.5:
		_face(body.global_position + body.velocity)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or body == null or not body.is_alive():
		return
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_held = true
				var gear := body.active_gear()
				if gear != null and gear.fire_mode == GearItem.FireMode.THROWN:
					# Grenade slot: LMB lobs at the aim point, one per click.
					if not gear.abilities.is_empty():
						body.activate_ability(gear.abilities[0], _aim_point())
					_lmb_held = false
			else:
				_lmb_held = false
	# The KIT bar — Q/E/F/C cast whatever the crew tree (and gear) has granted,
	# aimed at the cursor like everything else. Sits beside the 1/2/3 weapon
	# bar rather than inside it: gear is what you carry, the kit is what you
	# have learned.
	elif event.is_action_pressed("ability_1"):
		_cast_kit(0)
	elif event.is_action_pressed("ability_2"):
		_cast_kit(1)
	elif event.is_action_pressed("ability_3"):
		_cast_kit(2)
	elif event.is_action_pressed("ability_4"):
		_cast_kit(3)
	elif event.is_action_pressed("weapon_1"):
		body.select_slot(0)
	elif event.is_action_pressed("weapon_2"):
		body.select_slot(1)
	elif event.is_action_pressed("weapon_3"):
		body.select_slot(2)
	elif event.is_action_pressed("reload"):
		shooter.start_reload()

## Nearest target along the aim line: hostiles first; with no hostile on the
## line, a NEUTRAL under the cursor cone is a deliberate act — shooting the
## Assembly is allowed, and it provokes them.
func _acquire_hostile_in_cone(aim_point: Vector3) -> Character:
	var hostile := _acquire_in_cone(-1, aim_point, true)
	if hostile != null:
		return hostile
	return _acquire_in_cone(-1, aim_point, false)

## Living character nearest the body inside the aim cone. team >= 0 filters
## one faction (heal gun); team -1 + hostile_only filters by hostility.
func _acquire_in_cone(team: int, aim_point: Vector3, hostile_only := true) -> Character:
	var aim_dir := aim_point - body.global_position
	aim_dir.y = 0.0
	if aim_dir.length_squared() < 0.04:
		return null
	aim_dir = aim_dir.normalized()
	var cone := deg_to_rad(AIM_CONE_DEG)
	var best: Character = null
	var best_d := INF
	for node in body.get_tree().get_nodes_in_group("characters" if team < 0 else "team_%d" % team):
		var c := node as Character
		if c == null or c == body or not c.is_alive():
			continue
		if team < 0:
			if c.team == body.team:
				continue
			if hostile_only != Factions.hostile(body.team, c.team):
				continue
		var to_c := c.global_position - body.global_position
		to_c.y = 0.0
		var d := to_c.length()
		if d < 0.05 or d >= best_d:
			continue
		if aim_dir.angle_to(to_c / d) <= cone:
			best = c
			best_d = d
	return best

## Where the player is aiming, per camera mode. ISO: the point under the
## cursor. OTS (perspective camera): the point under the center reticle —
## a ray straight out of the camera. Both feed the SAME cone-acquire and
## accuracy/cover model; only the pointing device differs.
func _aim_point() -> Vector3:
	var camera := body.get_viewport().get_camera_3d()
	if camera != null and camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var from := camera.global_position
		var dir := -camera.global_transform.basis.z
		var query := PhysicsRayQueryParameters3D.create(
			from, from + dir * 200.0, Layers.GROUND | Layers.COVER)
		var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"]
		return from + dir * 60.0
	return _cursor_ground_point(_mouse_pos)

## World point under the cursor: ground hit first, y=0 plane as fallback so
## aiming past the arena edge still has a direction.
func _cursor_ground_point(screen_pos: Vector2) -> Vector3:
	var camera := body.get_viewport().get_camera_3d()
	if camera == null:
		return body.global_position + Vector3.FORWARD
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, Layers.GROUND)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	if absf(dir.y) > 0.0001:
		var t := -from.y / dir.y
		if t > 0.0:
			return from + dir * t
	return body.global_position + Vector3.FORWARD

## Cast kit slot `index`, if the crew has one there and it is off cooldown.
func _cast_kit(index: int) -> void:
	if body == null or index >= body.action_slots.size():
		return
	body.activate_ability(body.action_slots[index], _aim_point())

func _tick_footsteps(delta: float) -> void:
	if not body.is_on_floor():
		_stride = STRIDE_METRES * 0.6  # land already part-way to the next step
		return
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if speed < 0.5:
		return
	_stride += speed * delta
	if _stride >= STRIDE_METRES:
		_stride = 0.0
		AudioManager.play_sfx("footstep", -14.0, 0.12)

func _read_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

## Rotate stick input into the camera's yaw so W is always "screen up".
func _camera_relative(stick: Vector2) -> Vector3:
	var camera := body.get_viewport().get_camera_3d()
	var yaw := camera.global_rotation.y if camera != null else 0.0
	return Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, yaw)

func _face(point: Vector3) -> void:
	var dir := point - body.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		body.rotation.y = atan2(-dir.x, -dir.z)
