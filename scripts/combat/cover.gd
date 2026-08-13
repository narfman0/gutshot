## Tiered cover — proportional to exposed body, raycast-based.
## exposure() casts from the shooter's muzzle to the target's five body sample
## points (head, chest, pelvis, shoulders) against layer-2 cover geometry and
## returns the unblocked fraction. Tier thresholds map that fraction onto an
## accuracy multiplier: exposed shots are unmodified, half cover halves hit
## chance, full cover means the shot cannot be taken at all (grenades are the
## counterplay — their AoE ignores cover on purpose).
class_name Cover
extends RefCounted

const EXPOSED_MIN := 0.75      # unblocked fraction above which target is exposed
const FULL_COVER_MAX := 0.25   # at or below: no line on the target, no shot
const HALF_COVER_MULT := 0.5   # accuracy multiplier in the half-cover band

## Unblocked fraction [0..1] of the target's body from `shooter_muzzle`.
static func exposure(shooter_muzzle: Vector3, target: Character) -> float:
	var space := target.get_world_3d().direct_space_state
	var pts := target.cover_points()
	if pts.is_empty():
		return 1.0
	var open := 0
	for p in pts:
		var query := PhysicsRayQueryParameters3D.create(shooter_muzzle, p, Layers.LOS_MASK)
		if space.intersect_ray(query).is_empty():
			open += 1
	return float(open) / float(pts.size())

## Accuracy multiplier for an exposure fraction; 0.0 means "don't shoot".
static func accuracy_mult(exposure_frac: float) -> float:
	if exposure_frac <= FULL_COVER_MAX:
		return 0.0
	if exposure_frac < EXPOSED_MIN:
		return HALF_COVER_MULT
	return 1.0

static func can_hit(shooter_muzzle: Vector3, target: Character) -> bool:
	return exposure(shooter_muzzle, target) > FULL_COVER_MAX
