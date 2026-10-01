extends BossBase
## THE ASHEN REGENT - the final boss. Behind the crown was never a king: it is the vessel of the four elements the six guardians
## kept bound (stone, ice, fire, storm). Art: "Golems and elementals" by batareya - static 64x96 sprites drawn at 1.5x; there are no
## animation frames, so every movement is procedural (breathing, hovering, squash and stretch, flashes, particles, spectral fists).
##
## Its core is sealed. The four elemental SHRINES in the corners of the Nexus are arrow switches, and a form is weak to the element
## opposed to it: strike the right shrine and steam splits the shell for a few seconds.
##   Phase 1  STONE-FIRE TITAN   (sprite 15)  weak to WATER. Boulder toss, quake line, magma fist.
##   Phase 2  TIDE ELEMENTAL     (sprite 13)  weak to FIRE.  Tidal wave, frost orbs, geyser ring.
##   Phase 3  VOID-FLAME         (sprite 29)  needs BOTH shrines (fire + water) within 6 s; then only a RECALLED arrow.
##                                            Storm grid, void well, star fall, shadow clones.
## A wrong shrine backfires. No attack is reused in another phase.

const FORM_TEX := {1: "bosses/final_1.png", 2: "bosses/final_2.png", 3: "bosses/final_3.png"}
# the core, measured on the scaled sprites (px from the sprite's bottom centre)
const CORE := {1: Vector2(4, -87), 2: Vector2(-6, -86), 3: Vector2(2, -82)}
const RIM := {1: Color("ef8d35"), 2: Color("6ac8ff"), 3: Color("c86aff")}
const CORE_COL := {1: Color("ffd070"), 2: Color("c8f0ff"), 3: Color("e8b0ff")}
const PHASES := {
	1: {"gap": 0.9, "window": 3.4, "speed": 34.0},
	2: {"gap": 0.7, "window": 3.4, "speed": 40.0},
	3: {"gap": 0.5, "window": 3.8, "speed": 46.0},
}
const ATTACKS := {
	1: ["boulder_toss", "quake_line", "magma_fist"],
	2: ["tidal_wave", "frost_orbs", "geyser_ring"],
	3: ["storm_grid", "void_well", "star_fall", "shadow_clones"],
}
const SHRINE_MARK := {"fire": "j", "water": "u", "earth": "y", "storm": "z"}
const SHRINE_COL := {"fire": Color("ef6a2a"), "water": Color("4aa8ff"), "earth": Color("c09a4a"), "storm": Color("9b8cff")}
const REQUIRED := {1: ["water"], 2: ["fire"], 3: ["fire", "water"]}
const PHASE_TIPS := {
	1: "THE STONE-FIRE TITAN'S CORE IS SEALED. STRIKE THE WATER SHRINE (BLUE) WITH AN ARROW - THEN SHOOT THE CORE.",
	2: "THE TIDE ELEMENTAL FEARS FIRE. STRIKE THE FIRE SHRINE - THEN SHOOT THE CORE BEFORE IT CLOSES.",
	3: "THE VOID-FLAME NEEDS FIRE AND WATER TOGETHER. STRIKE BOTH SHRINES, THEN RECALL THE ARROW THROUGH THE CORE.",
}
const ORB := "bosses/orb_red.png"
const LAVA := Color("ef6a2a")

var phase := 1
var mover: CharacterBody2D
var body: Sprite2D
var shadow: Sprite2D
var core_node: Node2D
var particles: CPUParticles2D
var hazard: Hazard
var armor: Armor
var weak: WeakPoint
var weak_shape: CircleShape2D
var seals: Array = []
var shrines := {}
var shrine_hit := {}              # element -> ms timestamp of its last valid strike
var pose_scale := Vector2.ONE
var window_len := 3.4
var phase_pending := 0
var pull := false
var floor_rect := Rect2()
var center := Vector2.ZERO
var bob := 0.0
var orbs: Array = []
var orb_ang := 0.0
var hint_t := 0.0
var fists: Array = []             # the two floating fists: {node, spr}; drawn for this game (tools/gen_drawn.py)
var arms: Array = []              # Line2D tethers from the shoulders to the fists
var fist_mode := "idle"
const FIST_HOME := Vector2(48, -88)

