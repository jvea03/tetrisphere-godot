class_name TSSfx
extends RefCounted

## Short sound effects, synthesized in code (ported from Duckdoku's Sfx), and
## the music. TSSfx.play("click") from anywhere: players live under the tree
## root, so a sound survives the scene change it may trigger. Sounds go
## through the "SFX" bus and music through the "Music" bus, each muted by its
## own Settings toggle.

const SAMPLE_RATE := 22050
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const VOICES := 4   # how many of one sound can ring at once
const MENU_MUSIC := "res://audio/main_menu.mp3"
const LEVEL_MUSIC := [
	"res://audio/level_song_1.mp3",
	"res://audio/level_song_2.mp3",
	"res://audio/level_song_3.mp3",
	"res://audio/level_song_4.mp3",
]
const MUSIC_VOLUME_DB := {"menu": -8.0, "level": -10.0}   # under the sound effects, which carry the feedback
const MUSIC_SILENT_DB := -40.0
const MUSIC_FADE_IN := 1.2
const MUSIC_FADE_OUT := 0.6

static var _streams := {}
static var _players := {}   # sound name -> its voices (AudioStreamPlayers)
static var _music_mode := ""         # "menu", "level" or "" (silence)
static var _music_players := {}      # mode -> AudioStreamPlayer
static var _music_tweens := {}       # mode -> Tween
static var _level_bag: Array = []    # the level songs still to play this round
static var _last_level_song := ""


