extends Node
## Fully procedural, original audio: every sound effect and music loop is synthesised at startup.

const RATE := 22050
const MRATE := 16000

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music := {}
var _mutex := Mutex.new()
var _want := ""
var _current := ""
var _bus_music := 0
var _bus_sfx := 0
var _music_tween: Tween
var _music_defs := {}
var _music_queue: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_sounds()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM   # the web default ("sample") ignores our runtime-made buses
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_music_player)
	_music_defs = _music_definitions()
	_music_queue = _music_defs.keys()
	apply_volumes()

func _setup_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, "Master")
	_bus_music = AudioServer.get_bus_index("Music")
	_bus_sfx = AudioServer.get_bus_index("SFX")

func apply_volumes() -> void:
	if _bus_music == 0 and AudioServer.get_bus_index("Music") > 0:
		_bus_music = AudioServer.get_bus_index("Music")
		_bus_sfx = AudioServer.get_bus_index("SFX")
	var g = get_node_or_null("/root/Game")
	if g == null:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(g.settings["master"]))))
	AudioServer.set_bus_volume_db(_bus_music, linear_to_db(maxf(0.0001, float(g.settings["music"]) * 0.7)))
	AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(maxf(0.0001, float(g.settings["sfx"]))))

func _process(_d: float) -> void:
	# music loops are synthesised one per frame (wanted track first) to avoid a long startup hitch
	if not _music_queue.is_empty():
		var next: String = _music_queue[0]
		if _want != "" and _music_queue.has(_want):
			next = _want
		_music_queue.erase(next)
		_music[next] = _track(_music_defs[next])
	if _want != "" and _want != _current:
		var s = _music.get(_want)
		if s != null:
			_start_music(_want, s)

# ------------------------------------------------------------------ playback
func play(sound: String, vol_db := 0.0, pitch := 1.0, jitter := 0.06) -> void:
	var s = _sounds.get(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _players[0]
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.play()

func play_music(track: String) -> void:
	_want = track
	if track == "":
		_current = ""
		stop_music()

func stop_music(fade := 0.8) -> void:
	_want = ""
	_current = ""
	if _music_tween:
		_music_tween.kill()
	if _music_player.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -50.0, fade)
		_music_tween.tween_callback(_music_player.stop)

func _start_music(name: String, stream: AudioStream) -> void:
	_current = name
	if _music_tween:
		_music_tween.kill()
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", 0.0, 1.2)