func attack_list() -> Array:
	return ATTACKS[phase]

func all_attacks() -> Dictionary:
	return ATTACKS

func P(key: String) -> float:
	return PHASES[phase][key]

func _build() -> void:
	mover = CharacterBody2D.new()
	mover.collision_layer = L.BODY
	mover.collision_mask = L.WORLD
	mover.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 20.0
	cs.shape = c
	mover.add_child(cs)
	add_child(mover)
	shadow = Sprite2D.new()
	var img := Image.create(80, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 80:
			if pow((x - 39.5) / 39.0, 2.0) + pow((y - 11.5) / 11.5, 2.0) <= 1.0:
				img.set_pixel(x, y, Color(0.03, 0.0, 0.08, 0.45))
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.z_index = -3
	add_child(shadow)
	body = Gfx.base_sprite(FORM_TEX[1])
	body.material = ShaderMaterial.new()
	body.material.shader = load("res://shaders/rim.gdshader")
	body.material.set_shader_parameter("rim_size", 0.7)
	add_child(body)
	sprites.append(body)
	core_node = Node2D.new()
	core_node.z_index = 3
	core_node.draw.connect(_draw_core)
	add_child(core_node)
	particles = CPUParticles2D.new()
	particles.amount = 26
	particles.lifetime = 1.4
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(24, 50)
	particles.direction = Vector2.UP
	particles.spread = 40.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.z_index = 2
	particles.position = Vector2(0, -60)
	add_child(particles)
	hazard = add_hazard_circle(24.0, Vector2(0, -56))
	armor = add_armor_circle(34.0, Vector2(0, -58))
	weak = add_weak(11.0, CORE[1])
	weak_shape = weak.get_child(0).shape
	weak.glow.scale = Vector2(0.9, 0.9)
	for i in 2:
		var s := Gfx.sprite("environment/rune_on.png", Vector2(-7 + i * 14, -164))
		add_child(s)
		seals.append(s)
	for i in 4:
		var o := Hazard.circle(7.0)
		var sp := Gfx.sprite("bosses/orb_moon.png")
		sp.scale = Vector2(1.8, 1.8)
		o.add_child(sp)
		add_child(o)
		o.active = false
		o.visible = false
		orbs.append(o)
	for i in 2:
		var ln := Line2D.new()
		ln.width = 6.0
		ln.default_color = Color(RIM[1], 0.55)
		ln.z_index = 3
		ln.add_point(Vector2.ZERO)
		ln.add_point(Vector2.ZERO)
		add_child(ln)
		arms.append(ln)
		var n := Node2D.new()
		n.position = Vector2(FIST_HOME.x * (-1.0 if i == 0 else 1.0), FIST_HOME.y)
		n.z_index = 4
		var sp := Sprite2D.new()
		sp.texture = Gfx.tex("bosses/final_fist_1.png")
		n.add_child(sp)
		add_child(n)
		fists.append({"node": n, "spr": sp})
	floor_rect = Rect2(zone.cell_center(2, 3), Vector2((zone.w - 5) * 16, (zone.h - 6) * 16))
	center = zone.mark("a")
	_build_shrines()
	_set_weak(CORE[1], 11.0, true, true, false)

func _build_shrines() -> void:
	for el in SHRINE_MARK:
		var pos := zone.mark(SHRINE_MARK[el])
		if pos == Vector2.ZERO:
			continue
		var holder := Node2D.new()
		holder.position = pos + Vector2(0, 8)
		zone.entities.add_child(holder)
		var sw := RuneSwitch.make(10.0, "environment/shrine_%s_off.png" % el, "environment/shrine_%s_on.png" % el)
		sw.one_shot = false
		sw.sprite.position = Vector2(0, 26)
		sw.position = Vector2(0, -26)
		holder.add_child(sw)
		var hint := Node2D.new()
		hint.position = Vector2(0, -26)
		hint.z_index = 5
		hint.visible = false
		var col: Color = SHRINE_COL[el]
		hint.draw.connect(func():
			var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			hint.draw_arc(Vector2.ZERO, 22.0 + 3.0 * k, 0.0, TAU, 32, Color(col, 0.35 + 0.5 * k), 2.0))
		holder.add_child(hint)
		sw.struck.connect(_on_shrine.bind(el))
		shrines[el] = {"sw": sw, "holder": holder, "hint": hint, "pos": holder.global_position + Vector2(0, -20)}

func _on_start() -> void:
	position = zone.mark("B") + Vector2(0, 14)
	_apply_phase(1)
	set_state("idle")

# ------------------------------------------------------------------ procedural look
func _draw_core() -> void:
	var c: Color = CORE_COL[phase]
	var open := weak.armed
	var pulse := 0.5 + 0.5 * sin(bob * (7.0 if open else 3.0))
	var p: Vector2 = weak.position
	var r := (9.0 if open else 6.0) + 2.0 * pulse
	core_node.draw_circle(p, r + 3.0, Color(c, 0.25 + (0.25 if open else 0.0)))
	core_node.draw_circle(p, r, Color(c, 0.75))
	core_node.draw_circle(p, r * 0.5, Color(1, 1, 1, 0.9))
	if not open:
		core_node.draw_arc(p, r + 5.0, 0.0, TAU, 20, Color(0.5, 0.5, 0.6, 0.6), 2.0)      # the shell around it

## squash and stretch on the static sprite. Rising (sy > 1.04) gathers energy at the core; a fast drop (sy < 0.95) hits the ground.
func _pose(sx: float, sy: float, dur := 0.25) -> void:
	create_tween().tween_property(self, "pose_scale", Vector2(sx, sy), dur).set_trans(Tween.TRANS_SINE)
	if not is_inside_tree() or dead:
		return
	if sy > 1.04 and dur >= 0.3:
		Fx.charge(zone.entities, _core_world(), CORE_COL[phase], minf(dur, 0.8), 48.0)
	elif sy < 0.95 and dur <= 0.2:
		_ground_hit()

func _ground_hit() -> void:
	Fx.flash(zone.entities, global_position + Vector2(0, -4), RIM[phase], 26.0)
	RingFx.spawn(zone.entities, global_position + Vector2(0, 4), Color(RIM[phase], 0.7), 6.0, 60.0, 0.3, 2.0)
	var cr := Gfx.sprite("bosses/crack.png", global_position + Vector2(0, 6))
	cr.z_index = -4
	zone.floor_decor.add_child(cr)
	cr.global_position = global_position + Vector2(0, 6)
	create_tween().tween_property(cr, "modulate:a", 0.0, 4.0)
	Fx.dust(zone.entities, global_position, 8)

func _animate(delta: float) -> void:
	bob += delta
	var hover := 0.0 if phase == 1 else (7.0 if phase == 2 else 11.0)
	var b := sin(bob * (1.6 if phase == 1 else 2.2)) * (2.0 if phase == 1 else 5.0)
	body.position.y = -hover + b
	var br := 0.018 * sin(bob * 2.1)
	body.scale = pose_scale * Vector2(1.0 + br, 1.0 - br)
	body.rotation = sin(bob * 0.8) * 0.015
	shadow.scale = Vector2.ONE * (1.35 - 0.2 * clampf(hover / 11.0, 0.0, 1.0))
	shadow.modulate.a = 0.9 - 0.25 * clampf(hover / 11.0, 0.0, 1.0)
	core_node.position = Vector2(0, body.position.y)
	core_node.queue_redraw()
	_update_arms()

## The two floating fists are the titan's hands: they hover at the shoulders and act out every attack.
## mode: idle | raise | clap | slam | wide | cast | limp | throw (right fist flung along `aim`)
func _fists(mode: String, dur := 0.25, aim := Vector2.RIGHT) -> void:
	fist_mode = mode
	var l := Vector2(-FIST_HOME.x, FIST_HOME.y)
	var r := FIST_HOME
	var open_hand := false
	var rot := 0.0
	match mode:
		"raise":
			l = Vector2(-26, -170); r = Vector2(26, -170); open_hand = true
		"clap":
			l = Vector2(-8, -76); r = Vector2(8, -76)
		"slam":
			l = Vector2(-30, -6); r = Vector2(30, -6); rot = PI
		"wide":
			l = Vector2(-96, -86); r = Vector2(96, -86); open_hand = true
		"cast":
			l = Vector2(-22, -72); r = Vector2(22, -72); open_hand = true
		"limp":
			l = Vector2(-46, -36); r = Vector2(46, -36); open_hand = true; rot = 0.4
		"throw":
			r = aim.normalized() * 66.0 + Vector2(0, -84)
			rot = aim.angle() + PI / 2.0
	for i in 2:
		var f: Dictionary = fists[i]
		f["spr"].texture = Gfx.tex("bosses/final_%s_%d.png" % ["palm" if open_hand else "fist", phase])
		var target: Vector2 = l if i == 0 else r
		var rr := rot * (-1.0 if i == 0 else 1.0) if mode in ["limp"] else rot
		if mode == "throw" and i == 0:
			rr = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(f["node"], "position", target, dur).set_trans(Tween.TRANS_BACK if mode in ["slam", "throw"] else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(f["node"], "rotation", rr, dur)
	if mode == "slam":
		get_tree().create_timer(dur).timeout.connect(func():
			if is_instance_valid(self) and not dead and is_inside_tree():
				_ground_hit())

func _update_arms() -> void:
	for i in 2:
		var f: Dictionary = fists[i]
		var sgn := -1.0 if i == 0 else 1.0
		f["spr"].position = Vector2(0, sin(bob * 2.2 + i * 1.7) * 3.0 if fist_mode == "idle" else 0.0)
		var shoulder := Vector2(sgn * 30.0, -104.0 + body.position.y)
		arms[i].set_point_position(0, shoulder)
		arms[i].set_point_position(1, (f["node"].position as Vector2) + Vector2(0, 8).rotated(f["node"].rotation))
		arms[i].default_color = Color(RIM[phase], 0.5)
		arms[i].width = 5.0 + 1.5 * sin(bob * 3.0 + i)

func _flash_body(dur := 0.15) -> void:
	body.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(body, "modulate", Color.WHITE, dur)

func _apply_phase(p: int) -> void:
	phase = p
	zone.on_phase(p)
	reset_attacks()
	body.texture = Gfx.tex(FORM_TEX[p])
	(body.material as ShaderMaterial).set_shader_parameter("rim_color", RIM[p])
	weak.position = CORE[p]
	weak.glow.modulate = CORE_COL[p]
	_set_weak(CORE[p], 11.0 if p < 3 else 12.0, p < 3, true, false)
	armor.enabled = true
	hazard.active = true
	pose_scale = Vector2.ONE
	pull = false
	_fists("idle", 0.2)
	particles.color = RIM[p]
	particles.gravity = Vector2(0, -20.0 if p != 2 else 15.0)
	particles.emitting = true
	for i in 2:
		seals[i].texture = Gfx.tex("environment/rune_on.png" if i >= p - 1 else "environment/rune_off.png")
	for el in shrines:
		shrines[el]["hint"].visible = REQUIRED[p].has(el)
		shrines[el]["sw"].set_on(false)
	shrine_hit.clear()
	Game.say(PHASE_TIPS[p], 8.0)

func _set_weak(pos: Vector2, r: float, fly: bool, ret: bool, armed: bool) -> void:
	weak.position = pos
	weak_shape.radius = r
	weak.accept_fly = fly
	weak.accept_ret = ret
	weak.armed = armed

func _sync_mover() -> void:
	position += mover.position
	mover.position = Vector2.ZERO

func _dormant(delta: float) -> void:
	_animate(delta)

func _core_world() -> Vector2:
	return global_position + weak.position + Vector2(0, body.position.y)

func _lead(extra := 0.4) -> Vector2:
	return Atk.clamp_in(zone, player.global_position + player.velocity * extra)

# ------------------------------------------------------------------ shrines: the elemental counter puzzle
func _on_shrine(_sw: RuneSwitch, el: String) -> void:
	if dead or state == "evolve":
		return
	var sh: Dictionary = shrines[el]
	sh["sw"].set_on(true)
	var col: Color = SHRINE_COL[el]
	Fx.burst(zone.entities, sh["pos"], [col, col.lightened(0.5)], 14, 90.0, 0.6, 2.0)
	Sfx.play("stun", -4.0, 1.3)
	_beam_fx(sh["pos"], col)
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(sh["sw"]):
			sh["sw"].set_on(false))
	if not REQUIRED[phase].has(el):
		_backfire(el, sh["pos"])
		return
	shrine_hit[el] = Time.get_ticks_msec()
	var ready := true
	for r in REQUIRED[phase]:
		if not shrine_hit.has(r) or Time.get_ticks_msec() - int(shrine_hit[r]) > 6000:
			ready = false
	if ready:
		_open_core()
	else:
		Game.say("ONE SHRINE LIT - STRIKE THE OTHER WITHIN 6 SECONDS!", 2.5)

func _beam_fx(from: Vector2, col: Color) -> void:
	var ln := Line2D.new()
	ln.width = 4.0
	ln.default_color = col
	ln.z_index = 6
	ln.points = PackedVector2Array([from, _core_world()])
	zone.entities.add_child(ln)
	var tw := create_tween()
	tw.tween_property(ln, "modulate:a", 0.0, 0.7)
	tw.tween_callback(ln.queue_free)

## a shrine of the wrong element feeds the titan: it answers with a nova
func _backfire(el: String, pos: Vector2) -> void:
	Game.say("WRONG ELEMENT - THE %s SHRINE FEEDS IT!" % el.to_upper(), 2.5)
	Game.add_trauma(0.5)
	Atk.ring(zone, _core_world(), 14, 100.0, ORB, randf(), 4.0, 5.0)
	Atk.ring(zone, pos + Vector2(0, -20), 8, 90.0, ORB, randf(), 4.0, 5.0)
	_flash_body(0.2)

func _open_core() -> void:
	window_len = P("window")
	set_state("window")

# ------------------------------------------------------------------ state entry
func _enter(s: String) -> void:
	if s != "attack":
		pull = false
		pose_scale = Vector2.ONE
		for o in orbs:
			o.active = false
			o.visible = false
		if s != "window" and s != "evolve":
			_fists("idle", 0.25)
	match s:
		"idle":
			hazard.active = true
			armor.enabled = true
			weak.armed = false
		"window":
			hazard.active = false
			armor.enabled = false
			_set_weak(CORE[phase], 12.0 if phase == 3 else 11.0, phase < 3, true, true)
			Sfx.play("shatter", 0.0, 0.8)
			Sfx.play("stun", 0.0, 0.7)
			Game.hitstop(0.08)
			Game.add_trauma(0.7)
			Fx.burst(zone.entities, _core_world(), [Color("ffffff"), CORE_COL[phase]], 26, 110.0, 0.7, 2.0)
			_pose(1.06, 0.94, 0.15)
			_fists("limp", 0.3)                       # stunned: the hands drop
			Game.say("THE CORE IS OPEN!" if phase < 3 else "THE CORE IS OPEN - RECALL AN ARROW THROUGH IT!", 2.0)
		"evolve":
			hazard.active = false
			weak.armed = false
			armor.enabled = true
			Sfx.play("shatter")
			Sfx.play("roar", 2.0, 0.6)
			Game.hitstop(0.14)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)
			Fx.death_burst(zone.entities, _core_world(), [Color("ffe9a8"), RIM[phase]])
			Game.show_banner("SEAL %d BROKEN" % phase, "")

