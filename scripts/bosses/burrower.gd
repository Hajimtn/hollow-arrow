extends BossBase
## THE EXECUTIONER (Undead Executioner art) - the ghost judge of the candlelit crypt. It glides under the floor as a violet shade and
## surfaces to pass sentence. It is a GHOST: every arrow passes straight through it - the ember eyes under the hood are only
## vulnerable to a BLESSED arrow, one that has flown through the glow of a lit lantern (see Lair, "burrow"), and only on the
## frames where it stands with the scythe raised (the "summon" pose, frames >= 1). Ghosts are drawn to light: it erupts out of a lit
## lantern, and that is the window. Twelve attacks, none reused in another form.
##   Phase 1  EXECUTIONER  condemned (a chained ring locks onto you, the scythe falls), scythe sweep, and RING ERUPT: it rises out
##                         of a lit lantern (snuffing it) and raises the scythe - eyes open, blessed arrows only.
##   Phase 2  BRISTLING    wisp swarm, shadow step (dissolves, reappears behind you), spike lanes, and CREST ERUPT: it surfaces
##                         and raises the scythe briefly - eyes open.
##   Phase 3  DEVOURER     grave hands, soul harvest (a vortex with orbiting blades), cage drop, and DECOY ERUPTIONS: three
##                         eruptions, two false; the real one out of a lit lantern opens the eyes: blessed AND recalled arrows only.

const PHASES := {
	1: {"swim": 96.0, "cd": 1.1, "burst": 30.0, "body": 15.0},
	2: {"swim": 126.0, "cd": 0.8, "burst": 34.0, "body": 18.0},
	3: {"swim": 150.0, "cd": 0.55, "burst": 36.0, "body": 20.0},
}
const ATTACKS := {
	1: ["condemned", "scythe_sweep", "ring_erupt"],
	2: ["wisp_swarm", "shadow_step", "spike_lanes", "crest_erupt"],
	3: ["grave_hands", "soul_harvest", "cage_drop", "decoy_erupts"],
}
const PHASE_TIPS := {
	2: "IT RAISES THE SCYTHE BRIEFLY AFTER A CREST ERUPTION. SHOOT THE EYES UNDER THE HOOD - AND WATCH THE SHADOW STEP.",
	3: "DECOY ERUPTIONS! IF IT CLAIMS THE ARROW, RECALL IT THROUGH THE EYES.",
}

const SHEET := "bosses/reaper.png"     # 100x100 cells, 10 columns; rows are listed in tools/gen_boss_pack.py
const ANIMS := {
	"idle": {"frames": [0, 1, 2, 3], "fps": 5},
	"skill": {"frames": [60, 61, 62, 63, 64, 65, 70, 71, 72, 73, 74, 75], "fps": 16, "loop": false},   # scythe up, ring of spikes
	"attack": {"frames": [30, 31, 32, 33, 34, 35, 40, 41, 42, 43, 44, 45], "fps": 14, "loop": false},  # scythe raised, big arc, follow-through
	"summon": {"frames": [81, 82, 83, 82, 90, 83], "fps": 5},        # scythe held high: eyes exposed from frame 1
	"dissolve": {"frames": [100, 101, 102, 103, 104, 105], "fps": 27, "loop": false},
	"death": {"frames": [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117], "fps": 12, "loop": false},
}
const HEAD_POS := Vector2(0, -20)
const EYE := Vector2(-2, -16)          # measured on the sheet: cell (48,34) relative to the cell centre
const RIM := {1: Color("c3bfad"), 2: Color("db4f3a"), 3: Color("ef8d35")}
const FORM_SCALE := {1: 1.0, 2: 1.0, 3: 1.2}
const SHADOW := Color("c3bfad")

var phase := 1
var mound: AnimatedSprite2D
var head: AnimatedSprite2D
var hazard_burst: Hazard
var hazard_body: Hazard
var hazard_arc: Hazard
var weak: WeakPoint
var weak_shape: CircleShape2D
var armor: Armor
var burst_shape: CircleShape2D
var body_shape: CircleShape2D
var target := Vector2.ZERO
var trail_t := 0.0
var rumble_t := 0.0
var ate_arrow := false            # true when the eruption happened in lantern light (the window)
var pass_fx_t := 0.0
var dive_cd := 0.0
var facing := 1.0
var floor_rect := Rect2()
var phase_pending := 0
var weak_window := false
var surfaced := false
var pull := false
var orbit_blades: Array = []
var orbit_ang := 0.0
var move_tw: Tween

