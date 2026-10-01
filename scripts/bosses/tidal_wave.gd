class_name TidalWave
extends Node2D
## A wall of water that sweeps the whole arena from one side to the other. One gap is left open: find it and stand in it.

var dir := 1.0
var speed := 190.0
var gap_y := 100.0
var gap_h := 58.0
var arena_w := 640.0
var arena_h := 352.0
var top: Hazard
var bottom: Hazard
var t := 0.0

static func spawn(zone: Zone, from_left: bool, gap_center: float, seconds := 3.4) -> TidalWave:
	var w := TidalWave.new()
	w.arena_w = zone.w * 16.0
	w.arena_h = zone.h * 16.0
	w.dir = 1.0 if from_left else -1.0
	w.speed = (w.arena_w + 60.0) / seconds
	w.gap_y = gap_center
	w.position = Vector2(-24.0 if from_left else w.arena_w + 24.0, 0.0)
	w.z_index = 4
	w.add_to_group("projectile")
	zone.entities.add_child(w)
	w._build()
	Sfx.play("rumble", 0.0, 0.7)
	Game.add_trauma(0.3)
	return w

func _build() -> void:
	var y0 := 36.0
	var y1 := arena_h - 24.0
	var gt := gap_y - gap_h / 2.0
	var gb := gap_y + gap_h / 2.0
	top = Hazard.box(Vector2(20, maxf(4.0, gt - y0)), Vector2(0, (y0 + gt) / 2.0))
	bottom = Hazard.box(Vector2(20, maxf(4.0, y1 - gb)), Vector2(0, (gb + y1) / 2.0))
	add_child(top)
	add_child(bottom)

func _physics_process(delta: float) -> void:
	t += delta
	position.x += dir * speed * delta
	if (dir > 0.0 and position.x > arena_w + 40.0) or (dir < 0.0 and position.x < -40.0):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var y0 := 36.0
	var y1 := arena_h - 24.0
	var gt := gap_y - gap_h / 2.0
	var gb := gap_y + gap_h / 2.0
	for seg in [[y0, gt], [gb, y1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		draw_rect(Rect2(-10, a, 20, b - a), Color(0.2, 0.55, 0.95, 0.75))
		draw_rect(Rect2(-4, a, 8, b - a), Color(0.55, 0.85, 1.0, 0.9))
		var fx := dir * 8.0
		for y in range(int(a), int(b), 9):
			var off := sin(t * 14.0 + y * 0.4) * 2.5
			draw_rect(Rect2(fx + off - 1.5, y, 4, 5), Color(0.92, 0.98, 1.0, 0.95))
		draw_rect(Rect2(-dir * 14.0 - 6, a, 12, b - a), Color(0.3, 0.65, 1.0, 0.25))