# ------------------------------------------------------------------ per-frame
func _tick(delta: float) -> void:
	_animate(delta)
	hint_t += delta
	for el in shrines:
		if shrines[el]["hint"].visible:
			shrines[el]["hint"].queue_redraw()
	if pull:
		if int(t * 10.0) % 3 == 0:
			Fx.afterimage(zone.entities, body, Color(CORE_COL[phase], 0.25), 0.4)
		var to_me := (global_position + Vector2(0, -50) - player.global_position).normalized()
		player.move_and_collide(to_me * 62.0 * delta)
		zone.arrow.wind = (global_position - zone.arrow.global_position).normalized() * 300.0
	if orbs[0].visible:
		orb_ang += delta * 3.2
		for i in 4:
			orbs[i].position = Vector2.from_angle(orb_ang + TAU * i / 4.0) * 58.0 + Vector2(0, -56)
	match state:
		"idle":
			var d := (center + Vector2(sin(t * 0.5 + bob) * 80.0, -30.0)) - global_position
			mover.velocity = d.normalized() * minf(P("speed"), d.length() * 2.0)
			mover.move_and_slide()
			_sync_mover()
			if t > P("gap"):
				start_attack(pick_attack())
		"window":
			if t >= window_len:
				set_state("idle")
		"evolve":
			body.position.x = randf_range(-2.0, 2.0)
			if t >= 1.1 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
				_flash_body(0.5)
				Sfx.play("crash")
				Game.add_trauma(1.0)
				RingFx.spawn(zone.entities, global_position + Vector2(0, -50), Color("ffb040"), 8, 140, 0.6, 4.0)
				hazard.active = false
				Game.show_banner("THE REGENT " + ("RISES AS THE TIDE" if np == 2 else "OPENS THE VOID"), "PHASE %d" % np)
			if t >= 2.6:
				body.position.x = 0.0
				set_state("idle")