func attack_list() -> Array:
	return ATTACKS[phase]

func all_attacks() -> Dictionary:
	return ATTACKS

func P(key: String) -> float:
	return PHASES[phase][key]

func _build() -> void:
	mound = Gfx.strip("bosses/shade_pool.png", 40, 3, 8.0, false)
	mound.visible = false
	mound.z_index = -1
	add_child(mound)
	head = AnimatedSprite2D.new()
	head.sprite_frames = Gfx.sheet_frames(SHEET, 100, 100, ANIMS)
	head.position = HEAD_POS
	head.material = ShaderMaterial.new()
	head.material.shader = load("res://shaders/rim.gdshader")
	add_child(head)
	sprites.append(head)
	head.animation_finished.connect(_on_anim_done)
	head.play("idle")
	head.visible = false
	hazard_burst = add_hazard_circle(30.0, Vector2.ZERO, false)
	burst_shape = hazard_burst.shape_node.shape
	hazard_body = add_hazard_circle(15.0, Vector2.ZERO, false)
	body_shape = hazard_body.shape_node.shape
	hazard_arc = add_hazard_circle(38.0, Vector2(0, -6), false)      # the scythe's sweep
	weak = add_weak(12.0, HEAD_POS + EYE)
	weak.needs_blessed = true                       # a ghost: unblessed arrows pass through
	weak_shape = weak.get_child(0).shape
	weak.glow.scale = Vector2(0.55, 0.55)
	weak.glow.modulate = Color(1.3, 0.8, 0.6)
	armor = add_armor_circle(24.0, Vector2.ZERO, Armor.Mode.DROP, Armor.Mode.DROP)
	armor.enabled = false
	for i in 3:                                                      # phase-3 orbiting blades
		var h := Hazard.circle(9.0)
		add_child(h)
		h.active = false
		orbit_blades.append(h)
	floor_rect = Rect2(zone.cell_center(2, 3), Vector2((zone.w - 5) * 16, (zone.h - 6) * 16))

func _on_start() -> void:
	mound.visible = true
	position = zone.mark("B") + Vector2(0, 10)
	_apply_phase(1)
	set_state("swim")

func _apply_phase(p: int) -> void:
	phase = p
	zone.on_phase(p)
	burst_shape.radius = P("burst")
	body_shape.radius = P("body")
	mound.scale = Vector2.ONE * (1.0 + 0.2 * (p - 1))
	(head.material as ShaderMaterial).set_shader_parameter("rim_color", RIM[p])
	head.scale = Vector2.ONE * FORM_SCALE[p]
	head.play("idle")
	weak_window = false
	surfaced = false
	reset_attacks()

func _play(anim: String, speed := 1.0) -> void:
	head.speed_scale = speed
	if head.animation != anim or not head.is_playing():
		head.play(anim)

func _on_anim_done() -> void:
	if state == "attack" and surfaced and not weak_window and head.animation in ["skill", "attack"]:
		_play("idle")

## The eyes only count on the frames where the reaper stands with its scythe raised and the hood tilted up.
func _eyes_open() -> bool:
	return head.animation == "summon" and head.frame >= 1

func _eye_pos() -> Vector2:
	var e: Vector2 = HEAD_POS + EYE * float(FORM_SCALE[phase])
	e.x *= -facing if facing != 0.0 else 1.0
	return e

func _set_weak(pos: Vector2, r: float, fly: bool, ret: bool, armed: bool) -> void:
	weak.position = pos
	weak_shape.radius = r
	weak.accept_fly = fly
	weak.accept_ret = ret
	weak.armed = armed

func _clamp_floor(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, floor_rect.position.x, floor_rect.end.x), clampf(p.y, floor_rect.position.y, floor_rect.end.y))

func _pick_target() -> Vector2:
	var lit := _light_target()
	if lit != Vector2.ZERO:
		return lit
	return _clamp_floor(player.global_position + player.velocity * 0.25)

