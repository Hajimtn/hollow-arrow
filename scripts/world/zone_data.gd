class_name ZoneData
## Builds ASCII layouts and decoration lists for every zone in the game.
##
## Map legend:  # wall   . floor   , accent floor   : cracked   ; rubble   o dark   _ rune floor
##   @ player spawn   D arena door   B boss spawn   X exit portal   P pillar   C crystal block
##   T stalagmite     v return trigger   A arena gate   1-7 hub gates   a-h marks

const TILE := 16

const BOSS_INDEX := {"warden": "1", "knight": "2", "burrower": "3", "regent": "7", "colossus": "4", "hunter": "5", "twins": "6"}
const GATE_BOSS := {"1": "warden", "2": "knight", "3": "burrower", "4": "colossus", "5": "hunter", "6": "twins", "7": "regent"}

const THEME_OF := {
	"warden": "courtyard", "knight": "crystal", "burrower": "burrow", "colossus": "colossus",
	"hunter": "sky", "twins": "twins", "regent": "final",
}
const PATH_NAMES := {
	"warden": "OVERGROWN CLOISTER", "knight": "GLASS CAVERNS", "burrower": "THE CANDLELIT CRYPT",
	"colossus": "RUSTED CAUSEWAY", "hunter": "WINDSWEPT STAIRS", "twins": "HALL OF TWO SUNS",
	"regent": "THE ASHEN STAIR",
}
const PATH_THEME := {
	"warden": "forest", "knight": "crystal", "burrower": "burrow", "colossus": "colossus",
	"hunter": "sky", "twins": "twins", "regent": "final",
}
const PATH_LORE := {
	"warden": ["ROOTS HAVE SWALLOWED THE CLOISTER. THE WARDEN NEVER LEFT ITS POST.", "A STONE HAND POINTS ONWARD: 'BREAK WHAT HOLDS IT UP.'"],
	"knight": ["THE VAULT WAS SPUN FROM GLASS SO THE KING COULD WATCH HIS KNIGHT FROM EVERY SIDE.", "ONLY THE BACK OF A MIRROR CASTS NO REFLECTION."],
	"burrower": ["THE JUDGE DIED WITH THE LAST CANDLE. NOTHING MORTAL CAN TOUCH IT.", "'ONLY LIGHT REMEMBERS THE FLESH.' SCRATCHED INTO A LANTERN."],
	"colossus": ["IRON CHAINS RUN INTO THE DARK. SOMETHING VAST STRAINS AGAINST THEM.", "THE PYLONS WERE BUILT TO HOLD IT. THEY CAN BE UNDONE."],
	"hunter": ["THE STAIRS CLIMB INTO THE WIND. FEATHERS LITTER EVERY STEP.", "IT DIVES AT WHATEVER MOVES. LET IT LAND."],
	"twins": ["SUN AND MOON, EACH ARMORED BY THE OTHER'S LIGHT.", "TWO FLAMES, ONE OATH. BREAK THE OATH."],
	"regent": ["THE ASHEN STAIR, WHERE THE KING RECEIVED HIS SIX CHAMPIONS.", "'THE CROWN REMEMBERS EVERY LESSON.'"],
}
const ARENA_SIZE := {
	"warden": Vector2i(30, 17), "knight": Vector2i(30, 17), "burrower": Vector2i(38, 20),
	"colossus": Vector2i(34, 21), "hunter": Vector2i(36, 20), "twins": Vector2i(32, 19), "regent": Vector2i(40, 22),
}

# ------------------------------------------------------------------ grid helpers
static func _grid(w: int, h: int, ch: String) -> Array:
	var g := []
	for y in h:
		var row := []
		for x in w:
			row.append(ch)
		g.append(row)
	return g

