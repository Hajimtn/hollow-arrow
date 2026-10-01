extends BossBase
## THE TWIN SENTINELS (Evil Wizard 2 art, CC0) - two wizards of the observatory, one warded in warm light and one in cold light
## (the rim colour), each carrying the red gem on its staff. A ward ring shows the shell is closed; when the shell breaks the wizard
## reels (the "hurt" animation) and the gem, which is the weak point, is armed only while it does. Twelve attacks, none reused:
##   Phase 1  SUN & MOON   link beam (a beam that strikes the other twin breaks ITS ward: the window), rune circles, shadow claws,
##                         swap nova.  Kill one and the fight changes.
##   Phase 2  THE SURVIVOR blink storm, GRAVITY WELL (it pulls you and bends your arrow; afterwards the wizard is spent: the
##                         window), mirror images, claw lattice.
##   Phase 3  ECLIPSE      ECLIPSE BEAMS (four spinning arms; afterwards the giant is spent: the window, recalled arrow only),
##                         moon fall, arcane grid, solar flare.

const ATTACKS := {
	1: ["link_beam", "rune_circles", "shadow_claws", "swap_nova"],
	2: ["blink_storm", "gravity_well", "mirror_images", "claw_lattice"],
	3: ["eclipse_beams", "moon_fall", "arcane_grid", "solar_flare"],
}

class Sentinel extends Node2D:
	var kind := "sun"
	var alive := true
	var evolved := false
	var overloaded := false
	var overload_t := 0.0
	var sprite: AnimatedSprite2D
	var shielded := true : set = _set_shielded
	var ring_r := 19.0
	var armor: Armor
	var weak: WeakPoint
	var hazard: Hazard
	var orbit := 0.0
	var bob := 0.0
	var orbits := true

	func _set_shielded(v: bool) -> void:
		shielded = v
		queue_redraw()

	func _draw() -> void:
		if shielded:
			var c := Color(1.0, 0.75, 0.4, 0.55) if kind == "sun" else Color(0.65, 0.6, 1.0, 0.55)
			if kind == "eclipse":
				c = Color(0.95, 0.4, 0.4, 0.6)
			draw_arc(Vector2(0, -24), ring_r, 0.0, TAU, 40, c, 1.0)
			draw_arc(Vector2(0, -24), ring_r - 2.0, 0.0, TAU, 40, Color(c, 0.25), 1.0)