## the nearest lit lantern (ghosts are drawn to light), or Vector2.ZERO when the crypt is dark
func _light_target() -> Vector2:
	if zone.lair == null:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var bd := 99999.0
	for p in zone.lair.lit_positions():
		var d: float = p.distance_to(global_position)
		if d < bd:
			bd = d
			best = p + Vector2(34.0 * (1.0 if p.x < zone.w * 8.0 else -1.0), 8.0)      # beside the lantern (towards the room), so its post never blocks the eyes
	return best

func _attack_done(_attack_name: String) -> void:
	set_state("swim")

# ------------------------------------------------------------------ state entry
func _enter(s: String) -> void:
	if s != "attack":
		weak_window = false
		pull = false
		hazard_arc.active = false
		for b in orbit_blades:
			b.active = false
		if move_tw and move_tw.is_valid():
			move_tw.kill()
	match s:
		"swim":
			mound.visible = true
			head.visible = false
			surfaced = false
			hazard_body.active = false
			hazard_burst.active = false
			weak.armed = false
			armor.enabled = false
			dive_cd = P("cd")
		"evolve":
			hazard_body.active = false
			hazard_burst.active = false
			weak.armed = false
			armor.enabled = false     # the arrow that just struck is still passing through; nothing can hurt it now anyway
			Sfx.play("shatter")
			Sfx.play("roar", 2.0, 0.6)
			Game.hitstop(0.14)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)

