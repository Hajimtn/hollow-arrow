class_name TimedHazard
extends Hazard
## A lingering hazard patch (lava). Deadly until it fades.

var life := 3.0
var age := 0.0
var radius := 9.0
var col := Color(1.0, 0.45, 0.1)

static func spawn(parent: Node, pos: Vector2, r: float, seconds: float, color := Color(1.0, 0.45, 0.1)) -> TimedHazard:
	var h := TimedHazard.new()
	h.radius = r
	h.life = seconds
	h.col = color
	h.set_radius(r)
	h.z_index = -2
	h.add_to_group("projectile")
	parent.add_child(h)
	h.global_position = pos
	return h

func _physics_process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	if life - age < _fade():
		active = false     # dying embers are harmless (and drawn dim)
	queue_redraw()

func _fade() -> float:
	return minf(0.45, life * 0.35)

func _draw() -> void:
	var left := life - age
	var a := clampf(left / _fade(), 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(age * 14.0)
	draw_circle(Vector2.ZERO, radius + 2.0, Color(col, 0.30 * a))
	draw_circle(Vector2.ZERO, radius, Color(col, 0.85 * a * pulse))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.9, 0.5, 0.9 * a))