const SHEET := "bosses/wizard.png"     # 125x125 cells, 8 columns: rows 0 idle, 1 run, 2 attack1 (claws), 3 attack2 (spell), 4 hurt, 5 death
const ANIMS := {
	"idle": {"frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 8},
	"run": {"frames": [8, 9, 10, 11, 12, 13, 14, 15], "fps": 10},
	"attack1": {"frames": [16, 17, 18, 19, 20, 21, 22, 23], "fps": 8, "loop": false},   # staff thrust, shadow claws from frame 3
	"attack2": {"frames": [24, 25, 26, 27, 28, 29, 30, 31], "fps": 8, "loop": false},   # spell: the gem flares
	"hurt": {"frames": [32, 33, 34, 33], "fps": 5},
	"death": {"frames": [40, 41, 42, 43, 44, 45, 46], "fps": 7, "loop": false},
}
# staff gem, relative to the cell centre (measured on the sheet): idle and hurt frames
const GEM_IDLE := Vector2(9.5, -7.0)
const GEM_HURT := [Vector2(1.0, -7.0), Vector2(2.5, -7.0), Vector2(3.5, -7.0), Vector2(2.5, -7.0)]
const RIM := {"sun": Color("ef8d35"), "moon": Color("9b8cff"), "eclipse": Color("db4f3a")}
const ORBIT_SPEED := 0.42
const OVERLOAD_TIME := 5.5
const PHASE_TIPS := {
	2: "THE SURVIVOR EVOLVES. ITS BEAMS RICOCHET - AND EACH ONE CRACKS ITS OWN SHELL.",
	3: "ECLIPSE! DODGE THE SPINNING BEAMS, THEN RECALL THE ARROW ACROSS ITS OPEN CORE.",
}

var phase := 1
var tw: Array = []
var attacker: Sentinel = null
var turn := 0
var beam_dir := Vector2.RIGHT
var tele_line: Line2D
var beam_hazard: Hazard
var beam_line: Line2D
var beam_info := {}
var beam_segs: Array = []
var quad_pivot: Node2D
var quad_hazards: Array = []
var quad_lines: Array = []
var quad_base := 0.0
var phase_pending := 0
var dying: Sentinel = null
var last_pos := Vector2.ZERO
var fired_once := false
var well_on := false
var well_pos := Vector2.ZERO
var well_node: Node2D
var well_hazard: Hazard

func _build() -> void:
	for i in 2:
		var s := _make_sentinel("sun" if i == 0 else "moon")
		s.orbit = PI * i
		tw.append(s)
	_place_all()
	tele_line = Line2D.new()
	tele_line.width = 1.0
	tele_line.default_color = Color(1, 1, 1, 0)
	tele_line.add_point(Vector2.ZERO)
	tele_line.add_point(Vector2.ZERO)
	tele_line.z_index = 3
	tele_line.visible = Game.SHOW_AIM_TELEGRAPHS
	add_child(tele_line)
	beam_line = Line2D.new()
	beam_line.width = 5.0
	beam_line.default_color = Color(1, 1, 1, 0)
	beam_line.add_point(Vector2.ZERO)
	beam_line.add_point(Vector2.ZERO)
	beam_line.z_index = 3
	add_child(beam_line)
	beam_hazard = Hazard.box(Vector2(10, 7))
	add_child(beam_hazard)
	beam_hazard.active = false
	quad_pivot = Node2D.new()
	quad_pivot.visible = false
	add_child(quad_pivot)
	for i in 4:
		var h := Hazard.box(Vector2(280, 9), Vector2(140, 0))
		h.rotation = TAU * i / 4.0
		var ln := Line2D.new()
		ln.width = 6.0
		ln.default_color = Color(1.0, 0.9, 1.0)
		ln.points = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(TAU * i / 4.0) * 280.0])
		quad_pivot.add_child(ln)
		quad_pivot.add_child(h)
		h.active = false
		quad_hazards.append(h)
		quad_lines.append(ln)
	_make_well()

func _make_well() -> void:
	well_node = Node2D.new()
	well_node.z_index = -2
	well_node.visible = false
	add_child(well_node)
	well_hazard = Hazard.circle(11.0)
	well_node.add_child(well_hazard)
	well_hazard.active = false
	var draw := Node2D.new()
	draw.draw.connect(func():
		for k in 7:
			var r := 46.0 - k * 6.0
			draw.draw_arc(Vector2.ZERO, r, k * 0.9, k * 0.9 + 4.4, 24, Color(0.45, 0.35, 0.85, 0.15 + 0.07 * k), 2.0)
		draw.draw_circle(Vector2.ZERO, 11.0, Color(0.03, 0.0, 0.08, 0.95)))
	well_node.add_child(draw)

func _make_sentinel(kind: String) -> Sentinel:
	var s := Sentinel.new()
	s.kind = kind
	s.sprite = AnimatedSprite2D.new()
	s.sprite.sprite_frames = Gfx.sheet_frames(SHEET, 125, 125, ANIMS)
	s.sprite.position = Vector2(0, -24)
	s.sprite.material = ShaderMaterial.new()
	s.sprite.material.shader = load("res://shaders/rim.gdshader")
	s.sprite.material.set_shader_parameter("rim_color", RIM[kind])
	s.sprite.play("idle")
	s.add_child(s.sprite)
	sprites.append(s.sprite)
	s.hazard = Hazard.circle(13.0, Vector2(0, -14))
	s.add_child(s.hazard)
	s.armor = Armor.make_circle(19.0, Vector2(0, -24))
	s.add_child(s.armor)
	s.armor.clanked.connect(func(_p, _k): flash_sprite(s.sprite, 0.08))
	s.weak = WeakPoint.make(13.0, Vector2(0, -24))
	s.add_child(s.weak)
	s.weak.struck.connect(_on_sentinel_struck.bind(s))
	add_child(s)
	return s

func _play(s: Sentinel, anim: String, speed := 1.0) -> void:
	if (anim == "attack1" or anim == "attack2") and s.sprite.animation != anim and zone != null:
		Fx.charge(zone.entities, s.global_position + Vector2(0, -34), _col(s), 0.6, 30.0)
		RingFx.spawn(zone.entities, s.global_position + Vector2(0, -2), Color(_col(s), 0.6), 4.0, 26.0, 0.5, 1.0)
	s.sprite.speed_scale = speed
	if s.sprite.animation != anim or not s.sprite.is_playing():
		s.sprite.play(anim)

