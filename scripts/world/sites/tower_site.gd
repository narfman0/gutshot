@tool
## Vantag Tower — the LOBBY (docs/locations.md: public floors, corporate
## security posture; going loud here burns the district). First slice of the
## capstone, styled on THE lobby scene: a grid of massive marble columns
## flanking a polished aisle, a security desk at the door, an elevator bank
## at the back, and a formal mezzanine balcony ringing the room — guards on
## the rail, guards at the desk. Corp-lite security (shields, no morale, no
## pursuit — they hold the lobby) until the real faction lands.
extends SiteChunk

const MEZZ_H := 4.0
const DECK_T := 0.35
const STAIR_TILT := 26.57

const MARBLE := Color(0.62, 0.63, 0.60)
const MARBLE_DIM := Color(0.50, 0.51, 0.49)
const FLOOR_MARBLE := Color(0.44, 0.46, 0.45)

func site_id() -> String:
	return "tower"

func site_name() -> String:
	return "VANTAG TOWER — LOBBY"

func arena_half() -> float:
	return 26.0

func ground_color() -> Color:
	return FLOOR_MARBLE

func ground_roughness() -> float:
	return 0.12  # polished stone — the district's one clean floor

func heals_crew() -> bool:
	return false

func sun_energy() -> float:
	return 1.4  # the lobby is LIT — money keeps the gloom outside

func fog_density() -> float:
	return 0.0015

func ambient() -> String:
	return "ambient_lobby"

func wall_color() -> Color:
	return Color(0.50, 0.50, 0.48)

func floor_heights() -> Array:
	return [0.0, MEZZ_H]

func gates() -> Array:
	return [{"side": "s", "center": -6.0}]  # the plaza from the street

## Even, white, corporate — no neon in here.
func flood_lights() -> Array:
	return [
		[Vector3(-16, 7, -16), Color(0.85, 0.9, 1.0)],
		[Vector3(16, 7, -16), Color(0.85, 0.9, 1.0)],
		[Vector3(0, 8, 0), Color(0.9, 0.93, 1.0)],
		[Vector3(0, 7, 16), Color(0.85, 0.9, 1.0)],
	]

func crew_spawns() -> Array:
	return [
		Vector3(-7.5, 0.1, 22.5), Vector3(-5.0, 0.1, 23.5),
		Vector3(-2.5, 0.1, 22.5), Vector3(-5.0, 0.1, 21.0),
	]

func enemy_spawns() -> Array:
	return [
		# The desk detail — suits with shield rigs, patrol the aisle.
		{"skin": "suit", "pos": Vector3(-2.0, 0.1, 13.0), "pack": "lobby",
			"shield": 30.0, "xp": 15, "aggro": 13.0, "pursue": false,
			"patrol": [Vector3(-6.0, 0.1, 8.0), Vector3(6.0, 0.1, 8.0)]},
		{"skin": "suit", "pos": Vector3(3.0, 0.1, 14.0), "pack": "lobby",
			"shield": 30.0, "xp": 15, "aggro": 13.0, "pursue": false},
		# The balcony watch — the mezzanine rail owns the floor below.
		{"skin": "suit", "pos": Vector3(-22.0, 4.15, 0.0), "pack": "balcony",
			"shield": 30.0, "xp": 15, "aggro": 16.0, "pursue": false,
			"patrol": [Vector3(-22.0, MEZZ_H, 10.0), Vector3(-22.0, MEZZ_H, -14.0)]},
		{"skin": "suit", "pos": Vector3(22.0, 4.15, -4.0), "pack": "balcony",
			"shield": 30.0, "xp": 15, "aggro": 16.0, "pursue": false,
			"patrol": [Vector3(22.0, MEZZ_H, 10.0), Vector3(22.0, MEZZ_H, -14.0)]},
		{"skin": "suit", "pos": Vector3(0.0, 4.15, -21.0), "pack": "balcony",
			"shield": 30.0, "xp": 15, "aggro": 16.0, "pursue": false,
			"patrol": [Vector3(-14.0, MEZZ_H, -22.0), Vector3(14.0, MEZZ_H, -22.0)]},
	]

func build_extra_geometry() -> void:
	_build_columns()
	_build_desk_and_door()
	_build_mezzanine()
	_build_elevators()
	add_neon_sign("VANTAG", Vector3(0.0, 5.9, -25.2), Color(0.88, 0.95, 1.0), 0.0, 110)

