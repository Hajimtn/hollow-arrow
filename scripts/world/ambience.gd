class_name Ambience
extends Node2D
## Cheap ambient motion per biome: one node, one _draw, a few dozen particles. The boss calls set_phase() as the fight escalates
## (faster wind, denser snow, more embers, storm lightning).
##   courtyard  drifting cyan runic motes     crystal   snow            burrow  falling ash
##   colossus   rising embers                  sky       leaves + cloud shadows (+ lightning from phase 2)
##   twins      twinkling stars + gold dust    forest    fireflies       final   violet embers

const CFG := {
	"courtyard": {"n": 26, "cols": [Color("5fe0e0"), Color("b8fafa")], "vx": [-3.0, 3.0], "vy": [-14.0, -5.0], "size": [1, 2], "sway": 5.0, "alpha": 0.7, "twinkle": 2.0},
	"crystal": {"n": 70, "cols": [Color("ffffff"), Color("dff0ff")], "vx": [-4.0, 4.0], "vy": [14.0, 30.0], "size": [1, 2], "sway": 7.0, "alpha": 0.85, "twinkle": 0.0},
	"burrow": {"n": 44, "cols": [Color("8a8378"), Color("5a534c"), Color("d8ccb0"), Color("ef6a2a")], "vx": [6.0, 16.0], "vy": [5.0, 13.0], "size": [1, 2], "sway": 3.0, "alpha": 0.8, "twinkle": 0.0},
	"crypt": {"n": 34, "cols": [Color("a8d8ff"), Color("e8f0ff"), Color("8a80c0")], "vx": [-2.0, 2.0], "vy": [-12.0, -4.0], "size": [1, 2], "sway": 5.0, "alpha": 0.8, "twinkle": 2.6},
	"colossus": {"n": 44, "cols": [Color("ff8a30"), Color("ffc060"), Color("ef4a1e")], "vx": [-4.0, 4.0], "vy": [-32.0, -12.0], "size": [1, 2], "sway": 6.0, "alpha": 0.9, "twinkle": 9.0},
	"sky": {"n": 22, "cols": [Color("a8c890"), Color("d8d0a0"), Color("f7efdf")], "vx": [26.0, 52.0], "vy": [-4.0, 6.0], "size": [2, 2], "sway": 10.0, "alpha": 0.8, "twinkle": 0.0},
	"twins": {"n": 56, "cols": [Color("f7efdf"), Color("a89ad0"), Color("e8b050")], "vx": [-1.0, 1.0], "vy": [-2.0, 1.0], "size": [1, 1], "sway": 1.0, "alpha": 0.9, "twinkle": 3.0},
	"forest": {"n": 18, "cols": [Color("e8e070"), Color("c8f080")], "vx": [-5.0, 5.0], "vy": [-6.0, 4.0], "size": [1, 2], "sway": 8.0, "alpha": 0.9, "twinkle": 2.5},
	"final": {"n": 30, "cols": [Color("9b8cff"), Color("e8b050"), Color("db4f3a")], "vx": [-3.0, 3.0], "vy": [-16.0, -6.0], "size": [1, 2], "sway": 4.0, "alpha": 0.8, "twinkle": 2.0},
}
const PHASE_SPEED := [1.0, 1.5, 2.3]
const PHASE_FRAC := [0.6, 0.85, 1.0]

var kind := ""
var area := Rect2()
var parts: Array = []
var clouds: Array = []
var speed_mult := 1.0
var wind := Vector2.ZERO          # extra drift (the aerie lair sets it)
var active_frac := 0.6
var phase := 1
var t := 0.0
var lightning_t := 5.0
var flash_rect: ColorRect

func setup(k: String, rect: Rect2) -> void:
	kind = k
	area = rect
	z_index = 50
	if not CFG.has(k):
		set_process(false)
		return
	var c: Dictionary = CFG[k]
	var dens := clampf(rect.get_area() / (480.0 * 270.0), 1.0, 2.5)
	var n := int(int(c["n"]) * dens * 1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in n:
		var cols: Array = c["cols"]
		parts.append({
			"p": rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y),
			"v": Vector2(rng.randf_range(c["vx"][0], c["vx"][1]), rng.randf_range(c["vy"][0], c["vy"][1])),
			"s": float(rng.randi_range(c["size"][0], c["size"][1])),
			"c": cols[rng.randi() % cols.size()],
			"ph": rng.randf() * TAU,
		})
	if k == "sky":
		for i in 6:
			clouds.append({"p": rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y),
					"r": Vector2(rng.randf_range(50, 90), rng.randf_range(22, 38)), "v": rng.randf_range(7.0, 14.0)})
	set_phase(1)

func set_phase(p: int) -> void:
	phase = clampi(p, 1, 3)
	speed_mult = PHASE_SPEED[phase - 1]
	active_frac = PHASE_FRAC[phase - 1]
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	if not CFG.has(kind):
		return
	var c: Dictionary = CFG[kind]
	var count := int(parts.size() * active_frac)
	for i in count:
		var q: Dictionary = parts[i]
		var p: Vector2 = q["p"]
		var v: Vector2 = q["v"]
		p += (v + wind * 0.45) * delta * speed_mult
		p.x += sin(t * 1.3 + float(q["ph"])) * float(c["sway"]) * delta
		if p.x > area.end.x:
			p.x = area.position.x
		elif p.x < area.position.x:
			p.x = area.end.x
		if p.y > area.end.y:
			p.y = area.position.y
		elif p.y < area.position.y:
			p.y = area.end.y
		q["p"] = p
	for cl in clouds:
		var cp: Vector2 = cl["p"]
		cp.x += float(cl["v"]) * delta * speed_mult
		if cp.x - float(cl["r"].x) > area.end.x:
			cp.x = area.position.x - float(cl["r"].x)
		cl["p"] = cp
	if kind == "sky" and phase >= 2:
		lightning_t -= delta
		if lightning_t <= 0.0:
			lightning_t = randf_range(3.0, 6.0) if phase == 2 else randf_range(1.6, 3.6)
			_lightning()
	queue_redraw()

func _draw() -> void:
	if not CFG.has(kind):
		return
	var c: Dictionary = CFG[kind]
	var count := int(parts.size() * active_frac)
	for i in count:
		var q: Dictionary = parts[i]
		var col: Color = q["c"]
		var a: float = float(c["alpha"])
		if float(c["twinkle"]) > 0.0:
			a *= 0.35 + 0.65 * (0.5 + 0.5 * sin(t * float(c["twinkle"]) + float(q["ph"])))
		var s: float = q["s"]
		draw_rect(Rect2((q["p"] as Vector2).round(), Vector2(s, s)), Color(col, a))
	for cl in clouds:
		var pts := PackedVector2Array()
		var r: Vector2 = cl["r"]
		for k in 22:
			var ang := TAU * k / 22.0
			pts.append((cl["p"] as Vector2) + Vector2(cos(ang) * r.x, sin(ang) * r.y))
		draw_colored_polygon(pts, Color(0.08, 0.12, 0.16, 0.10 + 0.03 * phase))

func _lightning() -> void:
	if flash_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 2
		add_child(layer)
		flash_rect = ColorRect.new()
		flash_rect.color = Color(1, 1, 1, 0)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(flash_rect)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.4, 0.04)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.05)
	tw.tween_property(flash_rect, "color:a", 0.28, 0.04)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.3)
	Game.add_trauma(0.1)
