## Runtime navmesh baking. Levels and harnesses call bake() after their
## static geometry is in the tree; sources are whatever sits in the
## "navigation_mesh_source_group" group (cover props carve holes).
##
## The mesh is registered with NavigationServer3D directly instead of through
## a NavigationRegion3D node: an in-place runtime bake does not reliably push
## its polygons into the map through the node (observed on 4.7.1 — the region
## reports polygons, the map stays empty), while a server-level region works.
##
## `aabb` (non-empty) bakes only geometry inside it (filter_baking_aabb).
## The seamless district bakes one region PER SITE/CORRIDOR this way — a
## single 280×200 m bake takes minutes, five site-sized ones take a blink —
## and the map's edge-connection margin stitches adjacent regions together.
##
## bake() is synchronous (load time); bake_async() bakes on a thread and
## must be awaited — used for in-fight rebakes (breach doors) so a bake
## never hitches a frame. The old mesh stays live until the caller swaps.
class_name NavRuntime
extends RefCounted

const SOURCE_GROUP := "navigation_mesh_source_group"

static func bake(root: Node3D, collision_mask: int, agent_radius := 0.4,
		aabb := AABB()) -> RID:
	var region := _make_region(root, collision_mask, agent_radius, aabb)
	region.bake_navigation_mesh(false)
	return _register(root, region)

static func bake_async(root: Node3D, collision_mask: int, agent_radius := 0.4,
		aabb := AABB()) -> RID:
	var region := _make_region(root, collision_mask, agent_radius, aabb)
	region.bake_navigation_mesh(true)
	await region.bake_finished
	return _register(root, region)

static func _make_region(root: Node3D, collision_mask: int, agent_radius: float,
		aabb: AABB) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.geometry_collision_mask = collision_mask
	mesh.agent_radius = agent_radius
	if aabb.has_volume():
		mesh.filter_baking_aabb = aabb
	region.navigation_mesh = mesh
	root.add_child(region)
	return region

static func _register(root: Node3D, region: NavigationRegion3D) -> RID:
	var rid := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(rid, root.get_world_3d().navigation_map)
	NavigationServer3D.region_set_transform(rid, Transform3D())
	NavigationServer3D.region_set_navigation_mesh(rid, region.navigation_mesh)
	region.queue_free()
	return rid
