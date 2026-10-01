class_name CrystalBlock
extends StaticBody2D
## Reflective crystal obstacle: arrows bounce off it.

var skin := "crystal_block"

func _ready() -> void:
	collision_layer = L.WORLD
	collision_mask = 0
	add_to_group("crystal")
	var s := Gfx.base_sprite("environment/%s.png" % skin)
	add_child(s)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(15, 14)
	cs.shape = r
	cs.position = Vector2(0, -7)
	add_child(cs)
