class_name Zone
extends Node2D
## One playable area (hub, path or boss arena) built from ZoneData at runtime.

signal request_zone(zone_id: String, entry: String)
signal retry_requested
signal ending_requested
signal fight_started_signal

const TILE := 16
const WALL_CHARS := "#1234567A"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BOSS_SCENES := {
	"warden": "res://scenes/bosses/warden.tscn",
	"knight": "res://scenes/bosses/knight.tscn",
	"burrower": "res://scenes/bosses/burrower.tscn",
	"colossus": "res://scenes/bosses/colossus.tscn",
	"hunter": "res://scenes/bosses/hunter.tscn",
	"twins": "res://scenes/bosses/twins.tscn",
	"regent": "res://scenes/bosses/regent.tscn",
}
## name: [texture, foot width, foot height]  (foot 0 = walk-through prop)
const DECOR := {
	"tree_a": ["tree_a", 10, 6], "tree_b": ["tree_b", 10, 6], "tree_dead": ["tree_dead", 8, 5],
	"bush": ["bush", 0, 0], "statue_knight": ["statue_knight", 12, 6], "statue_hood": ["statue_hood", 12, 6],
	"statue_broken": ["statue_broken", 12, 6], "skeleton": ["skeleton", 44, 8], "sword_grave": ["sword_grave", 0, 0],
	"pillar": ["pillar", 12, 8], "pillar_broken": ["pillar_broken", 12, 8], "rubble": ["rubble", 0, 0],
	"fallen_column": ["fallen_column", 40, 8], "altar": ["altar", 46, 10], "fountain": ["fountain", 46, 14],
	"crystal_a": ["crystal_a", 10, 6], "crystal_b": ["crystal_b", 16, 6], "stalagmite": ["stalagmite", 10, 6],
	"mushrooms": ["mushrooms", 0, 0], "bones": ["bones", 0, 0], "flowers": ["flowers", 0, 0],
	"banner": ["banner", 0, 0], "throne": ["throne", 36, 10],
	# lairs: warden sanctum, knight vault, burrower dunes, colossus foundry, hunter aerie, twins observatory
	"vines": ["vines", 0, 0], "banner_teal": ["banner_teal", 0, 0], "ice_spire_a": ["ice_spire_a", 10, 6],
	"ice_spire_b": ["ice_spire_b", 16, 6], "frozen_fall": ["frozen_fall", 0, 0], "icicles": ["icicles", 0, 0],
	"snow_drift": ["snow_drift", 0, 0], "banner_ice": ["banner_ice", 0, 0], "gallows": ["gallows", 10, 6],
	"chop_block": ["chop_block", 14, 6], "hang_cage": ["hang_cage", 10, 6], "rib_cage": ["rib_cage", 34, 8],
	"skull_pile": ["skull_pile", 0, 0], "bone_spike": ["bone_spike", 10, 6], "banner_ash": ["banner_ash", 0, 0],
	"basalt_col": ["basalt_col", 12, 8], "anvil": ["anvil", 22, 8], "hang_chain": ["hang_chain", 0, 0],
	"banner_lava": ["banner_lava", 0, 0], "watchtower": ["watchtower", 32, 10], "grass_tuft": ["grass_tuft", 0, 0],
	"wind_banner": ["wind_banner", 0, 0], "feather_pile": ["feather_pile", 0, 0], "banner_wind": ["banner_wind", 0, 0],
	"obelisk": ["obelisk", 12, 6], "banner_violet": ["banner_violet", 0, 0],
	"tombstone": ["tombstone", 12, 6], "coffin": ["coffin", 34, 8],
}
## animated props: name: [file, frame width, frames, fps, foot width, foot height]
const ANIM_DECOR := {
	"brazier": ["brazier", 20, 3, 7.0, 10, 6], "brazier_cool": ["brazier_cool", 20, 3, 7.0, 10, 6],
	"waterfall": ["waterfall", 24, 4, 8.0, 0, 0], "lava_vent": ["lava_vent", 24, 3, 6.0, 0, 0],
}
## emblems painted on the floor (centred on their position, under everything)
const FLOOR_DECOR := ["rune_circle", "sun_disc", "moon_disc"]
## ground tint per biome and boss phase (CanvasModulate can only darken, so escalation = the room getting darker / warmer)
const PHASE_TINT := {
	"courtyard": [Color(1, 1, 1), Color(0.95, 1.0, 1.0), Color(1.0, 0.9, 0.85)],
	"crystal": [Color(1, 1, 1), Color(0.92, 0.96, 1.0), Color(0.84, 0.88, 1.0)],
	"colossus": [Color(1, 0.98, 0.96), Color(1, 0.9, 0.88), Color(1, 0.8, 0.74)],
	"sky": [Color(1, 1, 1), Color(0.82, 0.86, 0.95), Color(0.66, 0.66, 0.86)],
	"twins": [Color(1, 1, 1), Color(0.92, 0.9, 1.0), Color(0.68, 0.62, 0.8)],
}
const AMBIENCE_OF := {"courtyard": "courtyard", "crystal": "crystal", "burrow": "crypt", "colossus": "colossus", "sky": "sky",
		"twins": "twins", "forest": "forest", "final": "final"}