func _on_weak_struck(_kind: String) -> void:
	if dead or state == "evolve":
		return
	if phase >= 3:
		kill()
		return
	phase_pending = phase + 1
	set_state("evolve")

func _on_armor_clank(_pos: Vector2, _kind: String) -> void:
	_flash_body(0.08)

# ------------------------------------------------------------------ PHASE 1 - STONE-FIRE TITAN
func _atk_boulder_toss(g: int) -> void:
	_pose(0.94, 1.08, 0.5)
	_fists("raise", 0.5)
	Sfx.play("telegraph", -2.0, 0.8)
	if not await atk_wait(0.6, g): return
	for k in 3:
		_pose(1.08, 0.92, 0.08)
		_fists("throw", 0.12, _lead(0.3) - _core_world())
		Sfx.play("charge", -2.0, 0.9)
		var from := _core_world()
		Atk.fan(zone, from, (_lead(0.3) - from).angle(), 3 + (k % 2), 0.55, 175.0, "bosses/rock.png", 7.0, 5.0)
		Game.add_trauma(0.3)
		if not await atk_wait(0.2, g): return
		_pose(1.0, 1.0, 0.2)
		_fists("raise", 0.25)
		if not await atk_wait(0.4, g): return
	await atk_wait(0.3, g)

func _atk_quake_line(g: int) -> void:
	_pose(1.1, 0.88, 0.5)
	_fists("raise", 0.65)
	Sfx.play("roar", -2.0, 0.7)
	if not await atk_wait(0.7, g): return
	_pose(0.94, 1.08, 0.1)
	_fists("slam", 0.12)
	Game.add_trauma(0.7)
	Game.hitstop(0.05)
	var d := (player.global_position - global_position).normalized()
	Atk.line_blasts(zone, global_position, d, 15, 22.0, 16.0, 0.4, 0.05, Color("c09a4a"), "bosses/stone_spike.png", "rise")
	if not await atk_wait(0.6, g): return
	for off in [-0.4, 0.4]:
		Atk.line_blasts(zone, global_position, d.rotated(off), 14, 22.0, 16.0, 0.35, 0.05, Color("c09a4a"), "bosses/stone_spike.png", "rise")
	_pose(1.0, 1.0, 0.3)
	if not await atk_wait(1.6, g): return