## The music for what is on screen: "menu" loops the main menu song; "level"
## plays the level songs one after another in a shuffled order, every song
## once before any repeats (next_level_song); "" is silence. Switching fades
## the old music out and the new in. Asking for the mode already playing
## changes nothing, so the menu song carries on from menu to menu and a level
## song from one level into the next. SceneFlow calls this as screens change;
## call it from _process-time code, not while a parent is setting up children.
static func music(mode: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or mode == _music_mode:
		return
	var old := _music_mode
	_music_mode = mode
	ensure_buses()
	if old != "":
		_fade_music(old, false)
	if mode != "":
		_fade_music(mode, true)


## The next level song from the shuffle bag: every level song in a random order,
## each played once, then a fresh shuffle -- which never opens with the song
## that just finished, so no song plays twice in a row.
## Stops and lets go of every player and stream, as the app quits, so
## nothing is left playing (or held) while the engine shuts down.
static func release() -> void:
	for group in [_music_players, _players]:
		for entry in group.values():
			for p in (entry if entry is Array else [entry]):
				if not is_instance_valid(p):
					continue
				(p as AudioStreamPlayer).stop()
				(p as AudioStreamPlayer).stream = null
				(p as AudioStreamPlayer).queue_free()   # still parented while the tree shuts down: free() would error
		group.clear()
	for t in _music_tweens.values():
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	_music_tweens.clear()
	_streams.clear()
	_music_mode = ""


static func next_level_song() -> String:
	if _level_bag.is_empty():
		_level_bag = LEVEL_MUSIC.duplicate()
		_level_bag.shuffle()
		if _level_bag.size() > 1 and _level_bag[0] == _last_level_song:
			_level_bag.push_back(_level_bag.pop_front())
	_last_level_song = _level_bag.pop_front()
	return _last_level_song


static func _music_player(mode: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _music_players.get(mode)
	if is_instance_valid(player):
		return player
	player = AudioStreamPlayer.new()
	player.bus = MUSIC_BUS
	player.volume_db = MUSIC_SILENT_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if mode == "menu":
		var stream := load(MENU_MUSIC) as AudioStreamMP3
		stream.loop = true
		player.stream = stream
	else:
		# A level song ends by itself (it never loops): on to the next one.
		player.finished.connect(func() -> void:
			if _music_mode == "level":
				_play_level_song(player))
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	_music_players[mode] = player
	return player


static func _play_level_song(player: AudioStreamPlayer) -> void:
	var stream := load(next_level_song()) as AudioStreamMP3
	stream.loop = false
	player.stream = stream
	player.play()


static func _fade_music(mode: String, on: bool) -> void:
	var player := _music_player(mode)
	var tween: Tween = _music_tweens.get(mode)
	if tween != null and tween.is_valid():
		tween.kill()
	if on and not player.playing:
		player.volume_db = MUSIC_SILENT_DB
		if mode == "level":
			_play_level_song(player)
		else:
			player.play()
	tween = player.create_tween()
	tween.tween_property(player, "volume_db", float(MUSIC_VOLUME_DB[mode]) if on else MUSIC_SILENT_DB, MUSIC_FADE_IN if on else MUSIC_FADE_OUT)
	if not on:
		tween.tween_callback(player.stop)
	_music_tweens[mode] = tween


static func play(name: String, pitch: float = 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	ensure_buses()
	# A few voices per sound, so quick repeats (a clear's pops) ring over each
	# other instead of cutting the last one off: a free voice, else the oldest.
	var voices: Array = _players.get(name, [])
	var player: AudioStreamPlayer = null
	for v in voices:
		if is_instance_valid(v) and not (v as AudioStreamPlayer).playing:
			player = v
			break
	if player == null and voices.size() < VOICES:
		player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.stream = _stream(name)
		player.pitch_scale = pitch
		tree.root.add_child.call_deferred(player)
		voices.append(player)
		_players[name] = voices
		player.ready.connect(func(): player.play(), CONNECT_ONE_SHOT)
		return
	if player == null:
		player = voices.pop_front()
		voices.append(player)
	if not is_instance_valid(player) or not player.is_inside_tree():
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
				_streams[name] = _chime([659.0, 784.0, 1047.0], 0.055, 0.3)
			"chain":
				_streams[name] = _chime([659.0, 784.0, 988.0, 1319.0, 1568.0], 0.05, 0.3)
			"pop", "pop0":
				_streams[name] = _pop(0)
			"pop1":
				_streams[name] = _pop(1)
			"pop2":
				_streams[name] = _pop(2)
			"crack":
				_streams[name] = _crack()
			"shimmer":
				_streams[name] = _chime([1568.0, 2093.0, 2637.0, 3136.0, 2637.0, 3136.0], 0.04, 0.14)
			"miss":
				_streams[name] = _tone(220.0, 0.28, "triangle", 0.4, 90.0)
			"rock_launch":
				_streams[name] = _twang()
			"rock_fly":
				_streams[name] = _whizz()
			"rock_hit":
				_streams[name] = _thunk()
			"magic":
				_streams[name] = _chime([523.0, 587.0, 659.0, 784.0, 880.0, 1047.0, 1175.0, 1319.0, 1568.0, 1760.0, 2093.0], 0.028, 0.16)
			"rainbow":
				_streams[name] = _rainbow()
			"clang":
				_streams[name] = _clang()
			"knock":
				_streams[name] = _knock()
			"snap":
				_streams[name] = _snap()
			"tink":
				_streams[name] = _glass([2350.0], 0.0, 0.3)
			"shatter":
				_streams[name] = _shatter()
			"win":
				_streams[name] = _fanfare()
			"windup":
				_streams[name] = _windup()
			"whoosh":
				_streams[name] = _whoosh()
			"popper":
				_streams[name] = _popper()
			"tick":
				_streams[name] = _chime([1760.0], 0.0, 0.22)
			"ding":
				_streams[name] = _chime([1319.0, 1760.0, 2637.0], 0.045, 0.24)
			"lose":
				_streams[name] = _sad_horn()
			"heartbreak":
				_streams[name] = _heartbreak()
			"groan":
				_streams[name] = _groan()
			"revive":
				_streams[name] = _chime([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.07, 0.28)
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


## A block breaking: a candy pop -- a tiny click, a bubble that chirps up as it
## bursts, and a sugary crunch of filtered noise under it. `variant` (0-2)
## nudges the bubble's note and the crunch, so a clear's pops don't all match.
static func _pop(variant: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + variant
	var n := int(SAMPLE_RATE * 0.14)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var f0: float = [430.0, 480.0, 400.0][variant]
	var phase := 0.0
	var fast := 0.0
	var slow := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# The bubble: up from f0 to about 2.4x as it bursts, gone in ~70 ms.
		var f := f0 * (1.0 + 1.4 * (1.0 - exp(-t * 55.0)))
		phase += TAU * f / SAMPLE_RATE
		var bubble := (sin(phase) + 0.28 * sin(phase * 2.0) * exp(-t * 40.0)) * exp(-t * 34.0)
		# The crunch: noise band-passed (a fast low-pass less a slow one).
		fast += (noise - fast) * 0.55
		slow += (noise - slow) * (0.08 + 0.03 * float(variant))
		var crunch := (fast - slow) * exp(-t * 42.0) * (0.75 + 0.25 * sin(t * 900.0))
		var click := noise * exp(-t * 1100.0)
		var attack := minf(t / 0.0015, 1.0)
		samples[i] = (bubble * 0.55 + crunch * 0.45 + click * 0.3) * attack * 0.6
	return _make_stream(samples)


## Stone breaking: a low thud and a gritty crackle of chips settling.
static func _crack() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := int(SAMPLE_RATE * 0.2)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var grain := 0.0
	var low := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(160.0, 62.0, minf(t / 0.09, 1.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * 26.0)
		# Crackle: little impulses, thick at first and thinning out, each ringing off.
		if rng.randf() < 0.12 * exp(-t * 18.0):
			grain = rng.randf_range(-1.0, 1.0)
		grain *= 0.86
		low += (grain - low) * 0.45
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 700.0)
		var attack := minf(t / 0.001, 1.0)
		samples[i] = (thud * 0.6 + low * 0.9 + click * 0.35) * attack * 0.6
	return _make_stream(samples)


## Bell-like notes struck one after another `step` seconds apart, each ringing
## on under the next (a fundamental, an octave and a faint glassy partial).
static func _chime(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var ring := 0.32
	var n := int(SAMPLE_RATE * (step * float(freqs.size() - 1) + ring))
	var samples := PackedFloat32Array()
	samples.resize(n)
	for k in freqs.size():
		var f: float = freqs[k]
		var start := int(SAMPLE_RATE * step * float(k))
		for i in range(start, mini(start + int(SAMPLE_RATE * ring), n)):
			var t := float(i - start) / SAMPLE_RATE
			var env := minf(t / 0.002, 1.0) * exp(-t * 11.0)
			var s := sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 8.0) + 0.12 * sin(TAU * f * 3.01 * t) * exp(-t * 20.0)
			samples[i] += s * env * vol * 0.75
	return _make_stream(samples)


## Pulls the music down by `db` for `seconds` and lets it back up, so a
## fanfare can be heard over it.
static var _duck_tween: Tween
static func duck(seconds: float, db := -12.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if tree == null or bus == -1:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var set_db := func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v)
	_duck_tween = tree.create_tween()
	_duck_tween.tween_method(set_db, AudioServer.get_bus_volume_db(bus), db, 0.12)
	_duck_tween.tween_interval(maxf(seconds - 0.12, 0.0))
	_duck_tween.tween_method(set_db, db, 0.0, 0.8)


## A level won: bells running up C major (C5 E5 G5 C6), landing on a warm held
## C chord with a gentle shimmer of vibrato, a little sparkle over the top.
static func _fanfare() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 1.5)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var run := [523.0, 659.0, 784.0, 1047.0]
	var step := 0.075
	for k in run.size():
		var f: float = run[k]
		var start := int(SAMPLE_RATE * step * float(k))
		for i in range(start, mini(start + int(SAMPLE_RATE * 0.3), n)):
			var t := float(i - start) / SAMPLE_RATE
			var env := minf(t / 0.002, 1.0) * exp(-t * 10.0)
			samples[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 9.0)) * env * 0.22
	# The chord, struck as the run ends and held, fading over a second.
	var chord := [1047.0, 1319.0, 1568.0, 523.0]
	var at := int(SAMPLE_RATE * step * 4.0)
	for i in range(at, n):
		var t := float(i - at) / SAMPLE_RATE
		var env := minf(t / 0.01, 1.0) * exp(-t * 2.6)
		var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t) * minf(t / 0.3, 1.0)
		var s := 0.0
		for c in chord:
			var f: float = c
			s += sin(TAU * f * vib * t) + 0.25 * sin(TAU * f * 2.0 * vib * t) * exp(-t * 4.0)
		# A twinkle of high notes over the chord.
		var tw := 0.0
		for j in 3:
			var tj := t - 0.12 * float(j + 1)
			if tj > 0.0:
				tw += sin(TAU * [2093.0, 2637.0, 3136.0][j] * tj) * exp(-tj * 14.0)
		samples[i] += (s * 0.075 + tw * 0.08) * env
	return _make_stream(samples)


## The critter crouching to jump: a soft whistle rising, with a wobble.
static func _windup() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.5)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var p := t / 0.5
		phase += TAU * lerpf(330.0, 880.0, p * p) * (1.0 + 0.03 * sin(TAU * 14.0 * t)) / SAMPLE_RATE
		var env := minf(t / 0.05, 1.0) * (1.0 - smoothstep(0.85, 1.0, p))
		samples[i] = (sin(phase) + 0.2 * sin(phase * 2.0)) * env * 0.2
	return _make_stream(samples)


## The critter shooting out of the egg: a rush of air rising in pitch and
## fading as it goes, with a cartoon "fwip" at the start.
static func _whoosh() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := int(SAMPLE_RATE * 0.75)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var fast := 0.0
	var slow := 0.0
	var phase := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var p := t / 0.75
		var noise := rng.randf_range(-1.0, 1.0)
		# A band of noise sliding up: the low-passes open as it goes.
		fast += (noise - fast) * lerpf(0.12, 0.6, p)
		slow += (noise - slow) * lerpf(0.02, 0.15, p)
		var env := sin(PI * minf(p * 1.6, 1.0)) * (1.0 - p)
		phase += TAU * lerpf(500.0, 1500.0, minf(t / 0.12, 1.0)) / SAMPLE_RATE
		var fwip := sin(phase) * exp(-t * 22.0)
		samples[i] = ((fast - slow) * env * 1.4 + fwip * 0.3) * 0.75
	return _make_stream(samples)


## The win card's confetti: a party popper's crack, the paper crackling out,
## and a bright little chime.
static func _popper() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var n := int(SAMPLE_RATE * 0.45)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var grain := 0.0
	var low := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.3
		var crack := low * exp(-t * 60.0) * 1.6 + noise * exp(-t * 400.0) * 0.5
		if rng.randf() < 0.05 * exp(-t * 7.0):
			grain = rng.randf_range(-1.0, 1.0)
		grain *= 0.8
		var tc := t - 0.06
		var chime := 0.0
		if tc > 0.0:
			chime = (sin(TAU * 2093.0 * tc) + 0.5 * sin(TAU * 3136.0 * tc)) * exp(-tc * 12.0)
		samples[i] = (crack * 0.5 + grain * 0.35 + chime * 0.12) * minf(t / 0.001, 1.0)
	return _make_stream(samples)


## The Rocks booster firing: a slingshot's rubber band twanging (a bright
## plucked tone that sags in pitch and buzzes) with a puff of dust.
static func _twang() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var n := int(SAMPLE_RATE * 0.35)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var dust := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(260.0, 170.0, minf(t / 0.2, 1.0)) * (1.0 + 0.02 * sin(TAU * 30.0 * t)) / SAMPLE_RATE
		# A sawtooth softened with its octave: the band's buzz.
		var saw := 2.0 * fposmod(phase / TAU, 1.0) - 1.0
		var band := (saw * 0.5 + sin(phase) * 0.6) * exp(-t * 11.0)
		dust += (rng.randf_range(-1.0, 1.0) - dust) * 0.2
		samples[i] = (band * 0.4 + dust * exp(-t * 20.0) * 0.5) * minf(t / 0.002, 1.0) * 0.8
	return _make_stream(samples)


## A rock flying through the air: a short whizz of noise sliding down.
static func _whizz() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var n := int(SAMPLE_RATE * 0.38)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var fast := 0.0
	var slow := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var p := t / 0.38
		var noise := rng.randf_range(-1.0, 1.0)
		fast += (noise - fast) * lerpf(0.5, 0.15, p)
		slow += (noise - slow) * lerpf(0.12, 0.03, p)
		samples[i] = (fast - slow) * sin(PI * p) * 0.55
	return _make_stream(samples)


## A rock landing on the egg: a deep stony thunk and gravel scattering.
static func _thunk() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var n := int(SAMPLE_RATE * 0.3)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var grain := 0.0
	var low := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(120.0, 48.0, minf(t / 0.12, 1.0)) / SAMPLE_RATE
		var thud := (sin(phase) + 0.3 * sin(phase * 2.7) * exp(-t * 40.0)) * exp(-t * 16.0)
		if rng.randf() < 0.2 * exp(-t * 12.0):
			grain = rng.randf_range(-1.0, 1.0)
		grain *= 0.9
		low += (grain - low) * 0.35
		var hit := rng.randf_range(-1.0, 1.0) * exp(-t * 300.0)
		samples[i] = (thud * 0.75 + low * 0.8 + hit * 0.4) * minf(t / 0.001, 1.0) * 0.6
	return _make_stream(samples)


## The Any Piece landing: every colour at once -- a bright major chord of bells
## struck together, then twinkles tumbling down over it.
static func _rainbow() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.9)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var chord := [784.0, 988.0, 1175.0, 1568.0]
	var twinkles := [3136.0, 2637.0, 2349.0, 2093.0, 1760.0, 1568.0]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s := 0.0
		for c in chord:
			var f: float = c
			s += sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0)
		s *= minf(t / 0.003, 1.0) * exp(-t * 4.0) * 0.09
		for j in twinkles.size():
			var tj := t - 0.1 - 0.06 * float(j)
			if tj > 0.0:
				s += sin(TAU * float(twinkles[j]) * tj) * exp(-tj * 16.0) * 0.12
		samples[i] = s
	return _make_stream(samples)