var info: Dictionary
var zone_id := ""
var kind := "hub"
var rows: PackedStringArray
var w := 0
var h := 0
var tilemap: TileMapLayer
var floor_decor: Node2D
var entities: Node2D
var player: Player
var arrow: Arrow
var camera: GameCamera
var marks := {}
var boss: Node2D
var boss_id := ""
var door_cells: Array = []
var door_body: StaticBody2D
var fight_started := false
var fight_over := false
var gates: Array = []
var pillars: Array = []
var crystals: Array = []
var wall_tile_top := 4
var floor_rng := RandomNumberGenerator.new()
var _retry_sent := false
var spawn_pos := Vector2.ZERO
var tiles_tex: Texture2D
var t := 0.0
var lore_points: Array = []
var ambience: Ambience
var lair: Lair
var tint: CanvasModulate
var tile_count := 12

func build(id: String, entry: String) -> void:
	zone_id = id
	info = ZoneData.zone_info(id)
	kind = info["kind"]
	boss_id = info.get("boss", "")
	rows = info["rows"]
	h = rows.size()
	w = rows[0].length()
	floor_rng.seed = 12345
	_build_tiles()
	_build_walls()
	floor_decor = Node2D.new()
	floor_decor.z_index = -5
	add_child(floor_decor)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_scan_marks()
	for d in info["decor"]:
		add_decor(d[0], d[1])
	for l in info.get("lore", []):
		add_decor("sword_grave", l["pos"])
		lore_points.append({"pos": l["pos"], "text": l["text"], "shown": false})
	_spawn_player(entry)
	match kind:
		"hub":
			_setup_hub(entry)
		"path":
			_setup_path()
		"arena":
			_setup_arena()
	_setup_ambience()

# ------------------------------------------------------------------ tiles & walls
func ch_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "#"
	return rows[y][x]

func is_wall(x: int, y: int) -> bool:
	return WALL_CHARS.contains(ch_at(x, y))

func _tile_for(x: int, y: int) -> int:
	var ch := ch_at(x, y)
	if WALL_CHARS.contains(ch):
		var open := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not is_wall(x + dx, y + dy):
					open = true
		if not open:
			return 6
		return 5 if not is_wall(x, y + 1) else 4
	match ch:
		",": return 8
		":": return 3
		";": return 9
		"o": return 10
		"_": return 7
		"D": return 10
		"f": return 12          # the Nexus: fire / ice / earth / storm quadrants
		"i": return 13
		"e": return 14
		"s": return 15
	return _floor_variant(x, y)

func _floor_variant(x: int, y: int) -> int:
	var v := (x * 7 + y * 13 + x * y) % 11
	if v < 6:
		return 0
	if v < 9:
		return 1
	return 2

func _build_tiles() -> void:
	tiles_tex = Gfx.tex("environment/tiles_%s.png" % info["theme"])
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tiles_tex
	src.texture_region_size = Vector2i(TILE, TILE)
	tile_count = int(tiles_tex.get_width() / TILE)
	for i in tile_count:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	tilemap = TileMapLayer.new()
	tilemap.tile_set = ts
	tilemap.z_index = -10
	add_child(tilemap)
	for y in h:
		for x in w:
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(_tile_for(x, y), 0))

func set_floor_tile(cell: Vector2i, idx: int) -> void:
	tilemap.set_cell(cell, 0, Vector2i(idx, 0))

func _wall_body(rect: Rect2, group := "") -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = L.WORLD
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	cs.shape = r
	b.position = rect.position + rect.size / 2.0
	b.add_child(cs)
	if group != "":
		b.add_to_group(group)
	add_child(b)
	return b