func _atk_magma_fist(g: int) -> void:
	for k in 2:
		_pose(0.94, 1.1, 0.4)
		_fists("raise", 0.45)
		Sfx.play("telegraph", -2.0, 0.7)
		if not await atk_wait(0.5, g): return
		_fists("slam", 0.15)
		var target := _lead(0.9 if k == 1 else 0.5)
		Atk.blast(zone, target, 34.0, 1.1, LAVA, "bosses/golem_fist.png", "fall", 0.4)
		get_tree().create_timer(1.15).timeout.connect(func():
			if is_instance_valid(self) and not dead and is_inside_tree():
				TimedHazard.spawn(zone.entities, target, 26.0, 4.0, LAVA)
				Fx.debris(zone.entities, target, [Color("ef6a2a"), Color("5a3a2a")], 14))
		_pose(1.0, 1.0, 0.4)
		if not await atk_wait(0.7, g): return
	await atk_wait(1.2, g)

# ------------------------------------------------------------------ PHASE 2 - TIDE ELEMENTAL
func _atk_tidal_wave(g: int) -> void:
	_pose(1.06, 0.94, 0.5)
	_fists("wide", 0.6)
	Sfx.play("roar", -2.0, 0.6)
	if not await atk_wait(0.7, g): return
	var h := zone.h * 16.0
	for k in 2:
		var gap := clampf(player.global_position.y + randf_range(-50.0, 50.0), 90.0, h - 60.0)
		TidalWave.spawn(zone, (k == 0) == (randf() < 0.5), gap, 3.4)
		if not await atk_wait(1.5, g): return
	_pose(1.0, 1.0, 0.3)
	await atk_wait(2.4, g)