## Two ranks of marble columns flanking the central aisle — THE lobby read,
## and real chewable cover (COVER layer + cover group, navmesh carves).
func _build_columns() -> void:
	for x in [-6.0, 6.0]:
		for z in [-16.0, -9.0, -2.0, 5.0, 12.0]:
			_marble_box(Vector3(x, 0, z), Vector3(1.7, 4.6, 1.7), MARBLE, true)
			add_practical_light(Vector3(x, 3.9, z), Color(0.9, 0.94, 1.0), 0.9, 5.0)

func _build_desk_and_door() -> void:
	# The security desk — first cover past the doors, both directions.
	_marble_box(Vector3(0.5, 0, 16.5), Vector3(6.0, 1.1, 1.5), MARBLE_DIM, true)
	add_practical_light(Vector3(0.5, 1.6, 16.5), Color(0.8, 0.9, 1.0), 1.2, 5.0)
	# Metal-detector arch at the entrance — visual only; walking through it
	# is the point.
	for px in [-7.4, -4.6]:
		_marble_box(Vector3(px, 0, 20.5), Vector3(0.22, 2.3, 0.5), MARBLE_DIM, false)
	var lintel := _marble_box(Vector3(-6.0, 0, 20.5), Vector3(3.0, 0.2, 0.5), MARBLE_DIM, false)
	lintel.position.y = 2.3

## The balcony: marble decks on three sides at twice the exchange's height,
## marble balustrade, twin staircases hugging the side walls.
func _build_mezzanine() -> void:
	var deck_y := MEZZ_H - DECK_T * 0.5
	add_walkable_box(Vector3(0.0, deck_y, -22.0), Vector3(52.0, DECK_T, 8.0),
		0.0, 0.0, MARBLE_DIM, 0.02)   # north
	add_walkable_box(Vector3(-22.0, deck_y, -2.0), Vector3(8.0, DECK_T, 32.0),
		0.0, 0.0, MARBLE_DIM, 0.02)   # west
	add_walkable_box(Vector3(22.0, deck_y, -2.0), Vector3(8.0, DECK_T, 32.0),
		0.0, 0.0, MARBLE_DIM, 0.02)   # east
	add_rail(Vector3(0.0, MEZZ_H + 0.45, -18.0), Vector3(36.0, 0.9, 0.1),
		Color(0.66, 0.66, 0.63), 0.05)
	add_rail(Vector3(-18.0, MEZZ_H + 0.45, -2.0), Vector3(0.1, 0.9, 32.0),
		Color(0.66, 0.66, 0.63), 0.05)
	add_rail(Vector3(18.0, MEZZ_H + 0.45, -2.0), Vector3(0.1, 0.9, 32.0),
		Color(0.66, 0.66, 0.63), 0.05)
	# Staircases: floor at z≈22.6 rising north to the deck edge at z≈14.
	add_walkable_box(Vector3(-22.0, MEZZ_H * 0.5 - 0.175, 18.2),
		Vector3(4.0, DECK_T, 8.94), STAIR_TILT, 0.0, MARBLE_DIM, 0.02)
	add_walkable_box(Vector3(22.0, MEZZ_H * 0.5 - 0.175, 18.2),
		Vector3(4.0, DECK_T, 8.94), STAIR_TILT, 0.0, MARBLE_DIM, 0.02)

## The elevator bank under the north balcony — sealed. The rest of the
## tower is the campaign's problem.
func _build_elevators() -> void:
	for x in [-6.0, 0.0, 6.0]:
		var door := _marble_box(Vector3(x, 0, -25.3), Vector3(2.2, 2.7, 0.35),
			Color(0.35, 0.38, 0.40), false)
		var mi := door.get_child(0) as MeshInstance3D
		var mat := (mi.mesh as BoxMesh).material as StandardMaterial3D
		mat.metallic = 0.8
		mat.roughness = 0.25
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.8, 1.0)
		mat.emission_energy_multiplier = 0.12
		add_practical_light(Vector3(x, 2.6, -24.4), Color(0.6, 0.85, 1.0), 1.0, 4.0)

## A marble slab: mesh always; collider + cover group when `solid`.
func _marble_box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.COVER
		body.add_to_group("cover")
		body.add_to_group(NavRuntime.SOURCE_GROUP)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		col.position.y = size.y * 0.5
		body.add_child(col)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.18
	mat.metallic = 0.05
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	root.add_child(mi)
	gen_root().add_child(root)
	root.position = pos
	return root