# ------------------------------------------------------------------ surfacing helpers
## The reaper climbs out of the sand at its current position.
func _surface(spikes := true) -> void:
	surfaced = true
	mound.visible = false
	facing = signf(player.global_position.x - global_position.x)
	if facing == 0.0:
		facing = 1.0
	ate_arrow = zone.lair != null and zone.lair.in_light(global_position)
	if ate_arrow:
		for e in zone.lair.lanterns:
			if e["t"] > 0.0 and (e["holder"].global_position as Vector2).distance_to(global_position) < Lair.POOL_R:
				zone.lair._snuff(e)                   # it feeds on the flame
	head.visible = true
	head.flip_h = facing < 0.0             # the sheet holds the scythe on the right
	head.position = HEAD_POS
	head.scale = Vector2.ONE * 0.3
	if spikes:
		_play("skill")                      # the ring of spikes IS the eruption burst
		hazard_burst.active = true
		get_tree().create_timer(0.32).timeout.connect(func(): hazard_burst.active = false)
	create_tween().tween_property(head, "scale", Vector2.ONE * FORM_SCALE[phase], 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hazard_body.active = true
	Sfx.play("erupt")
	Game.hitstop(0.05)
	Game.add_trauma(0.7)
	Fx.debris(zone.entities, global_position, [Color("8a80c0"), Color("2a2034")], 24)
	Fx.dust(zone.entities, global_position, 12)
	RingFx.spawn(zone.entities, global_position, Color(1, 0.9, 0.7, 0.8), 6, 46, 0.35, 2.0)
	var cr := Gfx.sprite("bosses/crack.png", global_position)
	zone.floor_decor.add_child(cr)
	cr.global_position = global_position
	create_tween().tween_property(cr, "modulate:a", 0.0, 5.0)
	cr.z_index = -4

func _submerge() -> void:
	weak_window = false
	weak.armed = false
	armor.enabled = false
	hazard_body.active = false
	_play("dissolve")
	Sfx.play("thud")
	Fx.dust(zone.entities, global_position, 10)

func _sink(g: int) -> bool:
	_submerge()
	if not await atk_wait(0.24, g):
		return false
	head.visible = false
	surfaced = false
	mound.visible = true
	return true

## swim under the sand to a point (mound moves, hazards off)
func _burrow_to(pos: Vector2, dur: float) -> void:
	mound.visible = true
	head.visible = false
	surfaced = false
	hazard_body.active = false
	if move_tw and move_tw.is_valid():
		move_tw.kill()
	move_tw = create_tween()
	move_tw.tween_property(self, "global_position", _clamp_floor(pos), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sfx.play("rumble", 0.0, 0.9)

func _open_eyes(fly: bool, ret: bool, r: float, secs: float, g: int) -> bool:
	_set_weak(_eye_pos(), r, fly, ret, false)
	_play("summon")
	weak_window = true
	Sfx.play("stun")
	var ok := await atk_wait(secs, g)
	weak_window = false
	weak.armed = false
	return ok

func _lead(extra := 0.35) -> Vector2:
	return _clamp_floor(player.global_position + player.velocity * extra)

# ------------------------------------------------------------------ per-frame
## an unblessed arrow through the ghost: a faint shimmer and, at the eyes, a hint on how to hurt it
func _tick_ghost_fx(delta: float) -> void:
	pass_fx_t = maxf(0.0, pass_fx_t - delta)
	var ar := arrow
	if ar.state == Arrow.State.HELD or ar.blessed_t > 0.0:
		return
	if ar.global_position.distance_to(global_position + Vector2(0, -16)) < 22.0 and pass_fx_t <= 0.0:
		pass_fx_t = 0.4
		Fx.burst(zone.entities, ar.global_position, [Color("a8a0c8"), Color("4a4266")], 6, 30.0, 0.4, 2.0)
		Sfx.play("arrow_wall", -14.0, 1.6)
		if weak.armed and ar.global_position.distance_to(global_position + weak.position) < 16.0:
			Game.say("THE ARROW PASSES THROUGH THE GHOST. LET IT FLY THROUGH LANTERN LIGHT FIRST!", 3.0)

func _tick(delta: float) -> void:
	if surfaced:
		weak.position = _eye_pos()
		weak.armed = weak_window and _eyes_open()
		armor.enabled = false                       # a ghost has no body for an arrow to hit
		_tick_ghost_fx(delta)
	match state:
		"swim":
			dive_cd = maxf(0.0, dive_cd - delta)
			target = _pick_target()
			var d := target - global_position
			var dist := d.length()
			var step := minf(dist, P("swim") * delta)
			if dist > 1.0:
				global_position += d / dist * step
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.07
				Fx.burst(zone.entities, global_position + Vector2(0, 6), [Color("8a80c0"), Color("2a2034")], 3, 30.0, 0.5, 2.0, 30.0, Vector2.UP, 60.0)
			rumble_t -= delta
			if rumble_t <= 0.0:
				rumble_t = 0.75
				var loud: float = clampf(1.0 - player_dist() / 260.0, 0.0, 1.0)
				Sfx.play("rumble", -14.0 + loud * 12.0, 1.0)
				Game.add_trauma(0.05 + loud * 0.08)
			mound.position = Vector2(0, sin(t * 14.0) * 0.6)
			if dive_cd <= 0.0:
				start_attack(pick_attack())
		"attack":
			if pull:
				var to_me := (global_position - player.global_position).normalized()
				player.move_and_collide(to_me * 54.0 * delta)
			if not orbit_blades.is_empty() and orbit_blades[0].active:
				orbit_ang += delta * 3.4
				for i in 3:
					orbit_blades[i].position = Vector2.from_angle(orbit_ang + TAU * i / 3.0) * 46.0 + Vector2(0, -10)
		"evolve":
			head.position = HEAD_POS + Vector2(randf_range(-2, 2), randf_range(-2, 2))
			if t >= 1.0 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
				flash_sprite(head, 0.5)
				Sfx.play("stun", 0.0, 0.7)
				Sfx.play("crash")
				Game.add_trauma(1.0)
				Fx.debris(zone.entities, global_position, [Color("a58060"), Color("ff9a30")], 34)
				RingFx.spawn(zone.entities, global_position, Color("ffb040"), 8, 120, 0.6, 4.0)
				Game.show_banner("THE EXECUTIONER " + ("BRISTLES" if np == 2 else "HUNGERS"), "PHASE %d" % np)
				Game.say(PHASE_TIPS[np], 6.0)
			if t >= 2.4:
				set_state("swim")

# ------------------------------------------------------------------ PHASE 1 - EXECUTIONER
## A chained ring locks onto the player for a second, then the scythe falls on that spot.
func _cast_up(g: int, secs: float) -> bool:
	## it rises out of the floor, lifts the scythe (the "summon" pose) and channels; the caller then sinks again
	_surface(false)
	_play("summon")
	Fx.charge(zone.entities, global_position + Vector2(0, -50), Color("c3bfad"), 0.6, 36.0)
	return await atk_wait(secs, g)

func _atk_condemned(g: int) -> void:
	Sfx.play("telegraph", -2.0, 0.7)
	_surface(false)
	_play("summon")
	var w := WarnFx.circle(zone.floor_decor, player.global_position, 28.0, 1.0, Color("c3bfad"))
	w.follow = player
	w.freeze_at = 0.75
	Fx.charge(zone.entities, global_position + Vector2(0, -50), Color("c3bfad"), 0.9, 40.0)
	if not await atk_wait(1.0, g): return
	var p := _clamp_floor(player.global_position)
	Atk.blast(zone, p, 28.0, 0.75, SHADOW, "bosses/scythe_drop.png", "fall", 0.4)
	_play("attack", 1.2)                                      # it brings the scythe down as the blade falls
	if not await atk_wait(1.3, g): return
	await _sink(g)

func _atk_scythe_sweep(g: int) -> void:
	_burrow_to(_lead(0.3) + Vector2.from_angle(randf() * TAU) * 30.0, 0.7)
	if not await atk_wait(0.85, g): return
	_surface(false)
	_play("attack")
	hazard_arc.position = Vector2(0, -6)
	if not await atk_wait(0.3, g): return          # the scythe rises (frames 0-3)
	hazard_arc.active = true
	Sfx.play("charge", 0.0, 1.3)
	if not await atk_wait(0.3, g): return
	hazard_arc.active = false
	if not await atk_wait(0.4, g): return
	await _sink(g)

func _atk_ring_erupt(g: int) -> void:
	# ghosts are drawn to light: it glides to the nearest lit lantern and rises out of it
	_burrow_to(_pick_target(), 0.6)
	Sfx.play("rumble", 2.0, 0.8)
	Game.add_trauma(0.25)
	WarnFx.circle(zone.floor_decor, _pick_target(), P("burst") + 4.0, 0.9, Color(1.0, 0.5, 0.2))
	if not await atk_wait(0.9, g): return
	_surface(true)
	if not await atk_wait(0.4, g): return
	if ate_arrow:
		if not await _open_eyes(true, true, 12.0, 2.8, g): return
	else:
		if not await atk_wait(1.15, g): return
	await _sink(g)

# ------------------------------------------------------------------ PHASE 2 - BRISTLING
func _atk_wisp_swarm(g: int) -> void:
	_burrow_to(_lead(0.3), 0.5)
	if not await atk_wait(0.6, g): return
	_surface(false)
	_play("summon")
	Sfx.play("roar", -2.0, 1.3)
	if not await atk_wait(0.5, g): return
	for i in 5:
		var a := TAU * i / 5.0 + randf() * 0.4
		var w := Atk.homing(zone, global_position + Vector2(0, -20), Vector2.from_angle(a), 62.0, "bosses/wisp.png", 1.1, player, 6.0, 7.0)
		w.add_to_group("wisp")                          # wisps that touch a lit lantern snuff it
	Sfx.play("orb", -2.0, 0.8)
	if not await atk_wait(0.8, g): return
	await _sink(g)

func _atk_shadow_step(g: int) -> void:
	_burrow_to(player.global_position + Vector2(90.0 * (1.0 if randf() < 0.5 else -1.0), 0.0), 0.5)
	if not await atk_wait(0.55, g): return
	_surface(false)
	if not await atk_wait(0.2, g): return
	if not await _sink(g): return
	# it tunnels behind the player and strikes from there
	var behind := player.global_position - player.velocity.normalized() * 34.0 if player.velocity.length() > 20.0 else player.global_position + Vector2(-34.0 * facing, 8.0)
	_burrow_to(behind, 0.7)
	Sfx.play("rumble", 4.0, 1.1)
	if not await atk_wait(0.8, g): return
	_surface(false)
	_play("attack", 1.6)
	hazard_arc.active = true
	if not await atk_wait(0.36, g): return
	hazard_arc.active = false
	if not await atk_wait(0.3, g): return
	await _sink(g)

func _atk_spike_lanes(g: int) -> void:
	_burrow_to(_lead(0.3), 0.5)
	if not await atk_wait(0.6, g): return
	_surface(true)
	Sfx.play("telegraph", -6.0, 1.4)
	var origin := global_position
	var off := randf() * TAU
	for wave in 2:
		var segs := []
		for i in 8:
			var d := Vector2.from_angle(off + wave * PI / 8.0 + TAU * i / 8.0)
			WarnFx.lane(zone.floor_decor, origin, origin + d * 118.0, 12.0, 0.6, Color(0.9, 0.55, 0.25))
			segs.append([origin, origin + d * 118.0])
		if not await atk_wait(0.6, g): return
		BeamShot.fire(zone.entities, segs, 9.0, 0.3, Color(0.85, 0.65, 0.4))
		Sfx.play("thud", 0.0, 1.4)
		Game.add_trauma(0.3)
	if not await atk_wait(0.3, g): return
	await _sink(g)

func _atk_crest_erupt(g: int) -> void:
	_burrow_to(_lead(0.3), 0.55)
	Sfx.play("rumble", 2.0, 0.9)
	if not await atk_wait(0.7, g): return
	_surface(true)
	if not await atk_wait(0.4, g): return
	if not await _open_eyes(true, true, 11.0, 1.6, g): return
	await _sink(g)

# ------------------------------------------------------------------ PHASE 3 - DEVOURER
func _atk_grave_hands(g: int) -> void:
	Sfx.play("roar", -2.0, 0.6)
	Game.add_trauma(0.4)
	_surface(false)
	_play("skill", 0.9)                                       # arms wide, the dead answer
	var c := player.global_position
	for ring_i in 3:
		var rad := 38.0 + ring_i * 42.0
		var n := 7 + ring_i * 2
		for i in n:
			var p := Atk.clamp_in(zone, c + Vector2.from_angle(TAU * i / n + ring_i * 0.5) * rad)
			Atk.blast(zone, p, 14.0, 1.0 + 0.5 * ring_i, Color("d8ccb0"), "bosses/bone_hand.png", "rise", 0.5)
	if not await atk_wait(2.9, g): return
	await _sink(g)

func _atk_soul_harvest(g: int) -> void:
	_burrow_to(Vector2(floor_rect.get_center().x, floor_rect.get_center().y), 0.7)
	if not await atk_wait(0.8, g): return
	_surface(false)
	_play("summon")
	Sfx.play("roar", 0.0, 0.5)
	pull = true
	for b in orbit_blades:
		b.active = true
	if not await atk_wait(3.4, g): return
	pull = false
	for b in orbit_blades:
		b.active = false
	await _sink(g)

func _atk_cage_drop(g: int) -> void:
	Sfx.play("telegraph", -2.0, 0.6)
	Game.add_trauma(0.4)
	_surface(false)
	_play("summon")
	Fx.charge(zone.entities, global_position + Vector2(0, -50), Color("6a6270"), 0.7, 36.0)
	for i in 9:
		var p: Vector2 = _lead(0.5) if i < 2 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 115.0))
		Atk.blast(zone, p, 16.0, 1.0 + 0.11 * i, Color("6a6270"), "environment/hang_cage.png", "fall", 0.35)
	if not await atk_wait(2.4, g): return
	await _sink(g)