func _atk_frost_orbs(g: int) -> void:
	_pose(1.05, 0.95, 0.5)
	_fists("cast", 0.5)
	Sfx.play("telegraph", -2.0, 1.1)
	if not await atk_wait(0.5, g): return
	orb_ang = 0.0
	for o in orbs:
		o.visible = true
		o.active = true
	if not await atk_wait(1.5, g): return
	for i in 4:
		var o: Hazard = orbs[i]
		var from := o.global_position
		Atk.shot(zone, from, _lead(0.25) - from, 165.0, "bosses/orb_moon.png", 6.0, 5.0)
		o.active = false
		o.visible = false
		Sfx.play("orb", -2.0, 1.2)
		if not await atk_wait(0.28, g): return
	_pose(1.0, 1.0, 0.3)
	await atk_wait(1.0, g)

func _atk_geyser_ring(g: int) -> void:
	_pose(0.94, 1.08, 0.4)
	_fists("raise", 0.45)
	Sfx.play("roar", -2.0, 0.8)
	if not await atk_wait(0.6, g): return
	_pose(1.0, 1.0, 0.3)
	_fists("slam", 0.1)
	Game.add_trauma(0.5)
	var c := player.global_position
	for ring_i in 2:
		var rad := 62.0 + ring_i * 44.0
		var n := 8 + ring_i * 4
		var skip := randi() % n
		for i in n:
			if i == skip or i == (skip + 1) % n:
				continue                              # a doorway through each ring
			var p := Atk.clamp_in(zone, c + Vector2.from_angle(TAU * i / n + ring_i * 0.3) * rad)
			Atk.blast(zone, p, 15.0, 1.0 + 0.55 * ring_i, Color("6ac8ff"), "bosses/ice_spike.png", "rise", 0.5)
	if not await atk_wait(2.6, g): return

