class_name BeamShot
extends Node2D
## A telegraphed line beam that can ricochet off walls. `compute` gives the path for the telegraph,
## `fire` turns it into deadly hazards for `life` seconds.

var hazards: Array = []
var lines: Array = []
var life := 0.5
var age := 0.0

static func compute(node: Node2D, from: Vector2, dir: Vector2, bounces := 1, max_len := 600.0) -> Array:
	var segs := []
	var pos := from
	var d := dir.normalized()
	var space := node.get_world_2d().direct_space_state
	for i in bounces + 1:
		var q := PhysicsRayQueryParameters2D.create(pos, pos + d * max_len, L.WORLD)
		var r := space.intersect_ray(q)
		if r.is_empty():
			segs.append([pos, pos + d * max_len])
			break
		segs.append([pos, r["position"]])
		if i == bounces:
			break
		d = d.bounce(r["normal"]).normalized()
		pos = r["position"] + r["normal"] * 2.0
	return segs

static func fire(parent: Node, segs: Array, width: float, seconds: float, color := Color(0.85, 0.75, 1.0)) -> BeamShot:
	var b := BeamShot.new()
	b.life = seconds
	b.z_index = 4
	b.add_to_group("projectile")
	parent.add_child(b)
	for s in segs:
		var a: Vector2 = s[0]
		var e: Vector2 = s[1]
		var ln := a.distance_to(e)
		if ln < 2.0:
			continue
		var ln2 := Line2D.new()
		ln2.width = width
		ln2.default_color = color
		ln2.points = PackedVector2Array([a, e])
		b.add_child(ln2)
		b.lines.append(ln2)
		var h := Hazard.box(Vector2(ln, width))
		h.global_position = (a + e) / 2.0
		h.rotation = (e - a).angle()
		b.add_child(h)
		h.global_position = (a + e) / 2.0
		b.hazards.append(h)
	return b

func _physics_process(delta: float) -> void:
	age += delta
	for l in lines:
		l.default_color.a = clampf(1.0 - age / life, 0.0, 1.0)
		l.width = maxf(1.0, l.width - delta * 6.0)
	if age >= life:
		queue_free()
