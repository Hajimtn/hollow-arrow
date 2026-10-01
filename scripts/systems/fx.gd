class_name Fx
## Static particle helpers. All particles are 1-3px squares to stay pixel-art consistent.

static func burst(parent: Node, pos: Vector2, colors: Array, count := 12, speed := 60.0, life := 0.5, size := 2.0, gravity := 0.0, dir := Vector2.ZERO, spread := 180.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, count)
	p.lifetime = life
	p.local_coords = false
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = spread if dir != Vector2.ZERO else 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = maxf(1.0, size - 1.0)
	p.scale_amount_max = size
	var g := Gradient.new()
	var c0: Color = colors[0]
	var c1: Color = colors[colors.size() - 1]
	g.colors = PackedColorArray([c0, c1, Color(c1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	p.color_ramp = g
	p.z_index = 4
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p

static func dust(parent: Node, pos: Vector2, n := 5) -> void:
	burst(parent, pos, [Color("d8ccb0"), Color("8a7e70")], n, 26.0, 0.4, 2.0, -10.0, Vector2.UP, 90.0)

static func debris(parent: Node, pos: Vector2, colors := [Color("9a96a4"), Color("5a566a")], n := 14) -> void:
	burst(parent, pos, colors, n, 110.0, 0.7, 3.0, 260.0, Vector2.UP, 160.0)

static func sparks(parent: Node, pos: Vector2, n := 10) -> void:
	burst(parent, pos, [Color("fff0a0"), Color("ff9a30")], n, 120.0, 0.35, 2.0, 0.0)

static func death_burst(parent: Node, pos: Vector2, colors := [Color("ffe9a8"), Color("ff7a30")]) -> void:
	burst(parent, pos, colors, 60, 190.0, 1.1, 3.0, 40.0)
	burst(parent, pos, [Color("ffffff"), Color("ffb040")], 24, 90.0, 0.8, 2.0, -20.0)
	RingFx.spawn(parent, pos, Color("ffe9a8"), 6, 110, 0.6, 3.0)
	RingFx.spawn(parent, pos, Color("ff9a30"), 2, 70, 0.45, 2.0)

## A fading copy of a sprite's current frame: the trail of a dash, a roll or a blink.
static func afterimage(parent: Node, src: Node2D, color := Color(0.7, 0.8, 1.0, 0.5), life := 0.35) -> void:
	var g := Sprite2D.new()
	var tex: Texture2D = null
	if src is AnimatedSprite2D:
		tex = (src as AnimatedSprite2D).sprite_frames.get_frame_texture((src as AnimatedSprite2D).animation, (src as AnimatedSprite2D).frame)
		g.flip_h = (src as AnimatedSprite2D).flip_h
	elif src is Sprite2D:
		tex = (src as Sprite2D).texture
		g.flip_h = (src as Sprite2D).flip_h
		g.offset = (src as Sprite2D).offset
	if tex == null:
		return
	g.texture = tex
	g.scale = src.global_scale
	g.rotation = src.global_rotation
	g.modulate = color
	g.z_index = 1
	parent.add_child(g)
	g.global_position = src.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, life)
	tw.tween_callback(g.queue_free)

## Wind-up cue: sparks streaming INTO a point and a ring collapsing onto it (a cast, a charge, a roar).
static func charge(parent: Node, pos: Vector2, color: Color, seconds := 0.6, radius := 34.0) -> void:
	RingFx.spawn(parent, pos, Color(color, 0.8), radius, 3.0, seconds, 2.0)
	for i in 8:
		var a := TAU * i / 8.0 + randf() * 0.4
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 3
		p.lifetime = seconds
		p.local_coords = false
		p.direction = Vector2.from_angle(a + PI)
		p.spread = 8.0
		p.initial_velocity_min = radius / seconds * 0.9
		p.initial_velocity_max = radius / seconds * 1.1
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		p.color = color
		p.z_index = 5
		parent.add_child(p)
		p.global_position = pos + Vector2.from_angle(a) * radius
		p.emitting = true
		parent.get_tree().create_timer(seconds + 0.2).timeout.connect(p.queue_free)

## a short flash + sparks where an attack leaves the body (muzzle flash, punch impact)
static func flash(parent: Node, pos: Vector2, color := Color(1, 0.9, 0.6), size := 10.0) -> void:
	RingFx.spawn(parent, pos, Color(1, 1, 1, 0.9), 2.0, size, 0.12, 2.0, true)
	burst(parent, pos, [Color.WHITE, color], 8, 90.0, 0.25, 2.0)