func _gem_offset(s: Sentinel) -> Vector2:
	var g := GEM_IDLE
	if s.sprite.animation == "hurt":
		g = GEM_HURT[clampi(s.sprite.frame, 0, 3)]
	var k := 2.0 if s.kind == "eclipse" else (1.25 if s.evolved else 1.0)
	return Vector2(-g.x if s.sprite.flip_h else g.x, g.y) * k

func _place_all() -> void:
	for s in tw:
		if s.orbits:
			s.position = Vector2(cos(s.orbit) * 150.0, sin(s.orbit) * 66.0)

func other_of(s: Sentinel) -> Sentinel:
	for o in tw:
		if o != s and o.alive:
			return o
	return null

func alive_list() -> Array:
	var a := []
	for s in tw:
		if s.alive:
			a.append(s)
	return a

func _dormant(delta: float) -> void:
	for s in tw:
		s.bob += delta
		s.sprite.position.y = -24.0 + sin(s.bob * 2.0 + s.orbit) * 2.0
		s.sprite.flip_h = player.global_position.x < s.global_position.x

func _on_start() -> void:
	set_state("idle")

# ------------------------------------------------------------------ state entry
func attack_list() -> Array:
	return ATTACKS[phase]

func all_attacks() -> Dictionary:
	return ATTACKS

func _attack_done(_attack_name: String) -> void:
	attacker = null
	set_state("idle")

func _enter(s: String) -> void:
	if s != "attack":
		tele_line.default_color.a = 0.0
		beam_line.default_color.a = 0.0
		beam_hazard.active = false
		quad_pivot.visible = false
		for h in quad_hazards:
			h.active = false
		for s2 in alive_list():
			s2.orbits = s2.kind != "eclipse"
			s2.sprite.modulate.a = 1.0
	match s:
		"idle":
			attacker = null
		"evolve":
			for s2 in alive_list():
				s2.hazard.active = false
				s2.weak.armed = false
			Sfx.play("shatter")
			Game.hitstop(0.12)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)

# ------------------------------------------------------------------ per-frame
func _tick(delta: float) -> void:
	var busy := state == "attack"
	for s in alive_list():
		s.bob += delta
		s.sprite.position.y = -24.0 + sin(s.bob * 2.0 + s.orbit) * 2.0
		s.sprite.flip_h = player.global_position.x < s.global_position.x     # the art faces right
		s.weak.position = s.sprite.position + _gem_offset(s)
		if s.overloaded:
			s.overload_t -= delta
			s.sprite.position.x = randf_range(-0.6, 0.6)
			if s.overload_t <= 0.0:
				_close(s)
	if state != "evolve":
		for s in alive_list():
			if s.overloaded or not s.orbits:
				continue
			if busy and s == attacker:
				continue
			var speed := ORBIT_SPEED * (1.0 if phase == 1 else 1.6)
			s.orbit += speed * delta * (0.5 if busy else 1.0)
			s.position = Vector2(cos(s.orbit) * 150.0, sin(s.orbit) * 66.0)
	if well_on:
		_tick_well(delta)
	match state:
		"idle":
			var wait_t := 0.9 if phase == 1 else (0.7 if phase == 2 else 0.5)
			if t > wait_t:
				start_attack(pick_attack())
		"evolve":
			if dying:
				dying.modulate.a = maxf(0.0, dying.modulate.a - delta * 1.5)
			for s in alive_list():
				s.sprite.position.x = randf_range(-1.5, 1.5)
			if t >= 1.0 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
			if t >= 2.4:
				for s in alive_list():
					s.sprite.position.x = 0.0
					s.hazard.active = not s.overloaded
				set_state("idle")