func _atk_decoy_erupts(g: int) -> void:
	_burrow_to(_pick_target(), 0.5)
	Sfx.play("rumble", 4.0, 0.7)
	Game.add_trauma(0.3)
	WarnFx.circle(zone.floor_decor, _pick_target(), P("burst") + 4.0, 1.5, Color(1.0, 0.5, 0.2))
	for k in 2:
		var p := _clamp_floor(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(35.0, 75.0))
		Atk.blast(zone, p, 34.0, 0.55 + 0.15 * k, Color(1.0, 0.5, 0.2), "bosses/bone_hand.png", "rise", 0.35)
	if not await atk_wait(1.5, g): return
	_surface(true)
	if not await atk_wait(0.4, g): return
	if ate_arrow:
		if not await _open_eyes(false, true, 14.0, 1.5, g): return
	else:
		if not await atk_wait(1.0, g): return
	await _sink(g)

# ------------------------------------------------------------------ hits
func _on_weak_struck(_kind: String) -> void:
	if phase < 3:
		phase_pending = phase + 1
		set_state("evolve")
	else:
		kill()

func _on_armor_clank(_pos: Vector2, _kind: String) -> void:
	flash_sprite(head, 0.1)

func _death_sequence() -> void:
	head.scale = Vector2.ONE * FORM_SCALE[phase]
	_death_by_animation(head, "death", [Color("c3bfad"), Color("242020")])