# ------------------------------------------------------------------ PHASE 3 - VOID-FLAME
func _atk_storm_grid(g: int) -> void:
	_pose(1.06, 0.94, 0.4)
	_fists("raise", 0.45)
	Sfx.play("roar", 0.0, 0.7)
	if not await atk_wait(0.6, g): return
	_fists("slam", 0.1)
	var safe := _lead(0.4)
	var n := 0
	for gy in range(-4, 5):
		for gx in range(-4, 5):
			var p := Vector2(safe.x + gx * 40.0, safe.y + gy * 40.0)
			if p.distance_to(safe) < 46.0:
				continue                              # the safe pocket
			if p.x < 30.0 or p.x > zone.w * 16.0 - 30.0 or p.y < 44.0 or p.y > zone.h * 16.0 - 30.0:
				continue
			Atk.blast(zone, p, 19.0, 1.1 + 0.03 * (abs(gx) + abs(gy)) + 0.0 * n, Color("fff0a0"), "bosses/bolt.png", "rise", 0.3)
			n += 1
	_pose(1.0, 1.0, 0.3)
	if not await atk_wait(2.3, g): return

func _atk_void_well(g: int) -> void:
	_pose(0.94, 1.08, 0.5)
	_fists("cast", 0.5)
	Sfx.play("roar", 2.0, 0.5)
	if not await atk_wait(0.6, g): return
	pull = true
	Game.add_trauma(0.5)
	for k in 6:
		Atk.ring(zone, _core_world(), 5, 70.0, ORB, k * 0.5, 4.0, 4.0)
		if not await atk_wait(0.5, g):
			zone.arrow.wind = Vector2.ZERO
			return
	pull = false
	zone.arrow.wind = Vector2.ZERO
	_pose(1.0, 1.0, 0.3)
	await atk_wait(0.5, g)