func _apply_phase(np: int) -> void:
	phase = np
	zone.on_phase(np)
	turn = 0
	reset_attacks()
	if np == 2:
		var s: Sentinel = alive_list()[0]
		s.evolved = true
		s.overloaded = false
		s.sprite.scale = Vector2(1.25, 1.25)                # the survivor grows: its rim turns red
		s.sprite.material.set_shader_parameter("rim_color", RIM["eclipse"])
		s.ring_r = 22.0
		s.shielded = true
		_play(s, "idle")
		s.armor.enabled = true
		s.weak.armed = false
		flash_sprite(s.sprite, 0.5)
	else:
		var e := _make_sentinel("eclipse")
		e.orbits = false
		e.sprite.scale = Vector2(2.0, 2.0)                  # the eclipse: both wizards fused into one giant
		e.sprite.self_modulate = Color(0.55, 0.4, 0.7)
		e.ring_r = 34.0
		e.position = last_pos
		e.sprite.position = Vector2(0, -30)
		e.hazard.set_radius(26.0)
		e.hazard.position = Vector2(0, -26)
		(e.armor.get_child(0).shape as CircleShape2D).radius = 34.0
		e.armor.position = Vector2(0, -30)
		e.weak.position = Vector2(0, -30)
		(e.weak.get_child(0).shape as CircleShape2D).radius = 15.0
		e.weak.accept_fly = false
		e.weak.accept_ret = true
		tw.append(e)
		create_tween().tween_property(e, "position", Vector2(0, 8), 1.0)
		flash_sprite(e.sprite, 0.6)
		e.hazard.active = false
	Sfx.play("stun", 0.0, 0.7)
	Sfx.play("crash")
	Game.add_trauma(1.0)
	RingFx.spawn(zone.entities, global_position + Vector2(0, -20), Color("ffb040"), 8, 130, 0.6, 4.0)
	Game.show_banner("ECLIPSE" if np == 3 else "THE SURVIVOR EVOLVES", "PHASE %d" % np)
	Game.say(PHASE_TIPS[np], 6.0)

func _update_tele_line(from: Vector2) -> void:
	tele_line.clear_points()
	if phase == 1:
		var info := _beam_end(attacker, beam_dir)
		tele_line.add_point(to_local(from))
		tele_line.add_point(to_local(from + beam_dir * float(info["len"])))
	else:
		beam_segs = BeamShot.compute(self, from, beam_dir, 1)
		for i in beam_segs.size():
			tele_line.add_point(to_local(beam_segs[i][0]))
			if i == beam_segs.size() - 1:
				tele_line.add_point(to_local(beam_segs[i][1]))
	tele_line.width = 1.0 if t < 0.95 else 2.0
	var blink := absf(sin(t * (10.0 if t < 0.95 else 30.0)))
	tele_line.default_color = Color(1.0, 0.8, 0.4, 0.3 + 0.6 * blink) if attacker.kind == "sun" else Color(0.75, 0.6, 1.0, 0.3 + 0.6 * blink)

func _beam_end(a: Sentinel, dir: Vector2) -> Dictionary:
	var from := a.global_position + Vector2(0, -5)
	var wall_d := wall_distance(from, dir, 700.0)
	var res := {"len": wall_d, "twin": null}
	var o := other_of(a)
	if o != null:
		var to := (o.global_position + Vector2(0, -5)) - from
		var proj := to.dot(dir)
		if proj > 0.0 and proj < wall_d:
			var perp := absf(to.cross(dir))
			if perp < 16.0:
				res = {"len": maxf(4.0, proj - 12.0), "twin": o}
	return res

func _fire_beam() -> void:
	var from := attacker.global_position + Vector2(0, -5)
	var col := Color(1.0, 0.95, 0.7, 1.0) if attacker.kind == "sun" else Color(0.9, 0.8, 1.0, 1.0)
	if phase == 1:
		beam_info = _beam_end(attacker, beam_dir)
		var ln: float = beam_info["len"]
		var end := from + beam_dir * ln
		beam_line.set_point_position(0, to_local(from))
		beam_line.set_point_position(1, to_local(end))
		beam_line.default_color = col
		beam_hazard.set_size(Vector2(ln, 7.0))
		beam_hazard.global_position = from + beam_dir * ln / 2.0
		beam_hazard.rotation = beam_dir.angle()
		beam_hazard.active = true
		Fx.sparks(zone.entities, end, 10)
		var victim: Sentinel = beam_info["twin"]
		if victim != null and victim.alive and not victim.overloaded:
			_overload(victim)
	else:
		var segs := BeamShot.compute(self, from, beam_dir, 1)
		BeamShot.fire(zone.entities, segs, 7.0, 0.55, col)
		for sg in segs:
			Fx.sparks(zone.entities, sg[1], 8)
	Sfx.play("beam")
	Game.add_trauma(0.35)

