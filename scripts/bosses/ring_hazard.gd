class_name RingHazard
extends Hazard
## An expanding deadly ring (shockwave). Lethal only on the ring itself; step or roll through it.

const SEGMENTS := 64

var ring_radius := 10.0
var thickness := 6.0
var col := Color(1.0, 0.6, 0.25)
var shapes: Array = []

func _init() -> void:
	super._init()
	shape_node.queue_free()
	for i in SEGMENTS:
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = thickness
		cs.shape = c
		add_child(cs)
		shapes.append(cs)
	add_to_group("projectile")   # cleared automatically when the boss dies

static func spawn(parent: Node, pos: Vector2, color := Color(1.0, 0.6, 0.25)) -> RingHazard:
	var r := RingHazard.new()
	r.col = color
	r.z_index = 3
	parent.add_child(r)
	r.global_position = pos
	r.set_ring(14.0)
	return r

func set_ring(r: float) -> void:
	ring_radius = r
	for i in SEGMENTS:
		shapes[i].position = Vector2.from_angle(TAU * i / SEGMENTS) * r
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 72, Color(col, 0.35), thickness * 2.6, false)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 72, Color(col, 0.95), thickness * 1.2, false)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 72, Color(1, 1, 1, 0.9), 1.5, false)

## Grows the ring until `max_radius`, then frees it.
func expand(max_radius: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_method(set_ring, ring_radius, max_radius, seconds)
	tw.tween_callback(queue_free)
