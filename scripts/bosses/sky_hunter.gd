extends BossBase
## SKY HUNTER (ArcherHero art, drawn at 2x) - a cloaked archer that rides the gale. Every shooting attack costs one arrow from its
## quiver; when the quiver is empty it must LAND and kneel to refill it, and that is the weak-point window. The hit circle follows
## the head / quiver on the kneeling animation frame by frame (BossAnchors.HUNTER_KNEEL_*).
##   Phase 1  MARKSMAN   snipe (double tap), triple volley, skidding arrows that ricochet, and the ARROW THIEF: it snatches your
##                       arrow off the floor - recall it and it flies out of its hands.   Reload window 4.6s: any arrow at the head.
##   Phase 2  STORMCALLER arrow rain, trap arrows that detonate, a strafing dash and a lightning call.   Reload 3.4s: the QUIVER.
##   Phase 3  TEMPEST    cyclone of arrows, a closing ring of pins, shadow snipe (three shooters) and homing wind volleys.
##                       Reload 2.4s: the head, RECALLED arrows only.
## No attack appears in more than one phase.

const SHEET := "bosses/hunter.png"      # 64x64 cells, 8 columns (built by tools/gen_boss_pack.py)
const SCALE := 2.0
const GROUND_Y := -30.0                 # body offset when standing: puts the feet near the origin
const ANIMS := {
	"fly": {"frames": [56, 57, 58, 59, 60, 61, 62, 63, 64, 65], "fps": 10},
	"draw": {"frames": [16, 17, 18, 19, 20, 21, 22, 23], "fps": 10, "loop": false},
	"release": {"frames": [24, 25, 26], "fps": 14, "loop": false},
	"dash_in": {"frames": [40, 41, 42, 43, 44, 45, 46], "fps": 12, "loop": false},
	"dash": {"frames": [48, 49, 50], "fps": 14},
	"kneel": {"frames": [32, 33, 34, 35, 36, 37], "fps": 6},
	"draw_high": {"frames": [88, 89, 90, 91, 92, 93, 94, 95], "fps": 10, "loop": false},          # bow tilted to the sky
	"release_high": {"frames": [96, 97, 98, 99, 100], "fps": 14, "loop": false},
	"draw_low": {"frames": [104, 105, 106, 107, 108, 109, 110, 111], "fps": 10, "loop": false},   # kneeling, aiming along the ground
	"release_low": {"frames": [112, 113, 114, 115, 116, 117, 118], "fps": 14, "loop": false},
	"death": {"frames": [72, 73, 74, 75, 76, 77, 78, 79, 80, 81], "fps": 8, "loop": false},
}
const TINT := {1: Color(1, 1, 1), 2: Color(0.85, 0.95, 1.25), 3: Color(1.2, 0.85, 1.3)}
const RIM := {1: Color(1, 1, 1, 0), 2: Color("f7efdf"), 3: Color("db4f3a")}
const ARROW := "bosses/arrow_shot.png"

const PHASES := {
	1: {"gap": 0.85, "ammo": 4, "reload": 4.6},
	2: {"gap": 0.65, "ammo": 3, "reload": 3.4},
	3: {"gap": 0.45, "ammo": 3, "reload": 2.4},
}
const ATTACKS := {
	1: ["snipe", "triple", "skid", "thief"],
	2: ["arrow_rain", "trap_arrows", "strafe", "storm_call"],
	3: ["cyclone", "pin_down", "shadow_snipe", "wind_volley"],
}
const PHASE_TIPS := {
	2: "ITS HEAD IS HOODED NOW. WHEN THE QUIVER RUNS DRY AND IT KNEELS, STRIKE THE QUIVER ON ITS BACK.",
	3: "IT KNEELS FOR BARELY TWO SECONDS. RECALL THE ARROW ACROSS ITS HEAD.",
}

var phase := 1
var shadow: Sprite2D
var body: AnimatedSprite2D
var altitude := 46.0
var facing := 1.0
var hazard_impact: Hazard
var hazard_sweep: Hazard
var weak: WeakPoint
var weak_shape: CircleShape2D
var armor: Armor
var armor_shape: CircleShape2D
var floor_rect := Rect2()
var home := Vector2.ZERO
var bob := 0.0
var ammo := 4
var landed := false
var move_tw: Tween
var phase_pending := 0
var face_lock := false
var spiral := 0.0