## Armour knocked off a blocker: a struck steel plate -- a bright click and
## the clashing, inharmonic partials of metal ringing off.
static func _clang() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var n := int(SAMPLE_RATE * 0.55)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var f := 540.0
	var partials := [[1.0, 1.0, 9.0], [2.76, 0.6, 12.0], [5.40, 0.4, 18.0], [8.93, 0.25, 26.0], [1.51, 0.35, 7.0]]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var s := 0.0
		for pt in partials:
			s += sin(TAU * f * float(pt[0]) * t) * float(pt[1]) * exp(-t * float(pt[2]))
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 900.0)
		samples[i] = (s * 0.16 + click * 0.45) * minf(t / 0.0008, 1.0)
	return _make_stream(samples)


## A tie-down losing a layer: a hollow wooden knock.
static func _knock() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 59
	var n := int(SAMPLE_RATE * 0.16)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var low := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var body := sin(TAU * 310.0 * t) * exp(-t * 38.0) + 0.5 * sin(TAU * 720.0 * t) * exp(-t * 60.0)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.4
		samples[i] = (body * 0.5 + low * exp(-t * 120.0) * 0.6) * minf(t / 0.0008, 1.0) * 0.5
	return _make_stream(samples)


## A tie-down breaking free: the stake snaps with a splintering crack, and its
## cable springs loose with a wobbling "boing".
static func _snap() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var n := int(SAMPLE_RATE * 0.5)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var grain := 0.0
	var phase := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		if rng.randf() < 0.3 * exp(-t * 40.0):
			grain = noise
		grain *= 0.7
		var crack := noise * exp(-t * 250.0) * 0.7 + grain * 0.8
		var tb := maxf(t - 0.03, 0.0)
		phase += TAU * lerpf(620.0, 220.0, minf(tb / 0.3, 1.0)) * (1.0 + 0.06 * sin(TAU * 22.0 * tb)) / SAMPLE_RATE
		var boing := sin(phase) * exp(-tb * 7.0) * minf(tb / 0.01, 1.0) * (1.0 if t > 0.03 else 0.0)
		samples[i] = (crack * 0.5 + boing * 0.32) * minf(t / 0.0008, 1.0)
	return _make_stream(samples)