func _fire_nova(offset: float) -> void:
	Sfx.play("orb", 0.0, 0.9)
	Game.add_trauma(0.2)
	var n := 10 if phase == 1 else (14 if phase == 2 else 18)
	var tex := "bosses/orb_%s.png" % (attacker.kind if attacker.kind != "eclipse" else "moon")
	for i in n:
		var a := TAU * i / n + offset + (0.3 if offset == 0.0 else 0.0)
		Projectile.spawn(zone.entities, attacker.global_position + Vector2(0, -14), Vector2.from_angle(a) * (82.0 + 10.0 * phase), tex, 4.0, 8.0)

func _overload(s: Sentinel) -> void:
	s.overloaded = true
	s.overload_t = OVERLOAD_TIME if phase == 1 else (3.6 if phase == 2 else 2.6)
	_play(s, "hurt")
	s.shielded = false
	s.armor.enabled = false
	s.weak.armed = true
	s.hazard.active = false
	Sfx.play("stun")
	Sfx.play("shatter", -4.0)
	Game.hitstop(0.06)
	Game.add_trauma(0.7)
	Fx.debris(zone.entities, s.global_position + Vector2(0, -24), [Color("aab0c0"), Color("5a6078")], 16)
	RingFx.spawn(zone.entities, s.global_position + Vector2(0, -24), Color(1, 0.9, 0.6, 0.9), 4, 44, 0.35, 2.0)
	if phase == 1:
		Game.say("THE SHELL CRACKS - STRIKE THE CORE!", 2.0)

func _close(s: Sentinel) -> void:
	s.overloaded = false
	_play(s, "idle")
	s.shielded = true
	s.sprite.position.x = 0.0
	s.armor.enabled = true
	s.weak.armed = false
	s.hazard.active = true

# ------------------------------------------------------------------ attack helpers
func _pick_attacker() -> Sentinel:
	var list := alive_list()
	var a: Sentinel = list[turn % list.size()]
	turn += 1
	return a

func _col(a: Sentinel) -> Color:
	return Color(1.0, 0.7, 0.3) if a.kind == "sun" else (Color(0.7, 0.55, 1.0) if a.kind == "moon" else Color(0.95, 0.4, 0.4))

func _orb_tex(a: Sentinel) -> String:
	return "bosses/orb_%s.png" % (a.kind if a.kind != "eclipse" else "moon")

func _lead(extra := 0.4) -> Vector2:
	return Atk.clamp_in(zone, player.global_position + player.velocity * extra)

func _ghost(pos: Vector2, s: Sentinel) -> Sprite2D:
	var gs := Sprite2D.new()
	gs.texture = s.sprite.sprite_frames.get_frame_texture(s.sprite.animation, s.sprite.frame)
	gs.scale = s.sprite.scale
	gs.flip_h = pos.x > player.global_position.x
	gs.modulate = Color(0.85, 0.7, 1.0, 0.55)
	gs.position = pos + Vector2(0, -24)
	zone.entities.add_child(gs)
	Fx.burst(zone.entities, pos, [Color("ffffff"), Color("a89ad0")], 12, 60.0, 0.4, 2.0)
	return gs

func _tick_well(delta: float) -> void:
	var to := well_pos - player.global_position
	if to.length() > 8.0:
		player.move_and_collide(to.normalized() * 64.0 * delta)
	if zone.arrow:
		zone.arrow.wind = (well_pos - zone.arrow.global_position).normalized() * 320.0

func _end_well() -> void:
	well_on = false
	well_node.visible = false
	well_hazard.active = false
	if zone.arrow:
		zone.arrow.wind = Vector2.ZERO

# ------------------------------------------------------------------ PHASE 1 - SUN & MOON
func _atk_link_beam(g: int) -> void:
	attacker = _pick_attacker()
	_play(attacker, "attack1", 0.8 / 1.2)
	Sfx.play("telegraph", -2.0, 1.2)
	flash_sprite(attacker.sprite, 0.4)
	var el := 0.0
	while el < 1.2:
		var from := attacker.global_position + Vector2(0, -5)
		if el < 0.95:
			beam_dir = (player.global_position + Vector2(0, -5) - from).normalized()
		el += get_physics_process_delta_time()
		await get_tree().physics_frame
		if not atk_ok(g): return
	_play(attacker, "attack2")
	_fire_beam()
	var el2 := 0.0
	while el2 < 0.55:
		el2 += get_physics_process_delta_time()
		beam_line.default_color.a = 1.0 - el2 / 0.7
		await get_tree().physics_frame
		if not atk_ok(g): return
	beam_hazard.active = false
	beam_line.default_color.a = 0.0
	if not await atk_wait(0.5, g): return

