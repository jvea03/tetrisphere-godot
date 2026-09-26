class_name TSSfx
extends RefCounted

## Short sound effects, synthesized in code -- no audio files (ported from
## Duckdoku's Sfx). TSSfx.play("click") from anywhere: players live under the
## tree root, so a sound survives the scene change it may trigger. Everything
## goes through the "SFX" bus, which the Settings toggle mutes; "Music" is
## ready for a menu track (Tetrisphere has none yet).

const SAMPLE_RATE := 22050
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

static var _streams := {}
static var _players := {}


static func play(name: String, pitch: float = 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	ensure_buses()
	var player: AudioStreamPlayer = _players.get(name)
	if not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.stream = _stream(name)
		tree.root.add_child.call_deferred(player)
		_players[name] = player
		player.ready.connect(func(): player.play(), CONNECT_ONE_SHOT)
		return
	if not player.is_inside_tree():
		return # still being added; its first play is already queued
	player.pitch_scale = pitch
	player.play()


static func ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	apply_settings()


static func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not TSProfile.music_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not TSProfile.sfx_enabled)


static func _stream(name: String) -> AudioStreamWAV:
	if not _streams.has(name):
		match name:
			"click":
				_streams[name] = _tone(700.0, 0.05, "square", 0.22, 950.0)
			"aim":
				_streams[name] = _tone(880.0, 0.04, "sine", 0.25, 990.0)
			"drop":
				_streams[name] = _tone(420.0, 0.12, "triangle", 0.4, 300.0)
			"match":
				_streams[name] = _arpeggio([523.0, 659.0, 784.0], 0.07, "square", 0.3)
			"chain":
				_streams[name] = _arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.06, "square", 0.3)
			"miss":
				_streams[name] = _tone(220.0, 0.28, "triangle", 0.4, 90.0)
			"win":
				_streams[name] = _arpeggio([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.09, "sine", 0.4, 1.1)
			"lose":
				_streams[name] = _arpeggio([440.0, 330.0, 220.0, 140.0], 0.18, "sine", 0.45, 1.2)
			"upgrade":
				_streams[name] = _arpeggio([660.0, 880.0, 1320.0, 1760.0, 2640.0], 0.06, "sine", 0.35, 1.1)
			"coin":
				_streams[name] = _arpeggio([1320.0, 1760.0], 0.05, "sine", 0.3)
			"bomb":
				_streams[name] = _explosion()
			_:
				_streams[name] = _tone(600.0, 0.05, "sine", 0.2)
	return _streams[name]


static func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


## A single tone with a pitch slide and a fast-attack, curved decay: a blip.
static func _tone(freq: float, duration: float, wave: String, vol: float, freq_end: float = -1.0) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var end_freq: float = freq_end if freq_end > 0.0 else freq
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / float(maxi(n - 1, 1))
		var phase := TAU * lerpf(freq, end_freq, progress) * t
		var raw: float
		match wave:
			"square":
				raw = 1.0 if sin(phase) >= 0.0 else -1.0
			"triangle":
				raw = asin(sin(phase)) * (2.0 / PI)
			_:
				raw = sin(phase)
		samples[i] = raw * vol * pow(1.0 - progress, 1.6)
	return _make_stream(samples)


static func _arpeggio(freqs: Array, note_duration: float, wave: String, vol: float, decay_power: float = 1.4) -> AudioStreamWAV:
	var per := int(SAMPLE_RATE * note_duration)
	var samples := PackedFloat32Array()
	samples.resize(per * freqs.size())
	for idx in range(freqs.size()):
		var freq: float = freqs[idx]
		for i in range(per):
			var t := float(i) / SAMPLE_RATE
			var progress := float(i) / float(maxi(per - 1, 1))
			var phase := TAU * freq * t
			var raw: float = (1.0 if sin(phase) >= 0.0 else -1.0) if wave == "square" else sin(phase)
			samples[idx * per + i] = raw * vol * pow(1.0 - progress, decay_power)
	return _make_stream(samples)


## A noise burst that darkens as it decays, over a deep falling thump.
static func _explosion() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(SAMPLE_RATE * 1.0)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var low := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var attack: float = minf(t / 0.004, 1.0)
		low += (rng.randf_range(-1.0, 1.0) - low) * lerpf(0.55, 0.04, minf(t / 0.6, 1.0))
		var thump := sin(TAU * lerpf(90.0, 38.0, minf(t / 0.35, 1.0)) * t) * exp(-t * 6.0)
		samples[i] = (low * exp(-t * 3.2) * 0.9 + thump * 0.8) * attack * 0.7
	return _make_stream(samples)
