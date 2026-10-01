class_name WeakPoint
extends Area2D
## A boss weak spot. Does nothing until armed; one valid arrow contact emits `struck`.

signal struck(kind: String)

var armed := false : set = set_armed
var accept_fly := true
var accept_ret := true
var needs_blessed := false     # a ghost: only an arrow that passed through lantern light can hurt it
var glow: AnimatedSprite2D

func _init() -> void:
	collision_layer = L.WEAK
	collision_mask = 0
	monitoring = false
	monitorable = true

static func make(radius: float, pos := Vector2.ZERO, fly := true, ret := true) -> WeakPoint:
	var w := WeakPoint.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	w.add_child(cs)
	w.position = pos
	w.accept_fly = fly
	w.accept_ret = ret
	w.glow = Gfx.strip("bosses/weak_glow.png", 24, 3, 8.0, false)
	w.glow.visible = false
	w.glow.z_index = 3
	w.add_child(w.glow)
	return w

func set_armed(v: bool) -> void:
	armed = v
	if glow:
		glow.visible = v
		if v:
			glow.play("loop")

func try_hit(kind: String, by: Arrow = null) -> bool:
	if not armed:
		return false
	if needs_blessed and (by == null or by.blessed_t <= 0.0):
		return false
	if kind == "fly" and not accept_fly:
		return false
	if kind == "ret" and not accept_ret:
		return false
	struck.emit(kind)
	return true
