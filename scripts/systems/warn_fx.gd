class_name WarnFx
extends Node2D
## Ground telegraph markers (circle, lane, wedge). They are purely visual: the matching Hazard is separate.

var kind := "circle"
var radius := 24.0
var dur := 1.0
var t := 0.0
var col := Color(1.0, 0.28, 0.22)
var length := 100.0
var width := 20.0
var spread := 1.0
var follow: Node2D = null
var follow_offset := Vector2.ZERO
var freeze_at := -1.0     # stop following after this many seconds

static func _mk(parent: Node, pos: Vector2, seconds: float, color: Color) -> WarnFx:
	var w := WarnFx.new()
	w.dur = seconds
	w.col = color
	w.z_index = -3
	parent.add_child(w)
	w.global_position = pos
	return w

static func circle(parent: Node, pos: Vector2, r: float, seconds: float, color := Color(1.0, 0.28, 0.22)) -> WarnFx:
	var w := _mk(parent, pos, seconds, color)
	w.kind = "circle"
	w.radius = r
	return w

## A lane from `from` towards `to` with the given width.
static func lane(parent: Node, from: Vector2, to: Vector2, wd: float, seconds: float, color := Color(1.0, 0.28, 0.22)) -> WarnFx:
	var w := _mk(parent, from, seconds, color)
	w.kind = "lane"
	w.visible = Game.SHOW_AIM_TELEGRAPHS
	w.width = wd
	w.length = from.distance_to(to)
	w.rotation = (to - from).angle()
	return w

static func wedge(parent: Node, pos: Vector2, ang: float, sprd: float, r: float, seconds: float, color := Color(1.0, 0.28, 0.22)) -> WarnFx:
	var w := _mk(parent, pos, seconds, color)
	w.kind = "wedge"
	w.visible = Game.SHOW_AIM_TELEGRAPHS
	w.rotation = ang
	w.spread = sprd
	w.radius = r
	return w

func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	if follow and is_instance_valid(follow) and (freeze_at < 0.0 or t < freeze_at):
		global_position = follow.global_position + follow_offset
	queue_redraw()

func _draw() -> void:
	var k := clampf(t / dur, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 20.0)
	var line_c := Color(col, 0.55 + 0.35 * pulse)
	match kind:
		"circle":
			draw_circle(Vector2.ZERO, radius * k, Color(col, 0.22))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, line_c, 1.0, false)
		"lane":
			var r := Rect2(0, -width / 2.0, length, width)
			draw_rect(r, Color(col, 0.10 + 0.22 * k))
			draw_rect(r, line_c, false, 1.0)
		"wedge":
			var pts := PackedVector2Array([Vector2.ZERO])
			var n := 14
			for i in n + 1:
				var a := lerpf(-spread, spread, float(i) / n)
				pts.append(Vector2.from_angle(a) * radius)
			draw_colored_polygon(pts, Color(col, 0.10 + 0.22 * k))
			draw_polyline(pts, line_c, 1.0, false)
			draw_line(Vector2.ZERO, pts[1], line_c)
			draw_line(Vector2.ZERO, pts[n + 1], line_c)
