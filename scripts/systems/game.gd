extends Node
## Global game state: save data, settings, input map, time effects, shared signals.

signal boss_defeated(id: String)
signal toast(text: String, seconds: float)
signal banner(title: String, subtitle: String)

const SAVE_PATH := "user://hollow_arrow_save.json"
const SETTINGS_PATH := "user://hollow_arrow_settings.json"
## Hard mode for reading bosses: no aim lines, no lane/cone previews. Ground circles that mark where a blast lands stay,
## because the boss's wind-up animation and sound are then the only cue for WHICH WAY an attack goes.
const SHOW_AIM_TELEGRAPHS := false
const BOSS_ORDER := ["warden", "knight", "burrower", "colossus", "hunter", "twins", "regent"]
const BOSS_NAMES := {
	"warden": "THE STONE WARDEN",
	"knight": "THE MIRROR KNIGHT",
	"burrower": "THE HOLLOW EXECUTIONER",
	"colossus": "THE CHAINED COLOSSUS",
	"hunter": "THE SKY HUNTER",
	"twins": "THE TWIN SENTINELS",
	"regent": "THE ASHEN REGENT",
}
const BOSS_TAGLINES := {
	"warden": "Keeper of the Courtyard",
	"knight": "Shield of the Glass Vault",
	"burrower": "Judge of the Candlelit Crypt",
	"colossus": "Prisoner of Iron",
	"hunter": "Tyrant of the Winds",
	"twins": "Sun and Moon, Bound in Duty",
	"regent": "Last King of the Hollow Court",
}
const BOSS_TIPS := {
	"warden": "DODGE ITS ROLL INTO A PILLAR. WHEN IT UNCURLS, SHOOT THE CRYSTAL ON ITS BROW.",
	"knight": "THE ICE FLOOR IS SLICK AND ARROWS THAT HIT ITS ARMOUR FREEZE. WAIT FOR THE SLAM - THEN SHOOT THE EYE.",
	"burrower": "A GHOST: ARROWS PASS THROUGH IT. LIGHT A LANTERN WITH AN ARROW AND SHOOT THROUGH ITS GLOW - THEN HIT THE EYES.",
	"colossus": "LAVA ERUPTS UNDERFOOT. CUT THE THREE CHAINS WITH THE ARROW, THEN STRIKE THE DEMON'S FACE.",
	"hunter": "THE GALE BENDS YOUR ARROW. WHEN ITS QUIVER RUNS DRY IT KNEELS - SHOOT ITS HEAD. IF IT STEALS YOUR ARROW, RECALL IT.",
	"twins": "SUN SIDE: FAST ARROWS. MOON SIDE: SLOW. LET ONE WIZARD'S BEAM STRIKE THE OTHER, THEN SHOOT THE GEM ON ITS STAFF.",
	"regent": "ITS CORE IS SEALED. STRIKE THE SHRINE OF THE ELEMENT IT FEARS - THEN SHOOT THE CORE.",
}
const MAIN_BOSSES := ["warden", "knight", "burrower", "colossus", "hunter"]
const TWINS_REQUIRED := 3

var defeated := {}
var seen_unlocked := {}
var settings := {"master": 0.8, "music": 0.6, "sfx": 0.9, "shake": 1.0, "fullscreen": false}
var current_zone := "hub"
var entry := "start"
var play_time := 0.0
var deaths := 0
var boss_deaths := {}             # boss id -> how many times the player has died fighting it
signal deaths_changed
var finished := false
var intro_seen := false
var playing := false
var aim_override = null  # Vector2 for scripted tests, else null
## Touch play (phones/tablets): the on-screen controls set a direction to aim along; touch_debug lets a mouse stand in for a finger
## (start with `--touch` or open the web build with ?touch=1).
var touch_mode := false
var touch_aim := Vector2.ZERO
var touch_debug := false
var trauma := 0.0
var _slow_token := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_debug = "--touch" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		if bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('touch')")):
			touch_debug = true
		if OS.has_feature("web_android") or OS.has_feature("web_ios"):
			touch_mode = true
	if touch_debug or DisplayServer.is_touchscreen_available():
		touch_mode = true
	_setup_input()
	load_settings()
	apply_settings()