func _atk_star_fall(g: int) -> void:
	_pose(1.06, 0.94, 0.4)
	_fists("raise", 0.45)
	Sfx.play("roar", 0.0, 0.6)
	if not await atk_wait(0.6, g): return
	for i in 6:
		var p: Vector2 = _lead(0.5) if i == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(25.0, 115.0))
		var warm := i % 2 == 0
		Atk.blast(zone, p, 36.0, 1.5 + 0.28 * i, Color("ef8d35") if warm else Color("9b8cff"), "bosses/sun_big.png" if warm else "bosses/moon_big.png", "fall", 0.5)
	for i in 8:
		var p2 := Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 100.0))
		Atk.blast(zone, p2, 16.0, 1.0 + 0.16 * i, LAVA, "bosses/fire_drop.png", "fall", 0.3)
	_pose(1.0, 1.0, 0.3)
	if not await atk_wait(3.3, g): return

func _atk_shadow_clones(g: int) -> void:
	_pose(1.05, 0.95, 0.4)
	_fists("clap", 0.35)
	Sfx.play("telegraph", -2.0, 1.3)
	var ghosts: Array = []
	for sgn in [-1.0, 1.0]:
		var gp := Atk.clamp_in(zone, player.global_position + Vector2(sgn * 115.0, randf_range(-50.0, 50.0)), 40.0)
		var gs := Sprite2D.new()
		gs.texture = body.texture
		gs.offset = Vector2(0, -body.texture.get_height() / 2.0)
		gs.modulate = Color(0.75, 0.5, 1.0, 0.5)
		gs.position = gp
		zone.entities.add_child(gs)
		ghosts.append({"s": gs, "p": gp})
		Fx.burst(zone.entities, gp, [Color("ffffff"), Color("c86aff")], 14, 70.0, 0.5, 2.0)
	for wave in 3:
		if not await atk_wait(0.9 if wave == 0 else 0.55, g):
			for gh in ghosts:
				gh["s"].queue_free()
			return
		Sfx.play("orb", -2.0, 1.2)
		var srcs: Array = [_core_world()]
		for gh in ghosts:
			srcs.append(gh["p"] + Vector2(0, -90))
		for src in srcs:
			Atk.fan(zone, src, (player.global_position - src).angle(), 5, 0.8, 130.0, ORB, 4.0, 5.0)
	for gh in ghosts:
		gh["s"].queue_free()
	_pose(1.0, 1.0, 0.3)
	await atk_wait(0.6, g)

# ------------------------------------------------------------------ death
func _on_death_begin() -> void:
	super._on_death_begin()
	pull = false
	particles.emitting = false
	if zone.arrow:
		zone.arrow.wind = Vector2.ZERO
	for o in orbs:
		o.active = false
		o.visible = false

func _death_sequence() -> void:
	body.material = null
	for i in 16:
		var off := Vector2(randf_range(-30, 30), randf_range(-100, -10))
		Fx.burst(zone.entities, global_position + off, [Color("ffe9a8"), RIM[phase]], 16, 130.0, 0.8, 2.0, 60.0)
		if i % 4 == 0:
			Fx.death_burst(zone.entities, global_position + off)
		body.position.x = randf_range(-2.0, 2.0)
		body.modulate = Color(3, 3, 3) if i % 2 == 0 else Color.WHITE
		Game.add_trauma(0.2)
		await get_tree().create_timer(0.11, true, false, true).timeout
		if not is_inside_tree():
			return
	create_tween().tween_property(body, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.6, true, false, true).timeout
	_arena_reaction()
	Fx.death_burst(zone.entities, global_position + Vector2(0, -60))
	body.visible = false

func _arena_reaction() -> void:
	Game.add_trauma(1.0)
	RingFx.spawn(zone.entities, global_position + Vector2(0, -50), Color(1, 1, 1, 1), 10, 420, 1.2, 4.0, true)
	for s in seals:
		s.visible = false
	for f in fists:
		f["node"].visible = false
	for a in arms:
		a.visible = false
	core_node.visible = false
	for sh in shrines.values():
		sh["hint"].visible = false
