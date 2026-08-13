## Runtime navmesh baking. Levels and harnesses call bake() after their
## static geometry is in the tree; sources are whatever sits in the
## "navigation_mesh_source_group" group (cover props carve holes).
##
## The mesh is registered with NavigationServer3D directly instead of through
## a NavigationRegion3D node: an in-place runtime bake does not reliably push
## its polygons into the map through the node (observed on 4.7.1 — the region
## reports polygons, the map stays empty), while a server-level region works.
class_name NavRuntime
extends RefCounted

const SOURCE_GROUP := "navigation_mesh_source_group"

## Bake from static colliders in SOURCE_GROUP and register on the world map.
## Returns the region RID (callers may free it on level teardown; maps are
## per-World3D, so scene changes drop it anyway).
static func bake(root: Node3D, collision_mask: int, agent_radius := 0.4) -> RID:
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.geometry_collision_mask = collision_mask
	mesh.agent_radius = agent_radius
	region.navigation_mesh = mesh
	root.add_child(region)
	region.bake_navigation_mesh(false)
	var rid := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(rid, root.get_world_3d().navigation_map)
	NavigationServer3D.region_set_transform(rid, Transform3D())
	NavigationServer3D.region_set_navigation_mesh(rid, region.navigation_mesh)
	region.queue_free()
	return rid