# ------------------------------------------------------------------ synthesis
func _wav(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s

## wave: 0 sine 1 square 2 saw 3 noise 4 triangle 5 low-passed noise
func _layer(buf: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, wave: int, vol: float, decay := 2.0, vib := 0.0, wrap := false) -> void:
	var n0 := int(start * rate)
	var n := int(dur * rate)
	var phase := 0.0
	var lp := 0.0
	var size := buf.size()
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		if vib > 0.0:
			f *= 1.0 + vib * sin(TAU * 7.0 * float(i) / float(rate))
		phase += f / float(rate)
		var ph := phase - floorf(phase)
		var s := 0.0
		match wave:
			0: s = sin(TAU * ph)
			1: s = 1.0 if ph < 0.5 else -1.0
			2: s = ph * 2.0 - 1.0
			3: s = randf() * 2.0 - 1.0
			4: s = absf(ph * 4.0 - 2.0) - 1.0
			5:
				lp += ((randf() * 2.0 - 1.0) - lp) * clampf(f / float(rate) * 6.28, 0.0, 1.0)
				s = lp * 2.5
		var env := pow(1.0 - t, decay) * minf(1.0, float(i) / (float(rate) * 0.004))
		var idx := n0 + i
		if wrap:
			idx = idx % size
		if idx < size:
			buf[idx] += s * vol * env

func _buf(seconds: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b

func _add(name: String, seconds: float, layers: Array) -> void:
	var b := _buf(seconds)
	for l in layers:
		# [start, dur, f0, f1, wave, vol, decay, vib]
		_layer(b, RATE, l[0], l[1], l[2], l[3], l[4], l[5], l[6] if l.size() > 6 else 2.0, l[7] if l.size() > 7 else 0.0)
	_sounds[name] = _wav(b, RATE)

func _build_sounds() -> void:
	_add("shoot", 0.22, [[0, 0.2, 2200, 500, 5, 0.6, 2.5], [0, 0.14, 900, 260, 0, 0.35, 2.0], [0, 0.03, 1800, 1800, 3, 0.25, 3.0]])
	_add("arrow_wall", 0.18, [[0, 0.1, 220, 80, 1, 0.35, 3.0], [0, 0.05, 3000, 3000, 3, 0.35, 4.0], [0, 0.12, 120, 60, 0, 0.5, 2.5]])
	_add("arrow_clink", 0.3, [[0, 0.25, 1500, 1100, 1, 0.22, 2.5], [0, 0.3, 2300, 2100, 0, 0.3, 2.0], [0, 0.04, 4000, 4000, 3, 0.3, 3.0]])
	_add("recall", 0.5, [[0, 0.5, 260, 880, 0, 0.35, 0.7, 0.03], [0, 0.5, 130, 440, 4, 0.2, 0.8], [0, 0.4, 1500, 4000, 5, 0.25, 1.0]])
	_add("catch", 0.16, [[0, 0.1, 700, 1400, 0, 0.4, 2.0], [0, 0.03, 2500, 2500, 3, 0.3, 3.0]])
	_add("step", 0.06, [[0, 0.05, 500, 300, 5, 0.25, 2.5]])
	_add("dodge", 0.25, [[0, 0.22, 1800, 400, 5, 0.55, 1.8], [0, 0.15, 300, 150, 0, 0.2, 2.0]])
	_add("player_death", 0.9, [[0, 0.8, 380, 50, 2, 0.35, 1.2], [0, 0.3, 900, 200, 5, 0.6, 2.0], [0, 0.15, 90, 40, 0, 0.6, 2.0]])
	_add("weak_hit", 0.7, [[0, 0.5, 1320, 1320, 0, 0.35, 2.0], [0, 0.5, 1980, 1980, 0, 0.2, 2.5], [0, 0.25, 90, 35, 0, 0.7, 2.0], [0, 0.15, 3000, 3000, 3, 0.5, 3.0]])
	_add("boss_death", 2.6, [[0, 2.4, 300, 30, 2, 0.35, 1.0, 0.02], [0, 2.0, 2000, 100, 5, 0.7, 1.2], [0.05, 0.6, 1100, 110, 0, 0.5, 1.5], [0.3, 1.5, 600, 40, 1, 0.15, 1.5]])
	_add("telegraph", 0.5, [[0, 0.45, 300, 720, 1, 0.16, 0.6, 0.02], [0, 0.45, 150, 360, 2, 0.14, 0.6]])
	_add("roar", 0.9, [[0, 0.85, 95, 60, 2, 0.4, 1.0, 0.05], [0, 0.85, 800, 200, 5, 0.5, 1.2], [0, 0.85, 47, 40, 0, 0.5, 1.0]])
	_add("charge", 0.5, [[0, 0.5, 900, 200, 5, 0.6, 1.0], [0, 0.4, 70, 55, 2, 0.3, 1.5]])
	_add("slam", 0.8, [[0, 0.6, 100, 30, 0, 0.9, 2.0], [0, 0.4, 700, 90, 5, 0.9, 2.2], [0, 0.03, 3000, 3000, 3, 0.4, 3.0]])
	_add("crash", 0.8, [[0, 0.7, 120, 35, 0, 0.9, 2.0], [0, 0.6, 1200, 100, 5, 0.9, 1.6], [0.02, 0.4, 600, 60, 3, 0.35, 3.0]])
	_add("stun", 0.6, [[0, 0.5, 400, 90, 1, 0.3, 1.8], [0, 0.4, 700, 150, 5, 0.5, 2.0], [0.05, 0.4, 1046, 1046, 0, 0.25, 2.5]])
	_add("unlock", 1.6, [[0, 1.0, 400, 120, 5, 0.6, 0.8], [0, 0.6, 60, 45, 2, 0.35, 1.0], [0.6, 0.5, 660, 660, 0, 0.35, 1.5], [0.8, 0.5, 880, 880, 0, 0.3, 1.5], [1.0, 0.6, 1320, 1320, 0, 0.3, 1.5]])
	_add("ui_move", 0.06, [[0, 0.05, 520, 520, 1, 0.12, 2.0]])
	_add("ui_select", 0.15, [[0, 0.12, 620, 1040, 1, 0.16, 1.5], [0, 0.12, 1240, 2080, 0, 0.12, 1.5]])
	_add("beam", 0.9, [[0, 0.9, 190, 230, 2, 0.28, 0.8, 0.04], [0, 0.9, 2400, 1200, 5, 0.4, 0.9]])
	_add("rumble", 0.7, [[0, 0.7, 60, 50, 0, 0.5, 0.8], [0, 0.7, 240, 120, 5, 0.6, 0.9]])
	_add("erupt", 1.0, [[0, 0.9, 900, 120, 5, 0.9, 1.5], [0, 0.7, 90, 32, 0, 0.9, 1.8], [0, 0.05, 2500, 2500, 3, 0.5, 3.0]])
	_add("reflect", 0.35, [[0, 0.3, 1800, 2600, 0, 0.3, 2.0], [0, 0.3, 3600, 3900, 4, 0.14, 2.0], [0, 0.04, 4200, 4200, 3, 0.25, 3.0]])
	_add("checkpoint", 0.9, [[0, 0.6, 440, 440, 0, 0.3, 1.5], [0.15, 0.6, 660, 660, 0, 0.3, 1.5], [0.3, 0.6, 880, 880, 0, 0.3, 1.5]])
	_add("wing", 0.3, [[0, 0.28, 500, 120, 5, 0.5, 1.5]])
	_add("shatter", 0.6, [[0, 0.5, 2600, 500, 5, 0.6, 1.4], [0, 0.15, 4200, 4200, 3, 0.4, 2.5], [0, 0.4, 130, 50, 0, 0.5, 2.0]])
	_add("portal", 1.0, [[0, 0.9, 200, 800, 0, 0.3, 0.8, 0.03], [0.1, 0.8, 300, 1200, 4, 0.18, 0.9]])
	_add("switch", 0.5, [[0, 0.4, 500, 1000, 1, 0.2, 1.5], [0, 0.4, 1000, 2000, 0, 0.2, 1.5], [0, 0.08, 3500, 3500, 3, 0.35, 3.0]])
	_add("chain", 0.5, [[0, 0.3, 3000, 1400, 5, 0.5, 2.0], [0, 0.4, 1800, 1200, 1, 0.12, 3.0], [0.08, 0.3, 2600, 1200, 5, 0.4, 2.0]])
	_add("orb", 0.3, [[0, 0.25, 800, 300, 1, 0.14, 2.0], [0, 0.25, 1600, 700, 0, 0.16, 2.0]])
	_add("blink", 0.3, [[0, 0.25, 200, 1800, 0, 0.3, 2.0], [0, 0.2, 2400, 3000, 5, 0.3, 2.0]])
	_add("thud", 0.3, [[0, 0.25, 110, 45, 0, 0.7, 2.5], [0, 0.1, 500, 200, 5, 0.4, 2.5]])

# ------------------------------------------------------------------ music (built on a worker thread)
func _mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func _music_definitions() -> Dictionary:
	return {
		"title": {"bpm": 66, "bars": 4, "root": 45, "bass": [0, 0, 7, 5], "arp": [0, 3, 7, 12, 10, 7, 3, 7], "pulse": false, "arp_vol": 0.1, "pad": 0.09},
		"hub": {"bpm": 58, "bars": 4, "root": 43, "bass": [0, 0, 5, 3], "arp": [0, 7, 12, 7, 15, 12, 7, 3], "pulse": false, "arp_vol": 0.06, "pad": 0.1},
		"path": {"bpm": 50, "bars": 4, "root": 38, "bass": [0, 0, 0, 1], "arp": [0, -1, 7, -1, 3, -1, -1, 10], "pulse": false, "arp_vol": 0.05, "pad": 0.11},
		"battle": {"bpm": 128, "bars": 8, "root": 40, "bass": [0, 0, 3, 5, 0, 0, 7, 5], "arp": [0, 12, 7, 12, 3, 12, 10, 12], "pulse": true, "arp_vol": 0.06, "pad": 0.06},
		"battle2": {"bpm": 144, "bars": 8, "root": 43, "bass": [0, 3, 0, 5, 0, 3, 7, 6], "arp": [0, 7, 12, 15, 12, 7, 3, 7], "pulse": true, "arp_vol": 0.07, "pad": 0.06},
		"final": {"bpm": 156, "bars": 8, "root": 38, "bass": [0, 0, 1, 0, 3, 3, 5, 6], "arp": [0, 12, 15, 12, 7, 12, 19, 12], "pulse": true, "arp_vol": 0.08, "pad": 0.08},
		"ending": {"bpm": 60, "bars": 4, "root": 48, "bass": [0, 7, 5, 3], "arp": [0, 4, 7, 12, 7, 4, 7, 11], "pulse": false, "arp_vol": 0.09, "pad": 0.1},
	}

func _track(d: Dictionary) -> AudioStreamWAV:
	var bpm: float = d["bpm"]
	var bars: int = d["bars"]
	var beat := 60.0 / bpm
	var total := beat * 4.0 * bars
	var buf := _buf(total, MRATE)
	var root: float = d["root"]
	var bass: Array = d["bass"]
	var arp: Array = d["arp"]
	for bar in bars:
		var bt := bar * 4.0 * beat
		var deg: int = bass[bar % bass.size()]
		# pad chord (root + minor third + fifth)
		for iv in [0, 3, 7]:
			_layer(buf, MRATE, bt, beat * 4.0, _mtof(root + 12 + deg + iv), _mtof(root + 12 + deg + iv), 4, d["pad"], 0.6, 0.004, true)
		# sub bass
		if d["pulse"]:
			for e in 8:
				_layer(buf, MRATE, bt + e * beat * 0.5, beat * 0.45, _mtof(root + deg), _mtof(root + deg), 2, 0.13, 2.0, 0.0, true)
			for b in 4:
				_layer(buf, MRATE, bt + b * beat, 0.16, 120, 40, 0, 0.5, 2.0, 0.0, true)
				_layer(buf, MRATE, bt + b * beat + beat * 0.5, 0.05, 6000, 6000, 3, 0.07, 3.0, 0.0, true)
		else:
			_layer(buf, MRATE, bt, beat * 3.8, _mtof(root + deg), _mtof(root + deg), 0, 0.22, 0.7, 0.0, true)
		# arpeggio
		for e in 8:
			var n: int = arp[e % arp.size()]
			if n < 0:
				continue
			_layer(buf, MRATE, bt + e * beat * 0.5, beat * 0.9, _mtof(root + 24 + deg + n), _mtof(root + 24 + deg + n), 4, d["arp_vol"], 2.5, 0.0, true)
	return _wav(buf, MRATE, true)
