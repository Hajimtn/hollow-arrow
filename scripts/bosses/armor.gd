class_name Armor
extends Area2D
## Boss armour / reflective surfaces. Decides how the arrow reacts on contact.

enum Mode { DROP, BOUNCE, STICK, PASS }

signal clanked(pos: Vector2, kind: String)

var enabled := true
var fly_mode := Mode.DROP
var ret_mode := Mode.DROP
var normal_fn := Callable()   # func(arrow_pos: Vector2) -> Vector2

func _init() -> void:
	collision_layer = L.ARMOR
	collision_mask = 0
	monitoring = false
	monitorable = true

static func make_circle(radius: float, pos := Vector2.ZERO, fly := Mode.DROP, ret := Mode.DROP) -> Armor:
	var a := Armor.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	a.add_child(cs)
	a.position = pos
	a.fly_mode = fly
	a.ret_mode = ret
	return a

static func make_box(size: Vector2, pos := Vector2.ZERO, fly := Mode.DROP, ret := Mode.DROP) -> Armor:
	var a := Armor.new()
	var cs := CollisionShape2D.new()
	var c := RectangleShape2D.new()
	c.size = size
	cs.shape = c
	a.add_child(cs)
	a.position = pos
	a.fly_mode = fly
	a.ret_mode = ret
	return a

func mode_for(kind: String) -> int:
	if not enabled:
		return Mode.PASS
	return fly_mode if kind == "fly" else ret_mode

func normal_at(p: Vector2) -> Vector2:
	if normal_fn.is_valid():
		return normal_fn.call(p)
	return (p - global_position).normalized()
