## Autoload — minimum viable audio: pooled one-shot SFX and the hive-city
## ambient loop. Everything is flat (non-positional) placeholder audio
## synthesized into assets/audio/ by tools/gen_audio.py; the point is that
## the game is no longer silent. Real assets replace the WAVs by name later,
## no code change. (Lineage: wayfarer audio_manager.gd.)
extends Node

const _DIR := "res://assets/audio/"
const _SFX_POOL_SIZE := 8
const _AMBIENT_DB := -16.0
const _SFX_DB := -8.0

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _ambient: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = _SFX_DB
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = _AMBIENT_DB
	add_child(_ambient)

## Fire a one-shot by base name ("impact" → sfx_impact.wav). Small random
## pitch spread keeps rapid repeats from machine-gunning.
func play_sfx(sfx_name: String, volume_db := 0.0, pitch_jitter := 0.07) -> void:
	var stream := _load("sfx_" + sfx_name)
	if stream == null:
		return
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _SFX_POOL_SIZE
	p.stream = stream
	p.volume_db = _SFX_DB + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

## Start the looping city ambient. Safe to call every level load.
func play_ambient(ambient_name := "ambient_city") -> void:
	if _ambient.playing:
		return
	var stream := _load(ambient_name)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size() / 2  # 16-bit mono: 2 bytes per frame
	_ambient.stream = stream
	_ambient.play()

func _load(base: String) -> AudioStream:
	var path := _DIR + base + ".wav"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