func attack_list() -> Array:
	return ATTACKS[phase]

func all_attacks() -> Dictionary:
	return ATTACKS

func P(key: String) -> float:
	return PHASES[phase][key]

func _build() -> void:
	shadow = Sprite2D.new()
	var img := Image.create(60, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		for x in 60:
			if pow((x - 29.5) / 29.0, 2.0) + pow((y - 8.5) / 8.5, 2.0) <= 1.0:
				img.set_pixel(x, y, Color(0.05, 0.02, 0.1, 0.4))
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.z_index = -3
	add_child(shadow)
	body = AnimatedSprite2D.new()
	body.sprite_frames = Gfx.sheet_frames(SHEET, 64, 64, ANIMS)
	body.scale = Vector2(SCALE, SCALE)
	body.material = ShaderMaterial.new()
	body.material.shader = load("res://shaders/rim.gdshader")
	body.material.set_shader_parameter("rim_size", 0.6)
	add_child(body)
	sprites.append(body)
	body.play("fly")
	hazard_impact = add_hazard_circle(26.0, Vector2.ZERO, false)
	hazard_sweep = add_hazard_box(Vector2(56, 26), Vector2.ZERO, false)
	weak = add_weak(11.0, Vector2(3, -33))
	weak_shape = weak.get_child(0).shape
	weak.glow.scale = Vector2(0.6, 0.6)
	armor = add_armor_circle(22.0, Vector2(4, 0))
	armor_shape = armor.get_child(0).shape
	armor.enabled = false
	floor_rect = Rect2(zone.cell_center(2, 3), Vector2((zone.w - 5) * 16, (zone.h - 6) * 16))
	home = zone.mark("B")

func _play(anim: String, speed := 1.0) -> void:
	body.speed_scale = speed
	if body.animation != anim or not body.is_playing():
		body.play(anim)

## Head (phases 1, 3) or quiver (phase 2) on the current kneeling frame, relative to the boss origin.
func _weak_pos() -> Vector2:
	var i := clampi(body.frame, 0, 5) if body.animation == "kneel" else 0
	var v: Vector2 = BossAnchors.HUNTER_KNEEL_QUIVER[i] if phase == 2 else BossAnchors.HUNTER_KNEEL_HEAD[i]
	v = v * SCALE + body.position
	v.x *= facing               # the sheet faces right
	return v

func _apply_phase(p: int) -> void:
	phase = p
	zone.on_phase(p)
	armor_shape.radius = 22.0 + 2.0 * (p - 1)
	body.self_modulate = TINT[p]
	(body.material as ShaderMaterial).set_shader_parameter("rim_color", RIM[p])
	ammo = int(P("ammo"))
	landed = false
	reset_attacks()
	_play("fly")

func _set_alt(a: float) -> void:
	altitude = a
	body.position = Vector2(0, GROUND_Y - altitude)
	var k := clampf(1.0 - altitude / 110.0, 0.35, 1.0)
	shadow.scale = Vector2(k, k) * (1.0 + 0.15 * (phase - 1))
	shadow.modulate.a = k

func _set_weak(pos: Vector2, r: float, fly: bool, ret: bool, armed: bool) -> void:
	weak.position = pos
	weak_shape.radius = r
	weak.accept_fly = fly
	weak.accept_ret = ret
	weak.armed = armed

func _face(dx: float) -> void:
	if absf(dx) > 2.0:
		facing = signf(dx)
	body.flip_h = facing < 0.0
	armor.position = Vector2(4.0 * facing, 0)

func _muzzle() -> Vector2:
	return global_position + Vector2(24.0 * facing, -altitude * 0.4 - 6.0)

func _dormant(delta: float) -> void:
	bob += delta
	_set_alt(46.0 + sin(bob * 2.0) * 4.0)
	_face(player.global_position.x - global_position.x)

func _on_start() -> void:
	_apply_phase(1)
	set_state("hover")

func _glide_to(pos: Vector2, dur: float, alt := -1.0) -> void:
	if move_tw and move_tw.is_valid():
		move_tw.kill()
	move_tw = create_tween().set_parallel(true)
	move_tw.tween_property(self, "global_position", Atk.clamp_in(zone, pos, 30.0), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if alt >= 0.0:
		move_tw.tween_method(_set_alt, altitude, alt, dur)

func _attack_done(_attack_name: String) -> void:
	set_state("reload" if ammo <= 0 else "hover")

# ------------------------------------------------------------------ state entry
func _enter(s: String) -> void:
	if s != "attack" and move_tw and move_tw.is_valid():
		move_tw.kill()
	if s != "attack":
		face_lock = false
		hazard_sweep.active = false
	match s:
		"hover":
			landed = false
			weak.armed = false
			armor.enabled = false
			_play("fly")
		"reload":
			landed = false
			weak.armed = false
			armor.enabled = false
			Sfx.play("roar", -4.0, 1.4)
			_play("dash", 1.2)
		"takeoff":
			landed = false
			weak.armed = false
			armor.enabled = false
			ammo = int(P("ammo"))
			_play("fly")
			Sfx.play("wing")
		"evolve":
			landed = false
			weak.armed = false
			armor.enabled = false
			hazard_impact.active = false
			Sfx.play("shatter")
			Sfx.play("roar", 2.0, 0.6)
			Game.hitstop(0.14)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)

# ------------------------------------------------------------------ per-frame
func _tick(delta: float) -> void:
	match state:
		"hover":
			bob += delta
			_set_alt(46.0 + sin(bob * 2.0) * 4.0)
			body.speed_scale = 1.0 + 0.25 * phase
			var target := home + Vector2(sin(t * 0.8) * 90.0, 0)
			target.y = clampf(player.global_position.y - 70.0, floor_rect.position.y + 30, floor_rect.end.y - 60)
			global_position = global_position.lerp(target, 0.02 + 0.01 * phase)
			_face(player.global_position.x - global_position.x)
			if t > P("gap"):
				start_attack(pick_attack())
		"attack":
			if not face_lock:
				_face(player.global_position.x - global_position.x)
		"reload":
			# touch down, then kneel to refill the quiver: the weak-point window
			if not landed:
				_set_alt(maxf(0.0, altitude - 700.0 * delta))
				if altitude <= 0.0:
					_land()
			else:
				body.position = Vector2(0, GROUND_Y) + Vector2(randf_range(-0.4, 0.4), 0)
				weak.position = _weak_pos()
				weak.armed = true
				armor.enabled = not weak.armed
				_face(player.global_position.x - global_position.x)
				if t > 0.4 + P("reload"):
					set_state("takeoff")
		"takeoff":
			_set_alt(minf(46.0, altitude + 160.0 * delta))
			if altitude >= 46.0:
				set_state("hover")
		"evolve":
			body.position = Vector2(randf_range(-2, 2), GROUND_Y + randf_range(-1, 1))
			if t >= 1.0 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
				_play("kneel")
				flash_sprite(body, 0.5)
				Sfx.play("stun", 0.0, 0.7)
				Sfx.play("crash")
				Game.add_trauma(1.0)
				Fx.debris(zone.entities, global_position, [Color("b0b8c8"), Color("ffe070")], 34)
				RingFx.spawn(zone.entities, global_position, Color("ffe070"), 8, 120, 0.6, 4.0)
				Game.show_banner("THE HUNTER " + ("STORMS" if np == 2 else "RAGES"), "PHASE %d" % np)
				Game.say(PHASE_TIPS[np], 6.0)
			if t >= 2.4:
				set_state("takeoff")

func _land() -> void:
	landed = true
	_set_alt(0.0)
	_play("kneel")
	body.position = Vector2(0, GROUND_Y)
	hazard_impact.active = true
	get_tree().create_timer(0.35).timeout.connect(func(): hazard_impact.active = false)
	Sfx.play("crash")
	Game.hitstop(0.07)
	Game.add_trauma(0.8)
	zone.camera.punch(0.03, 0.3)
	Fx.debris(zone.entities, global_position, [Color("b0b8c8"), Color("5a6078")], 20)
	Fx.dust(zone.entities, global_position, 12)
	RingFx.spawn(zone.entities, global_position, Color(1, 1, 1, 0.7), 6, 58, 0.35, 2.0)
	match phase:
		1: _set_weak(_weak_pos(), 11.0, true, true, true)
		2: _set_weak(_weak_pos(), 11.0, true, true, true)
		3: _set_weak(_weak_pos(), 12.0, false, true, true)
	shadow.modulate.a = 0.0
	Sfx.play("stun")

# ------------------------------------------------------------------ helpers for attacks
## kind: "" = level shot, "_high" = aimed at the sky (rain, storm), "_low" = kneeling shot along the ground
func _draw_bow(dur: float, kind := "") -> void:
	_play("draw" + kind, 0.8 / dur)
	Sfx.play("telegraph", -4.0, 1.5)
	Fx.charge(zone.entities, _muzzle(), Color("f7efdf"), minf(dur, 0.6), 22.0)

func _release(kind := "") -> void:
	_play("release" + kind)
	Sfx.play("orb", -2.0, 1.4)
	Fx.flash(zone.entities, _muzzle(), Color("d8e0ea"), 9.0)
	var tw := create_tween()                                   # recoil: the archer rocks back and settles
	body.scale = Vector2(SCALE * 1.1, SCALE * 0.92)
	tw.tween_property(body, "scale", Vector2(SCALE, SCALE), 0.18)

func _lead(extra := 0.15) -> Vector2:
	return player.global_position + player.velocity * extra + Vector2(0, -6)

# ------------------------------------------------------------------ PHASE 1 - MARKSMAN
func _atk_snipe(g: int) -> void:
	_draw_bow(0.85)
	if not await atk_wait(0.85, g): return
	for k in 2:
		_release()
		var from := _muzzle()
		Atk.shot(zone, from, _lead(0.1 + 0.2 * k) - from, 470.0, ARROW, 3.5, 2.2)
		ammo -= (1 if k == 1 else 0)
		if not await atk_wait(0.38, g): return
	await atk_wait(0.3, g)

func _atk_triple(g: int) -> void:
	_draw_bow(0.7)
	if not await atk_wait(0.7, g): return
	for k in 2:
		_release()
		var from := _muzzle()
		Atk.fan(zone, from, (_lead() - from).angle() + (0.09 if k == 1 else -0.09), 3, 0.36, 250.0, ARROW, 3.5, 3.0)
		if not await atk_wait(0.36, g): return
	ammo -= 1
	await atk_wait(0.3, g)

func _atk_skid(g: int) -> void:
	_draw_bow(0.7, "_low")
	if not await atk_wait(0.7, g): return
	_release("_low")
	var from := _muzzle() + Vector2(0, altitude * 0.4)
	var base := (player.global_position - from).angle()
	for off in [-0.55, 0.0, 0.55]:
		var p := Atk.shot(zone, from, Vector2.from_angle(base + off), 300.0, ARROW, 3.5, 4.5)
		p.bounces_left = 2
	ammo -= 1
	await atk_wait(0.8, g)

func _atk_thief(g: int) -> void:
	var ar := zone.arrow
	if not (ar.state == Arrow.State.GROUND or ar.state == Arrow.State.STUCK) or ar.stolen_by != null:
		await _atk_snipe(g)              # nothing on the floor to steal
		return
	_play("dash_in", 0.58 / 0.7)
	Sfx.play("telegraph", -2.0, 1.5)
	_glide_to(ar.global_position, 0.7, 14.0)
	face_lock = false
	if not await atk_wait(0.75, g): return
	if ar.state == Arrow.State.GROUND or ar.state == Arrow.State.STUCK:
		if ar.state == Arrow.State.STUCK:
			ar._set_state(Arrow.State.GROUND)
		ar.stolen_by = self
		Sfx.play("catch", 0.0, 0.7)
		Game.say("IT STOLE YOUR ARROW - RECALL IT!", 2.0)
	var far := Vector2(floor_rect.get_center().x * 2.0 - player.global_position.x, floor_rect.position.y + 40.0)
	_glide_to(far, 1.1, 46.0)
	_play("fly", 1.4)
	for k in 3:
		if not await atk_wait(1.0, g): break
		if not is_instance_valid(ar) or ar.stolen_by != self:
			break
		_release()
		var from := _muzzle()
		Atk.fan(zone, from, (_lead() - from).angle(), 3, 0.5, 240.0, ARROW, 3.5, 3.0)
	if ar.stolen_by == self:
		ar.stolen_by = null
		ar.vel = Vector2.ZERO
	await atk_wait(0.2, g)

# ------------------------------------------------------------------ PHASE 2 - STORMCALLER
func _atk_arrow_rain(g: int) -> void:
	_draw_bow(0.6, "_high")
	if not await atk_wait(0.6, g): return
	_release("_high")
	Sfx.play("wing", 0.0, 1.3)
	var pl := player
	for i in 10:
		var p: Vector2 = pl.global_position + pl.velocity * 0.6 if i < 2 else pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 105.0)
		Atk.blast(zone, Atk.clamp_in(zone, p), 13.0, 1.0 + 0.09 * i, Color("d8e0ea"), "bosses/arrow_drop.png", "fall", 0.25)
	ammo -= 1
	await atk_wait(1.8, g)

