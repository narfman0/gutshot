## Direct control for the active squad member — WASD run-and-gun.
## WASD is the ONLY movement (camera-relative, Doom-snappy: max speed almost
## instantly, hard stop). LMB on an enemy sets a sticky target that the active
## weapon auto-fires at while in range/LOS (accuracy dips while moving); RMB
## clears the target; 1/2/3 switch weapon slots. With the thrown slot
## (grenades) active, LMB throws at the cursor point instead.
class_name PlayerController
extends Node

const SPEED := 7.5
const SPRINT_MUL := 1.5
const ACCEL := 400.0       # reach max speed in ~a frame — think Doom
const STOP_ACCEL := 400.0  # and stop just as hard
const GRAVITY := 9.8
const RETARGET_SECS := 0.14  # cursor re-pick cadence while LMB is held

var enabled := false:
	set(value):
		enabled = value
		if not enabled:
			_lmb_held = false

var body: Character
var shooter: Shooter

var target_enemy: Character = null  # survives until RMB, death, or switch

var _lmb_held := false
var _retarget_timer := 0.0
var _mouse_pos := Vector2.ZERO

func _ready() -> void:
	body = get_parent() as Character
	shooter = body.get_node("Shooter")

func _physics_process(delta: float) -> void:
	if not enabled or body == null or not body.is_alive():
		return

	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta

	var stick := _read_input()
	var speed := SPEED * (SPRINT_MUL if Input.is_action_pressed("sprint") else 1.0)
	if stick.length_squared() > 0.01:
		var dir := _camera_relative(stick)
		body.velocity.x = move_toward(body.velocity.x, dir.x * speed, ACCEL * delta)
		body.velocity.z = move_toward(body.velocity.z, dir.z * speed, ACCEL * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, STOP_ACCEL * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, STOP_ACCEL * delta)
	body.move_and_slide()

	# Drop dead/freed targets.
	if target_enemy != null and (not is_instance_valid(target_enemy) or not target_enemy.is_alive()):
		target_enemy = null
	# While LMB is held, keep re-picking under the cursor (drag across enemies
	# to retarget) and fire; releasing the button stops the shooting.
	if _lmb_held:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = RETARGET_SECS
			_pick_target(_mouse_pos)
	if target_enemy != null:
		_face(target_enemy.global_position)
	elif Vector2(body.velocity.x, body.velocity.z).length() > 0.5:
		_face(body.global_position + body.velocity)
	if _lmb_held and target_enemy != null and body.active_gear() != null \
			and body.active_gear().fire_mode != GearItem.FireMode.THROWN:
		shooter.try_fire(target_enemy)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or body == null or not body.is_alive():
		return
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_held = true
				_retarget_timer = 0.0
				_on_lmb_pressed(event.position)
			else:
				_lmb_held = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			target_enemy = null
	elif event.is_action_pressed("weapon_1"):
		body.select_slot(0)
	elif event.is_action_pressed("weapon_2"):
		body.select_slot(1)
	elif event.is_action_pressed("weapon_3"):
		body.select_slot(2)

func _on_lmb_pressed(screen_pos: Vector2) -> void:
	var gear := body.active_gear()
	if gear != null and gear.fire_mode == GearItem.FireMode.THROWN:
		# Grenade slot: LMB lobs at the cursor point, one throw per click.
		var hit := _pick(screen_pos)
		if not hit.is_empty() and not gear.abilities.is_empty():
			body.activate_ability(gear.abilities[0], hit["position"])
		_lmb_held = false
		return
	_pick_target(screen_pos)

func _pick_target(screen_pos: Vector2) -> void:
	var hit := _pick(screen_pos)
	if hit.is_empty():
		return
	var collider = hit["collider"]
	if collider is Character and (collider as Character).team != body.team \
			and (collider as Character).is_alive():
		target_enemy = collider

func _pick(screen_pos: Vector2) -> Dictionary:
	var camera := body.get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, Layers.CLICK_MASK)
	return body.get_world_3d().direct_space_state.intersect_ray(query)

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