func _wall_collidable(x: int, y: int) -> bool:
	if not is_wall(x, y):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not is_wall(x + dx, y + dy):
				return true
	return false

func _build_walls() -> void:
	var group: String = "crystal" if info.get("reflective", false) else ""
	for y in h:
		var x := 0
		while x < w:
			if _wall_collidable(x, y):
				var x0 := x
				while x < w and _wall_collidable(x, y):
					x += 1
				_wall_body(Rect2(x0 * TILE, y * TILE, (x - x0) * TILE, TILE), group)
			else:
				x += 1
	# outside perimeter so nothing can leave the map
	var pw := w * TILE
	var ph := h * TILE
	_wall_body(Rect2(-64, -64, pw + 128, 64))
	_wall_body(Rect2(-64, ph, pw + 128, 64))
	_wall_body(Rect2(-64, 0, 64, ph))
	_wall_body(Rect2(pw, 0, 64, ph))

func camera_bounds() -> Rect2i:
	var pw := w * TILE
	var ph := h * TILE
	if ph - 270 < 24:
		ph = 270
	if pw - 480 < 24:
		pw = 480
	return Rect2i(0, 0, pw, ph)

# ------------------------------------------------------------------ marks / props
func cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)

func cell_base(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE)

func _scan_marks() -> void:
	for y in h:
		for x in w:
			var ch := ch_at(x, y)
			if ch == "." or ch == "#" or ch == "," or ch == ":" or ch == ";" or ch == "o" or ch == "_" or ch == "f" or ch == "i" or ch == "e" or ch == "s":
				continue
			match ch:
				"P":
					var p := Pillar.new()
					p.position = cell_base(x, y)
					p.breakable = true
					p.skin = info.get("pillar_skin", "pillar")
					entities.add_child(p)
					pillars.append(p)
				"C":
					var c := CrystalBlock.new()
					c.position = cell_base(x, y)
					c.skin = info.get("crystal_skin", "crystal_block")
					entities.add_child(c)
					crystals.append(c)
				"T":
					add_decor(info.get("spike_decor", "stalagmite"), cell_base(x, y))
				"D":
					door_cells.append(Vector2i(x, y))
				_:
					if not marks.has(ch):
						marks[ch] = []
					marks[ch].append(cell_center(x, y))

func mark(ch: String, idx := 0) -> Vector2:
	if marks.has(ch) and marks[ch].size() > idx:
		return marks[ch][idx]
	return Vector2.ZERO