func _atk_rune_circles(g: int) -> void:
	attacker = _pick_attacker()
	_play(attacker, "attack2", 0.8 / 0.9)
	Sfx.play("telegraph", -2.0, 0.9)
	if not await atk_wait(0.5, g): return
	for k in 3:
		var p: Vector2 = _lead(0.5) if k == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0))
		Atk.blast(zone, p, 26.0, 1.3 + 0.28 * k, _col(attacker), "", "none", 0.5)
	if not await atk_wait(2.3, g): return

func _atk_shadow_claws(g: int) -> void:
	attacker = _pick_attacker()
	_play(attacker, "attack1", 0.8 / 0.7)
	Sfx.play("telegraph", -2.0, 1.1)
	if not await atk_wait(0.7, g): return
	var d := (player.global_position - attacker.global_position).normalized()
	Atk.line_blasts(zone, attacker.global_position, d, 11, 20.0, 12.0, 0.4, 0.06, _col(attacker), "bosses/claw.png", "rise")
	if not await atk_wait(1.6, g): return

func _atk_swap_nova(g: int) -> void:
	var list := alive_list()
	if list.size() < 2:
		return
	var a: Sentinel = list[0]
	var b2: Sentinel = list[1]
	_play(a, "attack2", 0.8 / 0.7)
	_play(b2, "attack2", 0.8 / 0.7)
	Sfx.play("telegraph", -2.0, 1.3)
	if not await atk_wait(0.7, g): return
	var pa := a.position
	var pb := b2.position
	var oa := a.orbit
	a.orbits = false
	b2.orbits = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(a, "position", pb, 0.35)
	tw.tween_property(b2, "position", pa, 0.35)
	Fx.burst(zone.entities, a.global_position, [Color("ffffff"), Color("ef8d35")], 12, 70.0, 0.4, 2.0)
	Fx.burst(zone.entities, b2.global_position, [Color("ffffff"), Color("9b8cff")], 12, 70.0, 0.4, 2.0)
	if not await atk_wait(0.4, g): return
	a.orbit = b2.orbit
	b2.orbit = oa
	a.orbits = true
	b2.orbits = true
	attacker = a
	_fire_nova(0.0)
	attacker = b2
	_fire_nova(PI / 10.0)
	if not await atk_wait(1.2, g): return

# ------------------------------------------------------------------ PHASE 2 - THE SURVIVOR
func _atk_blink_storm(g: int) -> void:
	var s: Sentinel = alive_list()[0]
	attacker = s
	s.orbits = false
	for k in 3:
		_play(s, "attack2", 1.4)
		var tw := create_tween()
		tw.tween_property(s.sprite, "modulate:a", 0.0, 0.2)
		Fx.burst(zone.entities, s.global_position, [Color("ffffff"), Color("db4f3a")], 14, 80.0, 0.4, 2.0)
		if not await atk_wait(0.25, g): return
		var dest := Vector2(randf_range(60.0, zone.w * 16.0 - 60.0), randf_range(70.0, zone.h * 16.0 - 60.0))
		s.global_position = Atk.clamp_in(zone, dest, 40.0)
		create_tween().tween_property(s.sprite, "modulate:a", 1.0, 0.15)
		Fx.burst(zone.entities, s.global_position, [Color("ffffff"), Color("db4f3a")], 14, 80.0, 0.4, 2.0)
		Sfx.play("orb", -2.0, 1.2)
		Atk.ring(zone, s.global_position + Vector2(0, -14), 12, 105.0, _orb_tex(s), k * 0.3, 4.0, 5.0)
		if not await atk_wait(0.6, g): return
	s.orbit = atan2(s.position.y / 66.0, s.position.x / 150.0)
	s.orbits = true

