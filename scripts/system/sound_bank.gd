## The sound bank — logical cue → the real recordings behind it.
##
## Every entry is a LIST, and AudioManager picks a different one each time.
## That is the whole point: the fatiguing thing about placeholder audio is
## not that a synthesized impact sounds fake, it is that the SAME impact
## fires forty times a fight. Variants fix that before fidelity does.
##
## Paths are full res:// literals so fetch_assets.sh resolves them out of the
## asset server's raw tree (see its SFX_PREFIX mapping). Anything not listed
## here falls back to the synthesized assets/audio/sfx_<key>.wav that
## tools/gen_audio.py writes — gunfire still does, deliberately: the library
## is a sci-fi set with no ballistic recordings, and purpose-built synth
## beats a laser pretending to be a pistol.
class_name SoundBank

const CUES := {
	# The Assembly SPEAKS. Machine custodians warn before they escalate —
	# that posture is in the design and was, until now, inaudible.
	"machine_warn": [
		"res://assets/audio/sfx/Synth Voice 2/Audio/lowerYourWeapon.ogg",
		"res://assets/audio/sfx/Synth Voice 2/Audio/dropYourWeapon.ogg",
		"res://assets/audio/sfx/Synth Voice 2/Audio/stop.ogg",
		"res://assets/audio/sfx/Synth Voice 2/Audio/defendYourPosition.ogg",
	],
	"machine_engage": [
		"res://assets/audio/sfx/Synth Voice 2/Audio/engagingWithAgressiveTactics.ogg",
		"res://assets/audio/sfx/Synth Voice 2/Audio/targetEngaged.ogg",
		"res://assets/audio/sfx/Synth Voice 2/Audio/attackMyTarget.ogg",
		"res://assets/audio/sfx/Synth Voice 2/Audio/callForBackup.ogg",
	],
	# synthesized, three variants — see tools/gen_audio.py GUNS
	"shot_smg": [
		"res://assets/audio/sfx_shot_smg_a.wav",
		"res://assets/audio/sfx_shot_smg_b.wav",
		"res://assets/audio/sfx_shot_smg_c.wav",
	],
	# synthesized, three variants — see tools/gen_audio.py GUNS
	"shot_rifle": [
		"res://assets/audio/sfx_shot_rifle_a.wav",
		"res://assets/audio/sfx_shot_rifle_b.wav",
		"res://assets/audio/sfx_shot_rifle_c.wav",
	],
	# synthesized, three variants — see tools/gen_audio.py GUNS
	"shot_pistol": [
		"res://assets/audio/sfx_shot_pistol_a.wav",
		"res://assets/audio/sfx_shot_pistol_b.wav",
		"res://assets/audio/sfx_shot_pistol_c.wav",
	],
	# a round finding a body — soft, close, not metallic
	"impact": [
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_medium_000.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_medium_001.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_medium_002.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_medium_003.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_medium_004.ogg",
	],
	# a round finding cover, a machine, a roller door
	"impact_metal": [
		"res://assets/audio/sfx/Impact Sounds/Audio/impactMetal_light_000.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactMetal_light_001.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactMetal_light_002.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactMetal_light_003.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactMetal_light_004.ogg",
	],
	# the shield layer eating it
	"shield_hit": [
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/forceField_000.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/forceField_001.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/forceField_002.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/forceField_003.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/forceField_004.ogg",
	],
	# frag, breach charges, a core going out
	"explosion": [
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/explosionCrunch_000.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/explosionCrunch_001.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/explosionCrunch_002.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/explosionCrunch_003.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/explosionCrunch_004.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/lowFrequency_explosion_000.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/lowFrequency_explosion_001.ogg",
	],
	# boots hitting deck after a drop
	"land": [
		"res://assets/audio/sfx/Impact Sounds/Audio/impactPlate_heavy_000.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactPlate_heavy_001.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactPlate_heavy_002.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactPlate_heavy_003.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactPlate_heavy_004.ogg",
	],
	# the district is concrete and plate, everywhere
	"footstep": [
		"res://assets/audio/sfx/Impact Sounds/Audio/footstep_concrete_000.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/footstep_concrete_001.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/footstep_concrete_002.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/footstep_concrete_003.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/footstep_concrete_004.ogg",
	],
	# someone hitting the floor
	"down": [
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_heavy_000.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_heavy_001.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_heavy_002.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_heavy_003.ogg",
		"res://assets/audio/sfx/Impact Sounds/Audio/impactSoft_heavy_004.ogg",
	],
	# the Assembly's arc cutters
	"shot_laser": [
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/laserSmall_000.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/laserSmall_001.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/laserSmall_002.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/laserSmall_003.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/laserSmall_004.ogg",
	],
	# breach doors and the tower seal
	"door_open": [
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/doorOpen_000.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/doorOpen_001.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/doorOpen_002.ogg",
	],
	"door_close": [
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/doorClose_000.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/doorClose_001.ogg",
		"res://assets/audio/sfx/Sci-Fi Sounds/Audio/doorClose_002.ogg",
	],
	# machine speech, corrupted
	"glitch": [
		"res://assets/audio/sfx/Interface Sounds/Audio/glitch_001.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/glitch_002.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/glitch_003.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/glitch_004.ogg",
	],
	# weapon swap
	"switch": [
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_001.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_002.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_003.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_004.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_005.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_006.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/switch_007.ogg",
	],
	# a magazine going home
	"reload": [
		"res://assets/audio/sfx/Interface Sounds/Audio/drop_001.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/drop_002.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/drop_003.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/drop_004.ogg",
	],
	# board and tree clicks
	"select": [
		"res://assets/audio/sfx/Interface Sounds/Audio/select_001.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/select_002.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/select_003.ogg",
		"res://assets/audio/sfx/Interface Sounds/Audio/select_004.ogg",
	],
	# steel finding someone
	"slash": [
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal1.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal2.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal3.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal4.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal5.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal6.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Swords/swordMetal7.ogg",
	],
	# steel finding air — the QUIET weapon, kept low in the mix
	"swing": [
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh1.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh2.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh3.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh4.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh5.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh6.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh7.ogg",
		"res://assets/audio/sfx/Foley Sounds/Audio/Woosh/woosh8.ogg",
	],
}

static func has(cue: String) -> bool:
	return CUES.has(cue)

## A random variant, or "" when the cue is not banked (caller falls back).
static func pick(cue: String) -> String:
	var list: Array = CUES.get(cue, [])
	if list.is_empty():
		return ""
	return str(list[randi() % list.size()])
