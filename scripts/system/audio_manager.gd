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
const _SILENT_DB := -60.0
const _CROSSFADE_SECS := 2.5

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
## Two ambient beds — the active one and the one fading out. Crossing into
## a site crossfades between them (zone ambience for the seamless district).
var _beds: Array[AudioStreamPlayer] = []
var _bed_idx := 0
var _ambient_name := ""
var _bed_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = _SFX_DB
		add_child(p)
		_pool.append(p)
	for i in 2:
		var bed := AudioStreamPlayer.new()
		bed.volume_db = _SILENT_DB
		add_child(bed)
		_beds.append(bed)

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

## Play (or crossfade to) a looping ambient bed. Same name → no-op, so
## GameWorld can call this on every site entry.
func play_ambient(ambient_name := "ambient_city") -> void:
	if ambient_name == _ambient_name:
		return
	var stream := _load(ambient_name)
	if stream == null:
		return
	_ambient_name = ambient_name
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size() / 2  # 16-bit mono: 2 bytes per frame
	var fading_out := _beds[_bed_idx]
	_bed_idx = (_bed_idx + 1) % 2
	var bed := _beds[_bed_idx]
	bed.stream = stream
	bed.volume_db = _SILENT_DB
	bed.play()
	if _bed_tween != null and _bed_tween.is_valid():
		_bed_tween.kill()  # rapid site hops: restart the fade from here
	_bed_tween = create_tween().set_parallel()
	_bed_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bed_tween.tween_property(bed, "volume_db", _AMBIENT_DB, _CROSSFADE_SECS)
	if fading_out.playing:
		_bed_tween.tween_property(fading_out, "volume_db", _SILENT_DB, _CROSSFADE_SECS)
		_bed_tween.chain().tween_callback(fading_out.stop)

## The bed currently playing (or fading in) — harness probe.
func ambient_name() -> String:
	return _ambient_name

func _load(base: String) -> AudioStream:
	var path := _DIR + base + ".wav"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