## Glass: struck crystal partials (a little inharmonic), `step` seconds apart.
static func _glass(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var ring := 0.4
	var n := int(SAMPLE_RATE * (step * float(maxi(freqs.size() - 1, 0)) + ring))
	var samples := PackedFloat32Array()
	samples.resize(n)
	for k in freqs.size():
		var f: float = freqs[k]
		var start := int(SAMPLE_RATE * step * float(k))
		for i in range(start, mini(start + int(SAMPLE_RATE * ring), n)):
			var t := float(i - start) / SAMPLE_RATE
			var s := sin(TAU * f * t) * exp(-t * 14.0) + 0.5 * sin(TAU * f * 2.32 * t) * exp(-t * 22.0) + 0.25 * sin(TAU * f * 4.1 * t) * exp(-t * 35.0)
			samples[i] += s * minf(t / 0.0006, 1.0) * vol * 0.6
	return _make_stream(samples)


## A geode cracking open: a stony crack, then a spill of crystal tinkles at
## random high notes, scattering and fading.
static func _shatter() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	var n := int(SAMPLE_RATE * 0.7)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var low := 0.0
	var tinkles := []
	for k in 9:
		tinkles.append([0.02 + rng.randf_range(0.0, 0.32) * pow(float(k) / 9.0, 0.7), rng.randf_range(1900.0, 4200.0), rng.randf_range(0.5, 1.0)])
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.3
		var crack := (low * exp(-t * 45.0) + noise * exp(-t * 500.0) * 0.5) * 0.7
		var s := 0.0
		for tk in tinkles:
			var tt: float = t - float(tk[0])
			if tt > 0.0:
				var f: float = tk[1]
				s += (sin(TAU * f * tt) + 0.4 * sin(TAU * f * 2.32 * tt)) * exp(-tt * 18.0) * float(tk[2])
		samples[i] = (crack * 0.6 + s * 0.14) * minf(t / 0.0008, 1.0)
	return _make_stream(samples)


## A level lost: a soft muted horn going "wah, wah, wah, wahhh" down G, F#, F,
## E -- each note's tone opening and closing like a plunger mute, the last one
## held with a wobble of vibrato that droops as it fades. Sad, but cute.
static func _sad_horn() -> AudioStreamWAV:
	var notes := [[392.0, 0.3], [370.0, 0.3], [349.0, 0.3], [330.0, 1.0]]
	var total := 0.0
	for nd in notes:
		total += float(nd[1])
	var n := int(SAMPLE_RATE * (total + 0.05))
	var samples := PackedFloat32Array()
	samples.resize(n)
	var i := 0
	var phase := 0.0
	var lp := 0.0
	for k in notes.size():
		var f0: float = notes[k][0]
		var dur: float = notes[k][1]
		var last := k == notes.size() - 1
		var count := int(SAMPLE_RATE * dur)
		for j in count:
			if i >= n:
				break
			var t := float(j) / SAMPLE_RATE
			var p := t / dur
			var f := f0
			if last:   # vibrato growing in, and the note sagging as it dies
				f *= (1.0 + 0.012 * sin(TAU * 5.0 * t) * minf(t / 0.3, 1.0)) * lerpf(1.0, 0.96, p * p)
			phase += TAU * f / SAMPLE_RATE
			var saw := 2.0 * fposmod(phase / TAU, 1.0) - 1.0
			# The "wah": the low-pass opens as the note sounds and closes after.
			var wah := minf(p * 4.0, 1.0) * (1.0 - p * 0.7) if last else sin(PI * minf(p * 1.6, 1.0))
			lp += (saw - lp) * lerpf(0.02, 0.16, wah)
			var env := minf(t / 0.03, 1.0) * (1.0 - smoothstep(0.82, 1.0, p))
			var warm := sin(phase * 0.5) * 0.35   # an octave under, for body
			samples[i] = (lp * 0.9 + warm * 0.4) * env * 0.42
			i += 1
	return _make_stream(samples)


## The last heart going: a glassy crack, then a sigh sliding down.
static func _heartbreak() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var n := int(SAMPLE_RATE * 0.6)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.6 \
			+ (sin(TAU * 1760.0 * t) + 0.5 * sin(TAU * 1760.0 * 2.4 * t)) * exp(-t * 30.0) * 0.25
		var ts := maxf(t - 0.08, 0.0)
		phase += TAU * lerpf(700.0, 380.0, smoothstep(0.0, 0.4, ts)) / SAMPLE_RATE
		var sigh := (sin(phase) + 0.2 * sin(phase * 2.0)) * minf(ts / 0.04, 1.0) * exp(-ts * 4.5) * (1.0 if t > 0.08 else 0.0)
		samples[i] = (crack + sigh * 0.35) * minf(t / 0.0008, 1.0)
	return _make_stream(samples)


## The egg overloaded: the shell straining under the weight -- a slow,
## stick-slip wooden creak over a low rumble.
static func _groan() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	var n := int(SAMPLE_RATE * 0.75)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var low := 0.0
	var jitter := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var p := t / 0.75
		jitter += (rng.randf_range(-1.0, 1.0) - jitter) * 0.002
		phase += TAU * (lerpf(95.0, 70.0, p) * (1.0 + jitter * 6.0)) / SAMPLE_RATE
		# Stick-slip: the creak catches and lets go in little pulses.
		var pulse := pow(0.5 + 0.5 * sin(TAU * lerpf(18.0, 9.0, p) * t), 3.0)
		var saw := 2.0 * fposmod(phase / TAU, 1.0) - 1.0
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.01
		var env := sin(PI * p)
		samples[i] = (saw * pulse * 0.35 + low * 2.0) * env * 0.6
	return _make_stream(samples)


## Brings ducked music straight back up (the moment has passed early).
static func unduck() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if tree == null or bus == -1:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = tree.create_tween()
	_duck_tween.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), AudioServer.get_bus_volume_db(bus), 0.0, 0.4)
