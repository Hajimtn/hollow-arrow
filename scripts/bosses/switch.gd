class_name RuneSwitch
extends Area2D
## Arrow-triggered mechanism (a rune plate or pylon rune).

signal struck(sw: RuneSwitch)

var on := false
var sprite: Sprite2D
var tex_off := "environment/switch_off.png"
var tex_on := "environment/switch_on.png"
var one_shot := true
var enabled := true
var accept_fly := true
var accept_ret := true

func _init() -> void:
	collision_layer = L.SWITCH
	collision_mask = 0
	monitoring = false
	monitorable = true

static func make(radius := 8.0, off_tex := "environment/switch_off.png", on_tex := "environment/switch_on.png") -> RuneSwitch:
	var s := RuneSwitch.new()
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	s.add_child(cs)
	s.tex_off = off_tex
	s.tex_on = on_tex
	s.sprite = Gfx.base_sprite(off_tex)
	s.sprite.position = Vector2(0, radius)
	s.add_child(s.sprite)
	return s

func accepts(kind: String) -> bool:
	return accept_fly if kind == "fly" else accept_ret

func strike() -> bool:
	if not enabled or (on and one_shot):
		return false
	set_on(true)
	struck.emit(self)
	return true

func set_on(v: bool) -> void:
	on = v
	sprite.texture = Gfx.tex(tex_on if v else tex_off)
