## Direct control for the active squad member — WASD run-and-gun.
## WASD moves (camera-relative); LMB on an enemy sets a sticky target that the
## active weapon auto-fires at while in range/LOS (accuracy dips while moving);
## holding LMB on ground still walks there (secondary); RMB clears the target;
## 1/2/3 switch weapon slots. With the thrown slot (grenades) active, LMB
## throws at the cursor point instead.
class_name PlayerController
extends Node

# Snappier than wayfarer on purpose: near-instant accel, instant-ish stop.
const SPEED := 6.0
const SPRINT_MUL := 1.5
const ACCEL := 60.0
const STOP_ACCEL := 40.0
const GRAVITY := 9.8
const ARRIVE_DIST := 0.4
const HOLD_REISSUE_SECS := 0.14

var enabled := false:
	set(value):
		enabled = value
		if not enabled:
			_click_target = Vector3.INF
			_lmb_held = false

var body: Character
var shooter: Shooter

var target_enemy: Character = null  # sticky: survives ground clicks

var _lmb_held := false
var _hold_timer := 0.0
var _mouse_pos := Vector2.ZERO
var _click_target := Vector3.INF

func _ready() -> void:
	body = get_parent() as Character
	shooter = body.get_node("Shooter")

func _physics_process(delta: float) -> void:
	if not enabled or body == null or not body.is_alive():
		return

	if _lmb_held:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_hold_timer = HOLD_REISSUE_SECS
			_handle_left_click(_mouse_pos)

	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta

	var stick := _read_input()
	var speed := SPEED * (SPRINT_MUL if Input.is_action_pressed("sprint") else 1.0)
	if stick.length_squared() > 0.01:
		_click_target = Vector3.INF
		var dir := _camera_relative(stick)
		body.velocity.x = move_toward(body.velocity.x, dir.x * speed, ACCEL * delta)
		body.velocity.z = move_toward(body.velocity.z, dir.z * speed, ACCEL * delta)
	elif _click_target != Vector3.INF:
		var to_target := _click_target - body.global_position
		to_target.y = 0.0
		if to_target.length() <= ARRIVE_DIST:
			_click_target = Vector3.INF
		else:
			var dir := to_target.normalized()
			body.velocity.x = move_toward(body.velocity.x, dir.x * speed, ACCEL * delta)
			body.velocity.z = move_toward(body.velocity.z, dir.z * speed, ACCEL * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, speed * STOP_ACCEL * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, speed * STOP_ACCEL * delta)
	body.move_and_slide()

	# Face the sticky target while it lives; otherwise face movement.
	if target_enemy != null and (not is_instance_valid(target_enemy) or not target_enemy.is_alive()):
		target_enemy = null
	if target_enemy != null:
		_face(target_enemy.global_position)
	elif Vector2(body.velocity.x, body.velocity.z).length() > 0.5:
		_face(body.global_position + body.velocity)

	# Sticky auto-fire with the active gun.
	if target_enemy != null and body.active_gear() != null \
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
				_hold_timer = HOLD_REISSUE_SECS
				_handle_left_click(event.position)
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

func _handle_left_click(screen_pos: Vector2) -> void:
	var hit := _pick(screen_pos)
	if hit.is_empty():
		return
	var gear := body.active_gear()
	if gear != null and gear.fire_mode == GearItem.FireMode.THROWN:
		# Grenade slot: LMB lobs at the cursor point, wherever it lands.
		var point: Vector3 = hit["position"]
		if not gear.abilities.is_empty():
			body.activate_ability(gear.abilities[0], point)
			_lmb_held = false  # one throw per click
		return
	var collider = hit["collider"]
	if collider is Character and (collider as Character).team != body.team \
			and (collider as Character).is_alive():
		target_enemy = collider
		return
	_click_target = hit["position"]

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