func _atk_gravity_well(g: int) -> void:
	var s: Sentinel = alive_list()[0]
	attacker = s
	_play(s, "attack2", 0.8 / 0.6)
	Sfx.play("roar", -2.0, 0.7)
	if not await atk_wait(0.6, g): return
	well_pos = Vector2(zone.w * 8.0, zone.h * 8.0)
	well_node.global_position = well_pos
	well_node.visible = true
	well_hazard.active = true
	well_on = true
	Game.add_trauma(0.5)
	for k in 6:
		Atk.ring(zone, well_pos, 5, 70.0, _orb_tex(s), k * 0.5, 4.0, 4.0)
		if not await atk_wait(0.52, g):
			_end_well()
			return
	_end_well()
	if s.alive and not s.overloaded:
		_overload(s)          # the wizard is spent: its ward is down
	await atk_wait(0.3, g)

func _atk_mirror_images(g: int) -> void:
	var s: Sentinel = alive_list()[0]
	attacker = s
	_play(s, "attack2", 0.8 / 0.9)
	Sfx.play("telegraph", -2.0, 1.4)
	var ghosts: Array = []
	for i in 2:
		var gp := Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(90.0, 140.0), 40.0)
		ghosts.append({"s": _ghost(gp, s), "p": gp})
	for wave in 3:
		if not await atk_wait(0.8 if wave == 0 else 0.6, g):
			for gh in ghosts:
				gh["s"].queue_free()
			return
		Sfx.play("orb", -2.0, 1.3)
		var srcs: Array = [s.global_position + Vector2(0, -14)]
		for gh in ghosts:
			srcs.append(gh["p"] + Vector2(0, -14))
		for src in srcs:
			Atk.fan(zone, src, (player.global_position - src).angle(), 3, 0.5, 120.0, _orb_tex(s), 4.0, 5.0)
	for gh in ghosts:
		gh["s"].queue_free()
	if not await atk_wait(0.5, g): return

func _atk_claw_lattice(g: int) -> void:
	var s: Sentinel = alive_list()[0]
	attacker = s
	_play(s, "attack1", 0.8 / 0.6)
	Sfx.play("telegraph", -2.0, 1.0)
	if not await atk_wait(0.6, g): return
	var c := player.global_position
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		Atk.line_blasts(zone, c + dir * 14.0, dir, 9, 22.0, 12.0, 1.1, 0.05, _col(s), "bosses/claw.png", "rise")
	if not await atk_wait(1.0, g): return
	for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		Atk.line_blasts(zone, c + dir.normalized() * 14.0, dir, 8, 22.0, 12.0, 0.9, 0.05, _col(s), "bosses/claw.png", "rise")
	if not await atk_wait(1.6, g): return

# ------------------------------------------------------------------ PHASE 3 - ECLIPSE
func _atk_eclipse_beams(g: int) -> void:
	var e: Sentinel = alive_list()[0]
	attacker = e
	quad_base = randf() * TAU
	_play(e, "attack2", 0.8 / 1.3)
	Sfx.play("telegraph", 0.0, 0.7)
	Sfx.play("roar", -2.0, 0.8)
	flash_sprite(e.sprite, 0.8)
	var el := 0.0
	while el < 1.3:
		e.sprite.position.x = randf_range(-1.2, 1.2)
		el += get_physics_process_delta_time()
		await get_tree().physics_frame
		if not atk_ok(g): return
	e.sprite.position.x = 0.0
	quad_pivot.global_position = e.global_position + Vector2(0, -20)
	quad_pivot.rotation = quad_base
	quad_pivot.visible = true
	for h in quad_hazards:
		h.active = true
	Sfx.play("beam", 2.0, 0.8)
	Game.add_trauma(0.5)
	var el2 := 0.0
	while el2 < 2.2:
		el2 += get_physics_process_delta_time()
		quad_pivot.rotation = quad_base + (el2 / 2.2) * 1.9
		await get_tree().physics_frame
		if not atk_ok(g): return
	quad_pivot.visible = false
	for h in quad_hazards:
		h.active = false
	if e.alive and not e.overloaded:
		_overload(e)
	await atk_wait(0.3, g)

func _atk_moon_fall(g: int) -> void:
	var e: Sentinel = alive_list()[0]
	attacker = e
	_play(e, "attack2", 0.8 / 0.8)
	Sfx.play("roar", 0.0, 0.6)
	if not await atk_wait(0.8, g): return
	for i in 5:
		var p: Vector2 = _lead(0.5) if i == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(25.0, 110.0))
		var warm := i % 2 == 0
		Atk.blast(zone, p, 40.0, 1.5 + 0.3 * i, Color("ef8d35") if warm else Color("9b8cff"), "bosses/sun_big.png" if warm else "bosses/moon_big.png", "fall", 0.5)
	if not await atk_wait(3.3, g): return

