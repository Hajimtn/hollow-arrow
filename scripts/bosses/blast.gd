class_name Blast
extends Node2D
## A telegraphed ground strike: a warning disc on the floor, an optional sprite that falls from above (icicle, arrow, meteor) or
## rises out of the ground (claw, bone hand, spike) or sits there from the start ("stuck": a trap arrow), then a lethal burst that lingers for `life` seconds.
## It joins the "projectile" group so a dying boss wipes every pending strike.

var radius := 20.0
var delay := 1.0
var life := 0.3
var col := Color(1.0, 0.45, 0.2)
var sprite: Sprite2D
var mode := "none"                 # none | fall | rise
var t := 0.0
var hot := false
var hz: Hazard
var quiet := false

## tex "" = just the warning disc.  mode "fall" drops the sprite onto the spot, "rise" pushes it up out of the ground.
static func spawn(parent: Node, pos: Vector2, r: float, seconds: float, color := Color(1.0, 0.45, 0.2), tex := "", mode_ := "fall", burst_life := 0.3) -> Blast:
	var b := Blast.new()
	b.radius = r
	b.delay = seconds
	b.col = color
	b.life = burst_life
	b.z_index = -2
	b.add_to_group("projectile")
	if tex != "":
		b.mode = mode_
		b.sprite = Gfx.base_sprite(tex)
		b.sprite.z_index = 6
		b.add_child(b.sprite)
	parent.add_child(b)
	b.global_position = pos
	b._place_sprite(0.0)
	return b

func _place_sprite(k: float) -> void:
	if sprite == null:
		return
	match mode:
		"fall":
			sprite.position = Vector2(0, lerpf(-150.0, 0.0, clampf(k * k, 0.0, 1.0)))
		"rise":
			sprite.position = Vector2(0, lerpf(sprite.texture.get_height() * 0.9, 0.0, clampf(k * 3.0 - 2.0, 0.0, 1.0)))
		"stuck":
			sprite.position = Vector2.ZERO
	sprite.modulate.a = 1.0 if (mode == "fall" or mode == "stuck" or k > 0.65) else 0.0

func _physics_process(delta: float) -> void:
	t += delta
	if not hot:
		_place_sprite(t / delay)
		if t >= delay:
			_burst()
	elif t >= delay + life:
		queue_free()
		return
	queue_redraw()

func _burst() -> void:
	hot = true
	hz = Hazard.circle(radius)
	add_child(hz)
	if sprite and (mode == "fall" or mode == "stuck"):
		sprite.visible = false
	elif sprite and mode == "rise":
		sprite.position = Vector2.ZERO
		sprite.modulate.a = 1.0
	if not quiet:
		Fx.burst(get_parent(), global_position, [Color(col, 1.0), Color(col.lightened(0.5), 1.0)], 10, 90.0, 0.35, 2.0, 160.0, Vector2.UP, 150.0)
		RingFx.spawn(get_parent(), global_position, Color(col.lightened(0.4), 0.8), 3, radius * 1.4, 0.25, 2.0)
		Sfx.play("thud", -8.0, 1.3)
		Game.add_trauma(0.12)

func _draw() -> void:
	if not hot:
		var k := clampf(t / delay, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(t * 18.0)
		draw_circle(Vector2.ZERO, radius * k, Color(col, 0.16 + 0.10 * pulse))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(col, 0.55 + 0.35 * pulse), 1.0, false)
	else:
		var a := clampf(1.0 - (t - delay) / life, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(col, 0.5 * a))
		draw_circle(Vector2.ZERO, radius * 0.6, Color(1, 1, 1, 0.55 * a))