func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.8)
	if playing and not get_tree().paused:
		play_time += delta

# ------------------------------------------------------------------ input
func _setup_input() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("dodge", [KEY_SPACE, KEY_SHIFT])
	_key("restart", [KEY_R])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("recall", [KEY_E, KEY_F])
	if not touch_debug:                      # in touch debug the mouse is a finger, not a bow
		_mouse("shoot", MOUSE_BUTTON_LEFT)
		_mouse("recall", MOUSE_BUTTON_RIGHT)
	else:
		for a in ["shoot", "recall"]:
			if not InputMap.has_action(a):
				InputMap.add_action(a)

func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

# ------------------------------------------------------------------ progression
func is_defeated(id: String) -> bool:
	return defeated.has(id)

func main_count() -> int:
	var n := 0
	for b in MAIN_BOSSES:
		if defeated.has(b):
			n += 1
	return n

func is_unlocked(id: String) -> bool:
	match id:
		"twins":
			return main_count() >= TWINS_REQUIRED
		"regent":
			return main_count() >= MAIN_BOSSES.size() and defeated.has("twins")
		_:
			return true

func mark_defeated(id: String) -> void:
	defeated[id] = true
	boss_defeated.emit(id)
	save_game()

func new_game() -> void:
	defeated = {}
	seen_unlocked = {}
	current_zone = "hub"
	entry = "start"
	play_time = 0.0
	deaths = 0
	boss_deaths = {}
	finished = false
	intro_seen = false
	for b in MAIN_BOSSES:
		seen_unlocked[b] = true

## one death, counted in total and against the boss being fought
func record_death(boss_id := "") -> void:
	deaths += 1
	if boss_id != "":
		boss_deaths[boss_id] = int(boss_deaths.get(boss_id, 0)) + 1
	deaths_changed.emit()

# ------------------------------------------------------------------ save / load
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var d := {
		"version": 1,
		"defeated": defeated.keys(),
		"seen_unlocked": seen_unlocked.keys(),
		"zone": current_zone,
		"entry": entry,
		"play_time": play_time,
		"deaths": deaths,
		"boss_deaths": boss_deaths,
		"finished": finished,
		"intro_seen": intro_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	defeated = {}
	for b in d.get("defeated", []):
		defeated[str(b)] = true
	seen_unlocked = {}
	for b in d.get("seen_unlocked", []):
		seen_unlocked[str(b)] = true
	# never resume inside an arena/path: always come back to the hub (arena starts are checkpoints)
	current_zone = "hub"
	entry = str(d.get("entry", "start"))
	play_time = float(d.get("play_time", 0.0))
	deaths = int(d.get("deaths", 0))
	boss_deaths = {}
	var bd = d.get("boss_deaths", {})
	if typeof(bd) == TYPE_DICTIONARY:
		for k in bd:
			boss_deaths[str(k)] = int(bd[k])
	finished = bool(d.get("finished", false))
	intro_seen = bool(d.get("intro_seen", true))
	return true

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge_settings(parsed)

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func _merge_settings(s) -> void:
	if typeof(s) != TYPE_DICTIONARY:
		return
	for k in settings:
		if s.has(k):
			settings[k] = s[k]

func apply_settings() -> void:
	var m: Node = get_node_or_null("/root/Sfx")
	if m and m.has_method("apply_volumes"):
		m.apply_volumes()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)

# ------------------------------------------------------------------ feel
func time_dip(scale: float, real_seconds: float) -> void:
	_slow_token += 1
	var tok := _slow_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if tok == _slow_token:
		Engine.time_scale = 1.0

func hitstop(seconds := 0.06) -> void:
	time_dip(0.02, seconds)

func slowmo(scale := 0.25, seconds := 1.4) -> void:
	time_dip(scale, seconds)

func reset_time() -> void:
	_slow_token += 1
	Engine.time_scale = 1.0

func add_trauma(a: float) -> void:
	trauma = minf(1.0, trauma + a * float(settings["shake"]))

func say(text: String, seconds := 2.5) -> void:
	toast.emit(text, seconds)

func show_banner(title: String, subtitle := "") -> void:
	banner.emit(title, subtitle)

func fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