static func _rect(g: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			if j >= 0 and j < g.size() and i >= 0 and i < g[0].size():
				g[j][i] = ch

static func _put(g: Array, x: int, y: int, ch: String) -> void:
	if y >= 0 and y < g.size() and x >= 0 and x < g[0].size():
		g[y][x] = ch

static func _rows(g: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for r in g:
		out.append("".join(r))
	return out

static func zone_info(id: String) -> Dictionary:
	if id == "hub":
		return hub()
	if id.begins_with("path_"):
		return path(id.substr(5))
	if id.begins_with("arena_"):
		return arena(id.substr(6))
	return hub()

# ------------------------------------------------------------------ hub
static func hub() -> Dictionary:
	var W := 56
	var H := 36
	var g := _grid(W, H, "#")
	_rect(g, 1, 5, W - 2, H - 6, ".")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# scattered cracks and accent patches
	for i in 70:
		var x := rng.randi_range(2, W - 3)
		var y := rng.randi_range(6, H - 3)
		g[y][x] = ":" if rng.randf() < 0.55 else ","
	# rune ring around the fountain
	for a in 48:
		var ang := TAU * a / 48.0
		_put(g, 28 + int(round(cos(ang) * 8.0)), 20 + int(round(sin(ang) * 6.0)), "_")
	# gate markers on the north wall face row
	var gate_x := {"1": 7, "2": 14, "3": 21, "7": 28, "4": 35, "5": 42, "6": 49}
	for k in gate_x:
		g[4][gate_x[k]] = k
	_put(g, 28, 32, "@")
	var decor := []
	# banners
	for tx in [10, 17, 38, 45]:
		decor.append(["banner", Vector2(tx * TILE + 8, 5 * TILE - 2)])
	# braziers flank the final gate and stand in the plaza
	for tx in [24, 32]:
		decor.append(["brazier", Vector2(tx * TILE + 8, 5 * TILE + 14)])
	for p in [Vector2(12, 12), Vector2(44, 12), Vector2(12, 28), Vector2(44, 28)]:
		decor.append(["brazier", p * TILE + Vector2(8, 8)])
	decor.append(["fountain", Vector2(28 * TILE + 8, 21 * TILE)])
	decor.append(["statue_knight", Vector2(19 * TILE + 8, 15 * TILE)])
	decor.append(["statue_hood", Vector2(37 * TILE + 8, 15 * TILE)])
	decor.append(["statue_broken", Vector2(19 * TILE + 8, 27 * TILE)])
	decor.append(["statue_knight", Vector2(37 * TILE + 8, 27 * TILE)])
	decor.append(["waterfall", Vector2(3 * TILE, 5 * TILE - 4)])
	decor.append(["waterfall", Vector2(53 * TILE, 5 * TILE - 4)])
	decor.append(["skeleton", Vector2(9 * TILE, 31 * TILE)])
	decor.append(["fallen_column", Vector2(46 * TILE, 30 * TILE)])
	decor.append(["fallen_column", Vector2(8 * TILE, 21 * TILE)])
	decor.append(["pillar", Vector2(4 * TILE + 8, 9 * TILE)])
	decor.append(["pillar_broken", Vector2(51 * TILE + 8, 9 * TILE)])
	decor.append(["altar", Vector2(28 * TILE, 12 * TILE)])
	decor.append(["sword_grave", Vector2(24 * TILE, 32 * TILE)])
	decor.append(["sword_grave", Vector2(33 * TILE, 33 * TILE)])
	for pos in [Vector2(3, 33), Vector2(52, 33), Vector2(2, 15), Vector2(53, 16)]:
		decor.append([["tree_a", "tree_b", "tree_dead"][rng.randi() % 3], pos * TILE + Vector2(8, 16)])
	for i in 26:
		var x2 := rng.randi_range(3, W - 4)
		var y2 := rng.randi_range(8, H - 3)
		if Vector2(x2, y2).distance_to(Vector2(28, 21)) < 10:
			continue
		decor.append([["bones", "flowers", "bush", "rubble", "mushrooms", "flowers"][rng.randi() % 6], Vector2(x2 * TILE + 8, y2 * TILE + 12)])
	var spawns := {"start": Vector2(28 * TILE + 8, 32 * TILE + 12)}
	for k in gate_x:
		spawns["from_" + GATE_BOSS[k]] = Vector2(gate_x[k] * TILE + 8, 7 * TILE + 12)
	var lore := [
		{"pos": Vector2(28 * TILE, 14 * TILE), "text": "AN ALTAR TO THE SIX GUARDIANS, WHO ONCE SWORE TO PROTECT THE KING."},
		{"pos": Vector2(22 * TILE, 26 * TILE), "text": "THE FOUNTAIN RAN DRY THE NIGHT THE COURT FELL."},
		{"pos": Vector2(36 * TILE, 32 * TILE), "text": "FIVE GATES STAND OPEN. THE SIXTH WAKES AFTER THREE GUARDIANS FALL."},
	]
	return {"id": "hub", "name": "THE HOLLOW COURT", "kind": "hub", "theme": "hub", "rows": _rows(g), "decor": decor,
			"music": "hub", "spawns": spawns, "lore": lore}

# ------------------------------------------------------------------ paths (short atmospheric walks)
static func path(boss: String) -> Dictionary:
	var W := 30
	var H := 46
	var g := _grid(W, H, "#")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + BOSS_INDEX[boss].to_int() * 31
	var cx := 15
	var band := 5
	var centers := {}
	for y in range(H - 2, 3, -1):
		if y % 4 == 0:
			cx = clampi(cx + rng.randi_range(-2, 2), 10, 20)
		var hw := band
		if y in range(30, 38) or y in range(10, 17):
			hw = 8   # small clearings
		centers[y] = cx
		for x in range(cx - hw, cx + hw + 1):
			_put(g, x, y, "." if rng.randf() < 0.85 else ",")
	# return trigger row at the bottom and arena gate at the top
	var bx: int = centers[H - 2]
	for x in range(bx - band, bx + band + 1):
		_put(g, x, H - 1, "v")
	var tx: int = centers[4]
	_put(g, tx, 3, "A")
	_put(g, bx, H - 4, "@")
	_put(g, tx, 5, "a")
	var decor := []
	var theme: String = PATH_THEME[boss]
	var lists := {
		"warden": ["tree_a", "tree_b", "bush", "statue_broken", "fallen_column", "flowers", "rubble", "tree_dead", "statue_hood"],
		"knight": ["ice_spire_a", "ice_spire_b", "snow_drift", "ice_spire_a", "bones", "rubble"],
		"burrower": ["tombstone", "skull_pile", "coffin", "chop_block", "tombstone", "sword_grave", "hang_cage", "tombstone"],
		"colossus": ["basalt_col", "banner_lava", "rubble", "anvil", "fallen_column", "statue_knight", "bones", "basalt_col"],
		"hunter": ["statue_broken", "grass_tuft", "pillar_broken", "wind_banner", "rubble", "feather_pile", "sword_grave", "tree_dead"],
		"twins": ["obelisk", "statue_hood", "brazier_cool", "banner_violet", "obelisk", "brazier", "rubble", "pillar"],
		"regent": ["statue_knight", "brazier", "banner", "pillar", "statue_broken", "bones", "sword_grave"],
	}
	var pool: Array = lists[boss]
	var tall := ["tree_a", "tree_b", "crystal_a", "crystal_b", "stalagmite", "pillar", "statue_knight", "statue_hood", "banner", "tree_dead",
			"pillar_broken", "statue_broken", "brazier", "brazier_cool", "ice_spire_a", "ice_spire_b", "bone_spike", "hang_cage", "chop_block",
			"basalt_col", "banner_lava", "anvil", "wind_banner", "obelisk", "banner_violet", "rib_cage", "tombstone", "coffin"]
	# edge dressing: blockers along the band edges, small stuff inside
	for y in range(6, H - 5, 2):
		var c: int = centers.get(y, 15)
		var hw := 8 if (y in range(30, 38) or y in range(10, 17)) else band
		for side in [-1, 1]:
			if rng.randf() < 0.75:
				var n: String = pool[rng.randi() % pool.size()]
				if n in tall:
					decor.append([n, Vector2((c + side * (hw + 1)) * TILE + 8, y * TILE + 14)])
		if rng.randf() < 0.55:
			var smalls := {"forest": ["bones", "rubble", "flowers", "mushrooms", "bush"], "crystal": ["snow_drift", "snow_drift", "bones", "rubble"],
					"burrow": ["skull_pile", "bones", "bones", "rubble"], "colossus": ["rubble", "bones", "rubble", "sword_grave"],
					"sky": ["grass_tuft", "grass_tuft", "feather_pile", "flowers", "rubble"], "twins": ["rubble", "bones", "sword_grave", "rubble"],
					"final": ["rubble", "bones", "sword_grave", "rubble"]}
			var sl: Array = smalls.get(theme, ["bones", "rubble"])
			var s: String = sl[rng.randi() % sl.size()]
			decor.append([s, Vector2((c + rng.randi_range(-band + 1, band - 1)) * TILE + 8, y * TILE + 12)])
	# one big set-piece in the middle clearing
	var mid: int = centers[34]
	match boss:
		"warden": decor.append(["skeleton", Vector2(mid * TILE, 35 * TILE)])
		"knight": decor.append(["altar", Vector2(mid * TILE, 34 * TILE)])
		"burrower": decor.append(["gallows", Vector2(mid * TILE, 36 * TILE)])
		"colossus": decor.append(["fallen_column", Vector2(mid * TILE, 35 * TILE)])
		"hunter": decor.append(["watchtower", Vector2(mid * TILE, 36 * TILE)])
		"twins": decor.append(["fountain", Vector2(mid * TILE, 35 * TILE)])
		"regent": decor.append(["throne", Vector2(mid * TILE, 35 * TILE)])
	if boss == "warden":
		decor.append(["waterfall", Vector2((centers[12] - 9) * TILE, 12 * TILE)])
	if boss == "twins":
		decor.append(["brazier_cool", Vector2((centers[12] + 9) * TILE, 12 * TILE)])
	# braziers mark the checkpoint at the arena approach
	decor.append(["brazier", Vector2((tx - 3) * TILE + 8, 7 * TILE)])
	decor.append(["brazier", Vector2((tx + 3) * TILE + 8, 7 * TILE)])
	var lore := []
	var lt: Array = PATH_LORE[boss]
	lore.append({"pos": Vector2((centers[40] + 3) * TILE, 40 * TILE + 8), "text": lt[0]})
	lore.append({"pos": Vector2((centers[15] - 3) * TILE, 15 * TILE + 8), "text": lt[1]})
	return {"id": "path_" + boss, "name": PATH_NAMES[boss], "kind": "path", "theme": theme, "rows": _rows(g), "decor": decor,
			"music": "path", "boss": boss, "lore": lore,
			"spawns": {"from_hub": Vector2(bx * TILE + 8, (H - 4) * TILE + 12), "from_arena": Vector2(tx * TILE + 8, 6 * TILE + 12)}}


# ------------------------------------------------------------------ arenas
static func _arena_base(w: int, h: int) -> Array:
	var g := _grid(w, h, "#")
	_rect(g, 1, 2, w - 2, h - 3, ".")
	var cx := w / 2
	for x in range(cx - 1, cx + 2):
		g[h - 1][x] = "D"
	g[h - 1][cx] = "@"
	g[h - 1][cx - 1] = "D"
	g[3][cx] = "X"
	return g

static func arena(boss: String) -> Dictionary:
	var sz: Vector2i = ARENA_SIZE[boss]
	var w := sz.x
	var h := sz.y
	var g := _arena_base(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + BOSS_INDEX[boss].to_int()
	var decor := []
	var music := "battle"
	var reflective := false
	var extra := {}
	match boss:
		"warden":
			# RUNE SANCTUM: grey-green flagstones, cyan rune pillars and a floor circle under the golem
			for p in [Vector2i(8, 6), Vector2i(21, 6), Vector2i(8, 11), Vector2i(21, 11)]:
				_put(g, p.x, p.y, "P")
			_put(g, 15, 5, "B")
			extra["pillar_skin"] = "pillar_rune"
			decor.append(["rune_circle", Vector2(15 * TILE + 8, 8 * TILE + 8)])
			for x in [4, 9, 15, 21, 26]:
				decor.append(["vines", Vector2(x * TILE + 8, 2 * TILE)])
			decor.append(["banner_teal", Vector2(6 * TILE + 8, 2 * TILE)])
			decor.append(["banner_teal", Vector2(23 * TILE + 8, 2 * TILE)])
			decor.append(["statue_broken", Vector2(3 * TILE + 8, 4 * TILE)])
			decor.append(["statue_hood", Vector2(26 * TILE + 8, 4 * TILE)])
			decor.append(["rubble", Vector2(2 * TILE + 8, 13 * TILE)])
			decor.append(["rubble", Vector2(27 * TILE + 8, 13 * TILE)])
		"knight":
			# FROZEN VAULT: ice floor, frozen waterfall, ice spires, snow drifts
			for p in [Vector2i(9, 6), Vector2i(20, 6), Vector2i(9, 11), Vector2i(20, 11)]:
				_put(g, p.x, p.y, "C")
			_put(g, 14, 9, "C")
			_put(g, 15, 9, "C")
			_put(g, 15, 5, "B")
			reflective = true
			extra["crystal_skin"] = "crystal_block_ice"
			decor.append(["frozen_fall", Vector2(15 * TILE + 8, 2 * TILE + 4)])
			for x in [6, 11, 19, 24]:
				decor.append(["icicles", Vector2(x * TILE + 8, 2 * TILE)])
			decor.append(["ice_spire_b", Vector2(3 * TILE, 4 * TILE)])
			decor.append(["ice_spire_a", Vector2(26 * TILE, 4 * TILE)])
			decor.append(["ice_spire_a", Vector2(3 * TILE, 13 * TILE)])
			decor.append(["ice_spire_b", Vector2(26 * TILE, 13 * TILE)])
			for q in [Vector2(5, 14), Vector2(24, 14), Vector2(2, 9), Vector2(27, 8)]:
				decor.append(["snow_drift", q * TILE + Vector2(8, 0)])
			decor.append(["brazier_cool", Vector2(2 * TILE + 8, 8 * TILE)])
			decor.append(["brazier_cool", Vector2(27 * TILE + 8, 8 * TILE)])
			decor.append(["banner_ice", Vector2(10 * TILE + 8, 2 * TILE)])
			decor.append(["banner_ice", Vector2(20 * TILE + 8, 2 * TILE)])
			music = "battle2"
		"burrower":
			# CANDLELIT CRYPT: dark flagstones, tombstones for pillars, coffins, a gallows, four lanterns to light with arrows
			for p in [Vector2i(9, 7), Vector2i(28, 7), Vector2i(9, 14), Vector2i(28, 14), Vector2i(19, 10)]:
				_put(g, p.x, p.y, "T")
			_put(g, 19, 6, "B")
			for lp in [Vector2i(7, 11), Vector2i(31, 11), Vector2i(14, 16), Vector2i(24, 16)]:
				_put(g, lp.x, lp.y, "l")
			for i in 30:
				g[rng.randi_range(3, h - 3)][rng.randi_range(2, w - 3)] = ","
			extra["spike_decor"] = "tombstone"
			decor.append(["coffin", Vector2(31 * TILE, 16 * TILE)])
			decor.append(["coffin", Vector2(5 * TILE, 16 * TILE)])
			decor.append(["gallows", Vector2(33 * TILE, 6 * TILE)])
			decor.append(["chop_block", Vector2(4 * TILE + 8, 6 * TILE)])
			decor.append(["hang_cage", Vector2(2 * TILE + 8, 10 * TILE)])
			for q in [Vector2(8, 16), Vector2(30, 8), Vector2(20, 17), Vector2(35, 12)]:
				decor.append(["skull_pile", q * TILE + Vector2(8, 0)])
			decor.append(["banner_ash", Vector2(12 * TILE + 8, 2 * TILE)])
			decor.append(["banner_ash", Vector2(26 * TILE + 8, 2 * TILE)])
		"colossus":
			# FOUNDRY: black basalt, lava vents in the wall, iron pylons, hanging chains
			_put(g, 17, 5, "B")
			_put(g, 4, 10, "a")
			_put(g, 29, 10, "b")
			_put(g, 17, 15, "c")
			for i in 26:
				var cx := rng.randi_range(2, w - 3)
				var cy := rng.randi_range(3, h - 3)
				if g[cy][cx] == ".":
					g[cy][cx] = ":"
			for x in [8, 14, 20, 26]:
				decor.append(["lava_vent", Vector2(x * TILE + 8, 2 * TILE)])
			for x in [11, 23]:
				decor.append(["hang_chain", Vector2(x * TILE + 8, 2 * TILE)])
			decor.append(["banner_lava", Vector2(5 * TILE + 8, 2 * TILE)])
			decor.append(["banner_lava", Vector2(28 * TILE + 8, 2 * TILE)])
			decor.append(["basalt_col", Vector2(3 * TILE, 17 * TILE)])
			decor.append(["basalt_col", Vector2(30 * TILE, 17 * TILE)])
			decor.append(["anvil", Vector2(7 * TILE, 17 * TILE)])
			decor.append(["anvil", Vector2(26 * TILE, 17 * TILE)])
			decor.append(["brazier", Vector2(2 * TILE + 8, 5 * TILE)])
			decor.append(["brazier", Vector2(31 * TILE + 8, 5 * TILE)])
			music = "battle2"
		"hunter":
			# AERIE: pale mossy stone on a cliff top, a ruined watchtower, wind-torn banners, grass
			_put(g, 18, 8, "B")
			for p in [Vector2(3, 5), Vector2(3, 15), Vector2(32, 15)]:
				decor.append(["pillar_broken", p * TILE + Vector2(8, 12)])
			decor.append(["watchtower", Vector2(32 * TILE + 8, 6 * TILE)])
			decor.append(["statue_broken", Vector2(18 * TILE, 3 * TILE + 8)])
			decor.append(["wind_banner", Vector2(10 * TILE + 8, 3 * TILE)])
			decor.append(["wind_banner", Vector2(26 * TILE + 8, 3 * TILE)])
			for i in 30:
				g[rng.randi_range(3, h - 3)][rng.randi_range(2, w - 3)] = ":"
			for i in 14:
				var gx := rng.randi_range(3, w - 4)
				var gy := rng.randi_range(4, h - 3)
				if abs(gx - 18) + abs(gy - 8) > 6:
					decor.append(["grass_tuft", Vector2(gx * TILE + 8, gy * TILE + 12)])
			for q in [Vector2(6, 16), Vector2(25, 11), Vector2(14, 5)]:
				decor.append(["feather_pile", q * TILE + Vector2(8, 12)])
		"twins":
			# OBSERVATORY: violet stone, a gold ring, the sun disc on the left and the moon disc on the right
			_put(g, 16, 8, "B")
			decor.append(["sun_disc", Vector2(10 * TILE + 8, 9 * TILE + 8)])
			decor.append(["moon_disc", Vector2(22 * TILE + 8, 9 * TILE + 8)])
			for p in [Vector2(3, 5), Vector2(3, 14)]:
				decor.append(["brazier", p * TILE + Vector2(8, 12)])
			for p in [Vector2(28, 5), Vector2(28, 14)]:
				decor.append(["brazier_cool", p * TILE + Vector2(8, 12)])
			decor.append(["obelisk", Vector2(6 * TILE + 8, 4 * TILE)])
			decor.append(["obelisk", Vector2(25 * TILE + 8, 4 * TILE)])
			decor.append(["banner_violet", Vector2(10 * TILE + 8, 2 * TILE)])
			decor.append(["banner_violet", Vector2(21 * TILE + 8, 2 * TILE)])
			for a in 32:
				var ang := TAU * a / 32.0
				_put(g, 16 + int(round(cos(ang) * 7.0)), 9 + int(round(sin(ang) * 5.0)), "_")
		"regent":
			# THE NEXUS: four elemental quadrants meet at a rune ring; a shrine of each element stands in its corner
			_put(g, 20, 9, "B")
			_put(g, 20, 11, "a")
			for y in range(2, h - 1):
				for x in range(1, w - 1):
					if g[y][x] == ".":
						var right := x >= w / 2
						var low := y >= h / 2
						g[y][x] = "s" if (right and low) else ("i" if right else ("e" if low else "f"))
			for a in 40:
				var ang := TAU * a / 40.0
				_put(g, 20 + int(round(cos(ang) * 9.0)), 11 + int(round(sin(ang) * 6.0)), "_")
			for sh in [["j", Vector2i(4, 5)], ["u", Vector2i(35, 5)], ["y", Vector2i(4, 17)], ["z", Vector2i(35, 17)]]:
				_put(g, sh[1].x, sh[1].y, sh[0])
			decor.append(["throne", Vector2(20 * TILE, 3 * TILE + 8)])
			for tx in [11, 28]:
				decor.append(["brazier", Vector2(tx * TILE + 8, 4 * TILE)])
			# one banner per fallen guardian, in the colours of their lair
			var names := ["banner_teal", "banner_ice", "banner_ash", "banner_lava", "banner_wind", "banner_violet"]
			var xs := [6, 10, 14, 26, 30, 34]
			for k in 6:
				decor.append([names[k], Vector2(xs[k] * TILE + 8, 2 * TILE)])
			music = "final"
	return {"id": "arena_" + boss, "name": Game.BOSS_NAMES[boss], "kind": "arena", "theme": THEME_OF[boss], "rows": _rows(g),
			"decor": decor, "music": music, "boss": boss, "reflective": reflective,
			"spawns": {"start": Vector2((w / 2) * TILE + 8, (h - 1) * TILE + 12)}}.merged(extra)
