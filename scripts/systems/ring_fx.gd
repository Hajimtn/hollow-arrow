class_name RingFx
extends Node2D
## Expanding pixel ring / filled flash used for shockwaves and telegraphs.

var r0 := 4.0
var r1 := 30.0
var dur := 0.3
var col := Color.WHITE
var width := 2.0
var fill := false
var t := 0.0

static func spawn(parent: Node, pos: Vector2, color: Color, radius_from: float, radius_to: float, seconds: float, line_width := 2.0, filled := false) -> RingFx:
	var r := RingFx.new()
	r.global_position = pos
	r.col = color
	r.r0 = radius_from
	r.r1 = radius_to
	r.dur = seconds
	r.width = line_width
	r.fill = filled
	r.z_index = 5
	parent.add_child(r)
	r.global_position = pos
	return r

func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k: float = clampf(t / dur, 0.0, 1.0)
	var r: float = lerpf(r0, r1, 1.0 - pow(1.0 - k, 2.0))
	var c := col
	c.a = col.a * (1.0 - k)
	if fill:
		draw_circle(Vector2.ZERO, r, c)
	else:
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, c, width, false)
