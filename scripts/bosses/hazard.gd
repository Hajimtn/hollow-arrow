class_name Hazard
extends Area2D
## Anything that kills the player on contact. Only counts while `active`.

var active := true : set = set_active
var shape_node: CollisionShape2D

func _init() -> void:
	collision_layer = L.HAZARD
	collision_mask = 0
	monitoring = false
	monitorable = true
	shape_node = CollisionShape2D.new()
	add_child(shape_node)

func set_active(v: bool) -> void:
	active = v
	collision_layer = L.HAZARD if v else 0

static func circle(radius: float, pos := Vector2.ZERO) -> Hazard:
	var h := Hazard.new()
	h.set_radius(radius)
	h.position = pos
	return h

static func box(size: Vector2, pos := Vector2.ZERO) -> Hazard:
	var h := Hazard.new()
	h.set_size(size)
	h.position = pos
	return h

func set_radius(r: float) -> void:
	var c := CircleShape2D.new()
	c.radius = r
	shape_node.shape = c

func set_size(s: Vector2) -> void:
	var r := RectangleShape2D.new()
	r.size = s
	shape_node.shape = r
