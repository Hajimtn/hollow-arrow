class_name Pillar
extends StaticBody2D
## Solid arena pillar. Breakable ones shatter when a charging boss slams into them.

signal shattered(pillar: Pillar)

var breakable := true
var skin := "pillar"       # texture family: pillar, pillar_rune ... (+ _cracked / _broken)
var broken := false
var sprite: Sprite2D
var _shape: CollisionShape2D

func _ready() -> void:
	collision_layer = L.WORLD
	collision_mask = 0
	add_to_group("pillar")
	sprite = Gfx.base_sprite("environment/%s.png" % skin)
	add_child(sprite)
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 12)
	_shape.shape = r
	_shape.position = Vector2(0, -6)
	add_child(_shape)

func crack() -> void:
	sprite.texture = Gfx.tex("environment/%s_cracked.png" % skin)

func shatter(hit_dir := Vector2.ZERO) -> void:
	if broken or not breakable:
		return
	broken = true
	sprite.texture = Gfx.tex("environment/%s_broken.png" % skin)
	_shape.set_deferred("disabled", true)
	remove_from_group("pillar")
	Fx.debris(get_parent(), global_position + Vector2(0, -16), [Color("9a96a4"), Color("5a566a")], 22)
	Fx.dust(get_parent(), global_position, 9)
	RingFx.spawn(get_parent(), global_position, Color(1, 1, 1, 0.6), 4, 40, 0.3, 2.0)
	Sfx.play("crash")
	shattered.emit(self)

func restore() -> void:
	broken = false
	sprite.texture = Gfx.tex("environment/%s.png" % skin)
	_shape.set_deferred("disabled", false)
	add_to_group("pillar")
	Fx.dust(get_parent(), global_position, 8)
