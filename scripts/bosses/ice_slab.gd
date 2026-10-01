class_name IceSlab
extends StaticBody2D
## A pillar of ice the Frost Guardian raises. Solid for the player, ricochets arrows (it is in the "crystal" group), and melts away.

var life := 7.0
var age := 0.0
var sprite: Sprite2D

static func spawn(zone: Zone, pos: Vector2, seconds := 7.0) -> IceSlab:
	var s := IceSlab.new()
	s.life = seconds
	s.position = pos
	s.add_to_group("crystal")
	s.add_to_group("projectile")          # wiped when the boss dies
	zone.entities.add_child(s)
	return s

func _ready() -> void:
	collision_layer = L.WORLD
	collision_mask = 0
	sprite = Gfx.base_sprite("bosses/ice_slab.png")
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(15, 12)
	cs.shape = r
	cs.position = Vector2(0, -6)
	add_child(cs)
	sprite.scale = Vector2(1, 0.1)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position, [Color("e8f8ff"), Color("8fd0ff")], 10, 70.0, 0.4, 2.0, 120.0, Vector2.UP, 120.0)
	Sfx.play("shatter", -6.0, 1.2)

func _physics_process(delta: float) -> void:
	age += delta
	if age > life - 1.0:
		sprite.modulate.a = 0.5 + 0.5 * sin(age * 22.0)
	if age >= life:
		Fx.burst(get_parent(), global_position + Vector2(0, -20), [Color("ffffff"), Color("8fd0ff")], 12, 80.0, 0.5, 2.0, 200.0)
		queue_free()