func _atk_trap_arrows(g: int) -> void:
	_draw_bow(0.5, "_low")
	if not await atk_wait(0.5, g): return
	for i in 4:
		_release("_low")
		var p := Atk.clamp_in(zone, player.global_position + Vector2.from_angle(TAU * i / 4.0 + randf() * 0.6) * randf_range(55.0, 100.0))
		Atk.blast(zone, p, 22.0, 1.9 + 0.1 * i, Color("fff0a0"), "bosses/arrow_drop.png", "stuck", 0.35)
		if not await atk_wait(0.22, g): return
	ammo -= 1
	await atk_wait(1.6, g)

func _atk_strafe(g: int) -> void:
	var lane := clampf(player.global_position.y - 30.0, floor_rect.position.y + 30.0, floor_rect.end.y - 40.0)
	var from_left := global_position.x < floor_rect.get_center().x
	var x0 := floor_rect.position.x - 20.0 if from_left else floor_rect.end.x + 20.0
	var x1 := floor_rect.end.x + 20.0 if from_left else floor_rect.position.x - 20.0
	_play("dash_in", 0.58 / 0.8)
	_glide_to(Vector2(x0, lane), 0.8, 20.0)
	face_lock = true
	_face(1.0 if from_left else -1.0)
	if not await atk_wait(0.85, g): return
	_play("dash")
	hazard_sweep.active = true
	if move_tw and move_tw.is_valid():
		move_tw.kill()
	global_position = Vector2(x0, lane)
	move_tw = create_tween()
	move_tw.tween_property(self, "global_position", Vector2(x1, lane), 1.25)
	for i in 8:
		var dir := Vector2((player.global_position.x - global_position.x) * 0.004, 1.0).normalized()
		Atk.shot(zone, global_position + Vector2(0, -8), dir, 215.0, ARROW, 3.5, 3.0)
		Fx.afterimage(zone.entities, body, Color(0.6, 0.9, 0.7, 0.45), 0.3)
		if not await atk_wait(0.155, g): return
	hazard_sweep.active = false
	ammo -= 1
	global_position = Atk.clamp_in(zone, global_position, 30.0)
	await atk_wait(0.3, g)