func _atk_arcane_grid(g: int) -> void:
	var e: Sentinel = alive_list()[0]
	attacker = e
	_play(e, "attack1", 0.8 / 0.8)
	Sfx.play("telegraph", -2.0, 0.8)
	var w := zone.w * 16.0
	var h := zone.h * 16.0
	var rows := [70.0, 114.0, 158.0, 202.0, 246.0]
	var cols := [70.0, 130.0, 190.0, 250.0, 310.0, 370.0, 430.0]
	rows.shuffle()
	cols.shuffle()
	for wave in 2:
		var segs := []
		var ends := []
		if wave == 0:
			for i in 3:
				segs.append([Vector2(16.0, rows[i]), Vector2(w - 16.0, rows[i])])
				ends.append(Vector2(20.0, rows[i]))
				ends.append(Vector2(w - 20.0, rows[i]))
		else:
			for i in 3:
				segs.append([Vector2(cols[i], 40.0), Vector2(cols[i], h - 24.0)])
				ends.append(Vector2(cols[i], 44.0))
				ends.append(Vector2(cols[i], h - 28.0))
		for k in 3:                                        # sparks at the line ends are the only warning
			for pnt in ends:
				Fx.sparks(zone.entities, pnt, 3)
			if not await atk_wait(0.2, g): return
		if not await atk_wait(0.5, g): return
		BeamShot.fire(zone.entities, segs, 9.0, 0.45, _col(e))
		Sfx.play("beam", -2.0, 1.2)
		Game.add_trauma(0.3)
		if not await atk_wait(0.7, g): return
	if not await atk_wait(0.3, g): return

func _atk_solar_flare(g: int) -> void:
	var e: Sentinel = alive_list()[0]
	attacker = e
	_play(e, "attack2", 0.8 / 0.7)
	Sfx.play("roar", 2.0, 0.5)
	Game.hitstop(0.05)
	if not await atk_wait(0.7, g): return
	for k in 3:
		var r := RingHazard.spawn(zone.entities, e.global_position + Vector2(0, -6), Color("ffc060") if k % 2 == 0 else Color("9b8cff"))
		r.expand(150.0 - 12.0 * k, 1.0)
		Atk.ring(zone, e.global_position + Vector2(0, -14), 18, 95.0 + 10.0 * k, _orb_tex(e), k * 0.17, 4.0, 4.0)
		Sfx.play("slam", -4.0, 1.0 - 0.1 * k)
		Game.add_trauma(0.5)
		if not await atk_wait(0.7, g): return
	if not await atk_wait(0.6, g): return


func _on_sentinel_struck(_kind: String, s: Sentinel) -> void:
	if not s.alive or state == "evolve":
		return
	s.alive = false
	s.weak.armed = false
	s.hazard.active = false
	s.armor.enabled = false
	s.shielded = false
	if phase < 3:
		_play(s, "death")
	Sfx.play("boss_death", -8.0, 1.5)
	Game.hitstop(0.12)
	Game.add_trauma(0.9)
	var big_col := [Color("ffe9a8"), Color("ff7a30")] if s.kind == "sun" else [Color("e8d8ff"), Color("8a60ff")]
	Fx.death_burst(zone.entities, s.global_position + Vector2(0, -24), big_col)
	tele_line.default_color.a = 0.0
	beam_line.default_color.a = 0.0
	beam_hazard.active = false
	quad_pivot.visible = false
	for h in quad_hazards:
		h.active = false
	last_pos = s.position
	if phase == 3:
		global_position = s.global_position + Vector2(0, -24)
		s.position = Vector2.ZERO
		s.sprite.position = Vector2.ZERO
		kill()
		return
	dying = s
	phase_pending = phase + 1
	Game.say("ONE FALLS!" if phase == 1 else "THE LAST TWIN FALLS... BUT THE SUN AND MOON ARE NOT DONE.", 2.5)
	set_state("evolve")

func _on_weak_struck(_kind: String) -> void:
	pass

func _death_sequence() -> void:
	var e: Sentinel = tw.back()
	e.sprite.self_modulate = Color.WHITE
	_death_by_animation(e.sprite, "death", [Color("e8d8ff"), Color("db4f3a")])
