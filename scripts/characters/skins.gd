## Skin registry — full res:// literals on purpose so fetch_assets.sh's
## used-only scan resolves every skin (plus its .bin/textures) from the
## asset server. Crew are Gang_Warfare outlaws; M1 enemies are City_Characters
## street-gang stand-ins for the cult.
class_name Skins

## name → {path, set} where set picks the locomotion clip set ("masc"/"femn").
const CREW := {
	"leader": {"path": "res://assets/meshes/POLYGON_Gang_Warfare_Source_Files_v4/SourceFiles/FBX/Characters/SK_Chr_DEA_Plainclothes_Male_01.gltf", "set": "masc"},
	"gunner": {"path": "res://assets/meshes/POLYGON_Gang_Warfare_Source_Files_v4/SourceFiles/FBX/Characters/SK_Chr_GangMember_Male_02.gltf", "set": "masc"},
	"medic": {"path": "res://assets/meshes/POLYGON_Gang_Warfare_Source_Files_v4/SourceFiles/FBX/Characters/SK_Chr_StreetGirl_01.gltf", "set": "femn"},
	"hacker": {"path": "res://assets/meshes/POLYGON_Gang_Warfare_Source_Files_v4/SourceFiles/FBX/Characters/SK_Chr_Asian_Gangster_Male_01.gltf", "set": "masc"},
}

const ENEMIES := {
	"punk": {"path": "res://assets/meshes/POLYGON_City_Characters_SourceFiles_v2/Source_Files/Characters/SK_Character_PunkGuy.gltf", "set": "masc"},
	"biker": {"path": "res://assets/meshes/POLYGON_City_Characters_SourceFiles_v2/Source_Files/Characters/SK_Character_Biker.gltf", "set": "masc"},
	"gangster": {"path": "res://assets/meshes/POLYGON_City_Characters_SourceFiles_v2/Source_Files/Characters/SK_Character_Gangster.gltf", "set": "masc"},
	"punk_girl": {"path": "res://assets/meshes/POLYGON_City_Characters_SourceFiles_v2/Source_Files/Characters/SK_Character_PunkGirl.gltf", "set": "femn"},
}

static func crew_names() -> Array:
	return CREW.keys()

static func enemy_names() -> Array:
	return ENEMIES.keys()