func _atk_storm_call(g: int) -> void:
	_draw_bow(0.7, "_high")
	Sfx.play("roar", -2.0, 1.2)
	if not await atk_wait(0.7, g): return
	_release("_high")
	var pl := player
	for i in 6:
		var p: Vector2 = pl.global_position + pl.velocity * 0.4 if i == 0 else pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 100.0)
		Atk.blast(zone, Atk.clamp_in(zone, p), 22.0, 0.95 + 0.18 * i, Color("fff0a0"), "bosses/bolt.png", "rise", 0.3)
	ammo -= 1
	await atk_wait(2.0, g)

# ------------------------------------------------------------------ PHASE 3 - TEMPEST
func _atk_cyclone(g: int) -> void:
	_glide_to(Vector2(floor_rect.get_center().x, floor_rect.get_center().y - 20.0), 0.7, 70.0)
	_play("dash", 1.6)
	face_lock = true
	Sfx.play("roar", -2.0, 0.8)
	if not await atk_wait(0.8, g): return
	for i in 22:
		body.flip_h = (i % 2) == 0
		if i % 2 == 0:
			Fx.afterimage(zone.entities, body, Color(0.9, 0.6, 1.0, 0.4), 0.3)
		Atk.ring(zone, global_position + Vector2(0, -altitude * 0.35), 4, 118.0, ARROW, i * 0.32, 3.5, 4.0)
		if i % 3 == 0:
			Sfx.play("wing", -8.0, 1.5)
		if not await atk_wait(0.14, g): return
	ammo -= 1
	await atk_wait(0.5, g)

