## Gear defines what a character can do — docs/architecture.md. A GearItem is
## a weapon (or thrown-device belt) that occupies one of the three loadout
## slots; its exported abilities register into the character's action_slots.
class_name GearItem
extends Resource

enum SlotType { PRIMARY, SECONDARY, HEAVY }
## MELEE: reach-gated swings (fire_range is arm's length), no ammo, QUIET —
## steel never trips hearing alerts, turf law, or muzzle-flash pins.
enum FireMode { HITSCAN, PROJECTILE, THROWN, MELEE }

@export var display_name := "Gear"
@export var slot_type: SlotType = SlotType.PRIMARY
@export var fire_mode: FireMode = FireMode.HITSCAN
## Heal weapon: fires at squadmates and restores `damage` HP per shot instead
## of hurting enemies (medic's heal gun).
@export var heals := false
## Heal variant that tops up SHIELDS instead of HP (the corp mender beam).
@export var restores_shield := false

@export var damage := 10.0
@export var fire_range := 20.0
## Shots per second.
@export var fire_rate := 4.0
## Chance [0..1] a shot connects at rest against an exposed target.
@export var base_accuracy := 0.8
## Multiplier applied to accuracy while the shooter is moving (run-and-gun).
@export var moving_accuracy_mult := 0.6
## Projectile speed (PROJECTILE and THROWN modes).
@export var projectile_speed := 18.0
## Rounds per magazine (reserves are infinite for now). 0 = no ammo system
## (thrown devices run on cooldowns instead).
@export var mag_size := 24
@export var reload_secs := 1.6
## Base name of the per-shot sound (sfx_<name>.wav in assets/audio/).
@export var shot_sfx := "shot_smg"

## Held weapon mesh (full res:// literal so fetch_assets.sh resolves it).
@export var mesh_path := ""
@export var icon: Texture2D

@export var abilities: Array[Ability] = []
