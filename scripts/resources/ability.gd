## Abstract ability Resource — docs/architecture.md §Ability System.
## Gear items export arrays of these; equipping gear registers them into the
## owning character's action_slots. Subclass and override activate(); no
## Character or HUD changes needed for new ability types.
class_name Ability
extends Resource

@export var display_name := "Ability"
@export var cooldown := 5.0
@export var icon: Texture2D

## Perform the ability. `target_point` is a world-space position (cursor
## ground point for player casts, a tactical position for AI casts).
## Return false if the cast could not start (caller won't consume cooldown).
func activate(_caster: Node, _target_point: Vector3) -> bool:
	push_warning("Ability.activate() not overridden: " + display_name)
	return false