func _atk_pin_down(g: int) -> void:
	_draw_bow(0.5, "_high")
	if not await atk_wait(0.5, g): return
	_release("_high")
	var c := player.global_position
	for ring_i in 3:
		var rad: float = [95.0, 58.0, 18.0][ring_i]
		var n: int = [9, 6, 1][ring_i]
		for i in n:
			var p := Atk.clamp_in(zone, c + Vector2.from_angle(TAU * i / n + ring_i * 0.4) * rad)
			Atk.blast(zone, p, 14.0, 1.0 + 0.5 * ring_i, Color("d8e0ea"), "bosses/arrow_drop.png", "fall", 0.25)
	ammo -= 1
	await atk_wait(2.4, g)

func _atk_shadow_snipe(g: int) -> void:
	_draw_bow(0.9)
	var ghosts: Array = []
	var pl := player
	for sgn in [-1.0, 1.0]:
		var gp := Atk.clamp_in(zone, pl.global_position + Vector2(sgn * 120.0, randf_range(-40.0, 40.0)), 30.0)
		var gs := Sprite2D.new()
		gs.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
		gs.scale = Vector2(SCALE, SCALE)
		gs.flip_h = gp.x > pl.global_position.x
		gs.modulate = Color(1, 1, 1, 0.5)
		gs.position = gp + Vector2(0, GROUND_Y - 46.0)
		zone.entities.add_child(gs)
		ghosts.append({"s": gs, "p": gp})
		Fx.burst(zone.entities, gp, [Color("ffffff"), Color("a8c890")], 12, 60.0, 0.4, 2.0)
	Sfx.play("wing", 0.0, 1.2)
	if not await atk_wait(0.95, g):
		for gh in ghosts:
			gh["s"].queue_free()
		return
	_release()
	var from := _muzzle()
	Atk.shot(zone, from, _lead(0.1) - from, 460.0, ARROW, 3.5, 2.2)
	for gh in ghosts:
		var gf: Vector2 = gh["p"] + Vector2(0, -20)
		Atk.shot(zone, gf, _lead(0.1) - gf, 460.0, ARROW, 3.5, 2.2)
		Fx.sparks(zone.entities, gf, 6)
		gh["s"].queue_free()
	ammo -= 1
	await atk_wait(0.8, g)

func _atk_wind_volley(g: int) -> void:
	_draw_bow(0.6)
	if not await atk_wait(0.6, g): return
	_release()
	var from := _muzzle()
	var base := (_lead() - from).angle()
	for k in 7:
		var a := base + lerpf(-1.1, 1.1, k / 6.0)
		Atk.homing(zone, from, Vector2.from_angle(a), 125.0, ARROW, 1.5, player, 3.5, 5.0)
	ammo -= 1
	await atk_wait(1.4, g)

# ------------------------------------------------------------------ hits
func _on_weak_struck(_kind: String) -> void:
	if phase < 3:
		phase_pending = phase + 1
		set_state("evolve")
	else:
		kill()

func _on_armor_clank(_pos: Vector2, _kind: String) -> void:
	flash_sprite(body, 0.08)

func _death_sequence() -> void:
	_death_by_animation(body, "death", [Color("b0b8c8"), Color("5d9b79")])