func add_decor(name: String, pos: Vector2) -> Node2D:
	if FLOOR_DECOR.has(name):
		var fs := Gfx.sprite("environment/%s.png" % name, pos)
		floor_decor.add_child(fs)
		return fs
	var n := Node2D.new()
	n.position = pos
	if ANIM_DECOR.has(name):
		var a: Array = ANIM_DECOR[name]
		n.add_child(Gfx.strip("environment/%s.png" % a[0], a[1], a[2], a[3]))
		if a[4] > 0:
			_foot(n, a[4], a[5])
	elif DECOR.has(name):
		var d: Array = DECOR[name]
		n.add_child(Gfx.base_sprite("environment/%s.png" % d[0]))
		if d[1] > 0:
			_foot(n, d[1], d[2])
	else:
		n.add_child(Gfx.base_sprite("environment/%s.png" % name))
	if name == "grass_tuft":                      # sways in the wind
		var tw := n.create_tween().set_loops()
		var amp := 0.10 + randf() * 0.06
		tw.tween_property(n, "rotation", amp, 1.1 + randf() * 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation", -amp * 0.5, 1.1 + randf() * 0.8).set_trans(Tween.TRANS_SINE)
	entities.add_child(n)
	return n

func _foot(n: Node2D, fw: float, fh: float) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = L.WORLD
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(fw, fh)
	cs.shape = r
	cs.position = Vector2(0, -fh / 2.0)
	b.add_child(cs)
	n.add_child(b)

func add_floor_sprite(node: Node2D, pos: Vector2) -> void:
	node.position = pos
	floor_decor.add_child(node)

# ------------------------------------------------------------------ player & camera
func _spawn_player(entry: String) -> void:
	var spawns: Dictionary = info["spawns"]
	spawn_pos = spawns.get(entry, spawns.values()[0])
	player = PLAYER_SCENE.instantiate() as Player
	player.position = spawn_pos
	entities.add_child(player)
	arrow = player.arrow
	entities.add_child(arrow)
	arrow.global_position = spawn_pos
	camera = GameCamera.new()
	camera.position = Vector2(0, -8)
	player.add_child(camera)
	camera.set_bounds(camera_bounds())
	camera.reset_smoothing()
	player.died.connect(_on_player_died)

func _on_player_died() -> void:
	Game.record_death(boss_id)
	Sfx.play_music("")
	await get_tree().create_timer(0.95, true, false, true).timeout
	if not _retry_sent and is_inside_tree():
		_retry_sent = true
		retry_requested.emit()

func force_retry() -> void:
	if not _retry_sent:
		_retry_sent = true
		retry_requested.emit()

# ------------------------------------------------------------------ hub
func _setup_hub(entry: String) -> void:
	Game.show_banner(info["name"], "")
	var total_lit := 0
	var final_gate: Gate = null
	for y in h:
		for x in w:
			var ch := ch_at(x, y)
			if not GATE_BOSSES.has(ch):
				continue
			var b: String = GATE_BOSSES[ch]
			var g := Gate.new()
			g.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
			entities.add_child(g)
			var unlocked := Game.is_unlocked(b)
			var seen: bool = Game.seen_unlocked.has(b)
			g.setup(self, "path_" + b, "from_hub", b, b == "regent", not (unlocked and seen))
			gates.append(g)
			if b == "regent":
				final_gate = g
			if unlocked and not seen:
				_delayed_unlock(g, b)
	# six rune lights above the final gate: one per fallen guardian
	if final_gate:
		for i in 6:
			var id: String = Game.BOSS_ORDER[i]
			var l := Gfx.sprite("environment/rune_on.png" if Game.is_defeated(id) else "environment/rune_off.png")
			l.position = final_gate.position + Vector2(-25 + i * 10, -92)
			entities.add_child(l)
			if Game.is_defeated(id):
				total_lit += 1
	# sparkle checkpoint circle at the spawn
	var cp := Gfx.strip("environment/checkpoint.png", 40, 3, 5.0, false)
	add_floor_sprite(cp, spawns_center("start") + Vector2(0, -2))
	Sfx.play_music("hub")

const GATE_BOSSES := {"1": "warden", "2": "knight", "3": "burrower", "4": "colossus", "5": "hunter", "6": "twins", "7": "regent"}

func spawns_center(entry: String) -> Vector2:
	return info["spawns"].get(entry, spawn_pos)

func _delayed_unlock(g: Gate, b: String) -> void:
	player.locked = true
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	camera.position_smoothing_speed = 3.0
	g.unlock(true)
	Game.seen_unlocked[b] = true
	Game.say("A SEAL HAS BROKEN: " + Game.BOSS_NAMES[b], 3.5)
	Game.save_game()
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		player.locked = false
		camera.position_smoothing_speed = 7.0

# ------------------------------------------------------------------ path
func _setup_path() -> void:
	Game.show_banner(info["name"], "")
	# arena gate at the top
	for y in h:
		for x in w:
			if ch_at(x, y) == "A":
				var g := Gate.new()
				g.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
				entities.add_child(g)
				g.setup(self, "arena_" + boss_id, "start", boss_id, false, false)
				gates.append(g)
	var cp := Gfx.strip("environment/checkpoint.png", 40, 3, 5.0, false)
	add_floor_sprite(cp, mark("a") + Vector2(0, 2))
	Sfx.play_music("path")

func _physics_process(delta: float) -> void:
	t += delta
	if player and not player.dead:
		for l in lore_points:
			if not l["shown"] and player.global_position.distance_to(l["pos"]) < 30.0:
				l["shown"] = true
				Game.say(l["text"], 5.0)
	if kind == "path" and player and not player.dead:
		if player.global_position.y > (h - 1) * TILE + 6:
			request_zone.emit("hub", "from_" + boss_id)
	if kind == "arena":
		_arena_tick()

# ------------------------------------------------------------------ arena
func _setup_arena() -> void:
	var packed: PackedScene = load(BOSS_SCENES[boss_id])
	boss = packed.instantiate()
	var bp := mark("B")
	boss.position = bp
	entities.add_child(boss)
	boss.call("setup", self)
	boss.connect("defeated", _on_boss_defeated)
	var cp := Gfx.strip("environment/checkpoint.png", 40, 3, 5.0, false)
	add_floor_sprite(cp, spawn_pos + Vector2(0, -2))
	Sfx.play("checkpoint", -8.0)
	Sfx.play_music("path")
	player.locked = false
	if ["courtyard", "crystal", "burrow", "colossus", "sky", "twins", "final"].has(info["theme"]):
		lair = Lair.new()
		add_child(lair)
		lair.setup(self, info["theme"])

func _arena_tick() -> void:
	if fight_started or fight_over or player.dead:
		return
	if player.global_position.y < (h - 1) * TILE - 18:
		start_fight()

func start_fight() -> void:
	if fight_started:
		return
	fight_started = true
	if lair:
		lair.start()
	close_door()
	Game.show_banner(Game.BOSS_NAMES[boss_id], Game.BOSS_TAGLINES[boss_id])
	Sfx.play_music(info["music"])
	boss.call("start_fight")
	fight_started_signal.emit()
	await get_tree().create_timer(2.6).timeout
	if is_inside_tree() and not fight_over and not player.dead:
		Game.say(Game.BOSS_TIPS[boss_id], 5.0)

func close_door() -> void:
	if door_cells.is_empty():
		return
	var minx := 9999
	var maxx := -1
	for c in door_cells:
		set_floor_tile(c, 4)
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
	var y: int = door_cells[0].y
	door_body = _wall_body(Rect2(minx * TILE, y * TILE, (maxx - minx + 1) * TILE, TILE))
	# also the cell the spawn stands in
	Fx.dust(entities, Vector2((minx + maxx + 1) * TILE / 2.0, y * TILE + 4), 10)
	Sfx.play("thud")
	Game.add_trauma(0.3)

func open_door() -> void:
	if door_body:
		door_body.queue_free()
		door_body = null
	for c in door_cells:
		set_floor_tile(c, 10)
	set_floor_tile(Vector2i(w / 2, h - 1), 10)

func _on_boss_defeated() -> void:
	if fight_over:
		return
	fight_over = true
	if lair:
		lair.stop()
	Game.mark_defeated(boss_id)
	if boss_id == "regent":
		Game.finished = true
		Game.save_game()
	Sfx.stop_music(1.5)
	await get_tree().create_timer(2.2, true, false, true).timeout
	if not is_inside_tree():
		return
	if boss_id == "regent":
		await get_tree().create_timer(1.5, true, false, true).timeout
		ending_requested.emit()
		return
	Game.show_banner("FOE VANQUISHED", Game.BOSS_NAMES[boss_id])
	open_door()
	var pt := ExitPortal.new()
	pt.position = mark("X") + Vector2(0, 8)
	entities.add_child(pt)
	pt.setup(self, "hub", "from_" + boss_id)
	Sfx.play_music("hub")
	Game.say("THE PORTAL AWAITS", 3.0)

# ------------------------------------------------------------------ lair ambience and phase changes
func _setup_ambience() -> void:
	var k: String = AMBIENCE_OF.get(info["theme"], "")
	if k == "" or kind == "hub":
		return
	ambience = Ambience.new()
	add_child(ambience)
	ambience.setup(k, Rect2(0, 0, w * TILE, h * TILE))

## Called by a boss when it enters phase p: the lair escalates with it (ambience speeds up, floor tiles change, the light shifts).
func on_phase(p: int) -> void:
	if kind != "arena":
		return
	if ambience:
		ambience.set_phase(p)
	if lair:
		lair.set_phase(p)
	var theme: String = info["theme"]
	if PHASE_TINT.has(theme):
		if tint == null:
			tint = CanvasModulate.new()
			add_child(tint)
		create_tween().tween_property(tint, "color", PHASE_TINT[theme][clampi(p, 1, 3) - 1], 1.4)
	if p >= 2 and tile_count >= 14 and theme != "final":
		_ripple_floor(p)

func _ripple_floor(p: int) -> void:
	var origin: Vector2 = boss.global_position if boss else Vector2(w * TILE / 2.0, h * TILE / 2.0)
	var cells: Array = []
	for y in h:
		for x in w:
			if ch_at(x, y) != ".":
				continue
			var hsh := (x * 73 + y * 151 + x * y * 7) % 100
			if hsh < (14 if p == 2 else 26):
				cells.append({"c": Vector2i(x, y), "d": cell_center(x, y).distance_to(origin), "t": 12 if p == 2 else 13})
	cells.sort_custom(func(a, b): return a["d"] < b["d"])
	var i := 0
	while i < cells.size():
		for k in 10:
			if i >= cells.size():
				break
			set_floor_tile(cells[i]["c"], cells[i]["t"])
			i += 1
		await get_tree().process_frame
		if not is_inside_tree():
			return
