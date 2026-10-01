extends BossBase
## CHAINED COLOSSUS (Demon Slime art) - the master of the foundry. Three forms, eleven attacks, none reused in another form.
##   Phase 1  CHAINED    cleaver slam, chain lash, eruption.  Cut the three pylon chains with the arrow; the demon doubles over
##                       (hurt animation) and its glowing FACE is the target before the chains re-forge.
##   Phase 2  UNCHAINED  orb barrage (the horn flames detach and fly - the weak points fly with them), cleaver boomerang, leap
##                       slam, fire wave.  The two horn FLAME ORBS are the weak points: hit both within a few seconds.
##   Phase 3  BURNING    meteor rain, flame charge, immolation, hellfire spiral.  The pylons rise again; only a RECALLED arrow cuts
##                       their chains, and the flaming crown answers only to a RECALLED arrow.
## The slams and lashes are the demon's own cleaver, thrown as spectral blades (cleaver_up / cleaver_down sprites).

const SWEEP_LEN := 190.0
const PHASES := {
	1: {"gap": 0.6, "expose": 7.5},
	2: {"gap": 0.4, "expose": 5.5},
	3: {"gap": 0.25, "expose": 5.0},
}
const ATTACKS := {
	1: ["cleaver_slam", "chain_lash", "eruption"],
	2: ["orb_barrage", "cleaver_boomerang", "leap_slam", "fire_wave"],
	3: ["meteor_rain", "flame_charge", "immolation", "hellfire_spiral"],
}
const FIRE := Color("ef6a2a")
const PHASE_TIPS := {
	2: "THE CHAINS SNAPPED! STRIKE BOTH HORN FLAMES BEFORE THEY RESEAL - THEY FLY WHEN IT SHOOTS.",
	3: "THE PYLONS RISE AGAIN. ONLY A RECALLED ARROW CAN CUT THEIR CHAINS - AND STRIKE THE FLAMING CROWN.",
}

const SHEET := "bosses/demon.png"          # 170x130 cells, 22 columns: row 0 idle, 1 walk, 2 cleave, 3 hurt, 4 death
const ANIMS := {
	"idle": {"frames": [0, 1, 2, 3, 4, 5], "fps": 6},
	"cl_wind": {"frames": [44, 45, 46, 47, 48, 49, 50, 51, 52], "fps": 9, "loop": false},      # cleave frames 0-8: cleaver raised
	"cl_chop": {"frames": [53, 54, 55, 56, 57, 58], "fps": 14, "loop": false},                  # cleave frames 9-14: the chop
	"walk": {"frames": [22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33], "fps": 16},
	"hurt": {"frames": [66, 67, 68, 69, 70], "fps": 8},
	"ignite": {"frames": [90, 91, 92, 93], "fps": 8, "loop": false},                            # death frames 2-5: catches fire
	"burn": {"frames": [93, 94, 95, 94], "fps": 8},                                             # death frames 5-7: engulfed, arms up
	"death": {"frames": [96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109], "fps": 9, "loop": false},
}
const BASE := Vector2(-1, -11)           # puts the demon's body centre on the boss origin
const FACE := Vector2(-11, 6)            # glowing face, cell-relative (sheet faces LEFT)
const CROWN := Vector2(-8, -20)          # crown of flames in the burning pose
const TINT := {1: Color(1, 1, 1), 2: Color(1.25, 0.85, 0.85), 3: Color(1, 1, 1)}

var phase := 1
var flipped := false
var body: AnimatedSprite2D
var body_hazard: Hazard
var armor: Armor
var core: WeakPoint
var core_shape: CircleShape2D
var gems: Array = []
var gem_hit := [false, false]
var gem_timer := 0.0
var gem_marks: Array = []
var fists: Array = []
var pylons: Array = []
var broken := 0
var next_fist := 0
var sweeps: Array = []         # {pivot, hazard, from, to}
var sweep_t := -1.0
var sweep_dur := 1.4
var sweep_count := 1
var breath := 0.0
var phase_pending := 0
var orbs_out := false
var orb_sprites: Array = []
var orb_ang := 0.0
var home_pos := Vector2.ZERO
var move_tw: Tween
var breath_fx: AnimatedSprite2D          # the fire breath cone (drawn for this game: tools/gen_drawn.py)

func attack_list() -> Array:
	return ATTACKS[phase]

func all_attacks() -> Dictionary:
	return ATTACKS

func P(key: String) -> float:
	return PHASES[phase][key]

func _build() -> void:
	position.y += 30.0          # the demon is taller than the old sprite: keep its horns inside the arena
	home_pos = position
	body = AnimatedSprite2D.new()
	body.sprite_frames = Gfx.sheet_frames(SHEET, 170, 130, ANIMS)
	body.position = BASE
	add_child(body)
	sprites.append(body)
	body.animation_finished.connect(_on_anim_done)
	body.play("idle")
	breath_fx = AnimatedSprite2D.new()
	var bf := SpriteFrames.new()
	bf.remove_animation("default")
	bf.add_animation("breath")
	bf.set_animation_speed("breath", 14.0)
	bf.set_animation_loop("breath", true)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = Gfx.tex("bosses/fire_breath.png")
		at.region = Rect2(i * 64, 0, 64, 40)
		bf.add_frame("breath", at)
	breath_fx.sprite_frames = bf
	breath_fx.centered = false
	breath_fx.offset = Vector2(0, -20)
	breath_fx.z_index = 4
	breath_fx.scale = Vector2(2.4, 2.4)
	breath_fx.visible = false
	add_child(breath_fx)
	body_hazard = add_hazard_circle(34.0, Vector2(0, 10))
	armor = add_armor_circle(30.0, Vector2(0, 16))
	core = add_weak(13.0, FACE + BASE)
	core_shape = core.get_child(0).shape
	core.glow.scale = Vector2(0.6, 0.6)
	for i in 2:
		var g := WeakPoint.make(9.0, Vector2(-33 if i == 0 else 11, -22))
		g.glow.scale = Vector2(0.55, 0.55)
		g.glow.modulate = Color(1.4, 1.0, 0.5)
		add_child(g)
		g.struck.connect(_on_gem.bind(i))
		gems.append(g)
	for i in 2:                 # the horn flames when they leave the horns
		var o := Gfx.sprite("bosses/orb_fire.png")
		o.scale = Vector2(1.5, 1.5)
		o.visible = false
		o.z_index = 5
		add_child(o)
		orb_sprites.append(o)
	for side in [-1, 1]:
		var n := Node2D.new()
		n.position = Vector2(66 * side, 50)
		add_child(n)
		var spr := Gfx.sprite("bosses/cleaver_up.png")
		n.add_child(spr)
		sprites.append(spr)
		var hz := Hazard.circle(24.0)
		n.add_child(hz)
		hz.active = false
		fists.append({"node": n, "spr": spr, "haz": hz, "home": n.position})
	for i in 2:
		var pv := Node2D.new()
		pv.position = Vector2(0, 30)
		pv.visible = false
		add_child(pv)
		var arm := Line2D.new()
		arm.width = 9.0
		arm.default_color = Color("6a606c")
		arm.add_point(Vector2.ZERO)
		arm.add_point(Vector2(SWEEP_LEN, 0))
		pv.add_child(arm)
		pv.add_child(Gfx.sprite("bosses/cleaver_down.png", Vector2(SWEEP_LEN - 8, 0)))
		var hz2 := Hazard.box(Vector2(SWEEP_LEN, 15), Vector2(SWEEP_LEN / 2.0, 0))
		pv.add_child(hz2)
		hz2.active = false
		sweeps.append({"pivot": pv, "hazard": hz2, "from": 0.0, "to": 0.0})
	_build_pylons()

func _build_pylons() -> void:
	var anchors := [Vector2(-52, -6), Vector2(52, -6), Vector2(0, 46)]
	var keys := ["a", "b", "c"]
	for i in 3:
		var base := zone.mark(keys[i]) + Vector2(0, 8)
		var holder := Node2D.new()
		holder.position = base
		zone.entities.add_child(holder)
		zone._foot(holder, 18.0, 8.0)
		var foot: StaticBody2D = holder.get_child(holder.get_child_count() - 1)
		var sw := RuneSwitch.make(9.0, "environment/pylon_iron_off.png", "environment/pylon_iron_on.png")
		sw.sprite.position = Vector2(0, 30)
		sw.position = Vector2(0, -30)
		holder.add_child(sw)
		sw.struck.connect(_on_pylon_struck)
		var ch := ChainFx.new()
		zone.floor_decor.add_child(ch)
		ch.a = global_position + anchors[i]
		ch.b = base + Vector2(0, -30)
		ch.slack = 6.0
		pylons.append({"sw": sw, "chain": ch, "holder": holder, "foot": foot})

func _pylons_active(on: bool, fx := true) -> void:
	for p in pylons:
		p["holder"].visible = on
		p["chain"].visible = on
		p["sw"].enabled = on
		p["sw"].set_on(false)
		p["foot"].collision_layer = L.WORLD if on else 0
		if fx:
			Fx.dust(zone.entities, p["holder"].global_position, 10)
			Fx.debris(zone.entities, p["holder"].global_position + Vector2(0, -20), [Color("7a7a88"), Color("3a3a48")], 10)

func _on_start() -> void:
	_apply_phase(1)
	set_state("intro")

func _play(anim: String, speed := 1.0) -> void:
	body.speed_scale = speed
	if body.animation != anim or not body.is_playing():
		body.play(anim)

func _idle_anim() -> String:
	return "burn" if phase == 3 else "idle"

func _on_anim_done() -> void:
	if body.animation == "cl_chop" or body.animation == "cl_wind" and state == "gap":
		_play(_idle_anim())
	elif body.animation == "ignite":
		_play("burn")

func _face_player() -> void:
	flipped = player.global_position.x > global_position.x     # the sheet faces left
	body.flip_h = flipped

## Where the two horn flame orbs are on the current frame (relative to the boss origin).
func _orb_offsets() -> Array:
	var pair: Array = BossAnchors.DEMON_ORBS_IDLE[0]
	match body.animation:
		"idle":
			pair = BossAnchors.DEMON_ORBS_IDLE[clampi(body.frame, 0, 5)]
		"cl_wind":
			pair = BossAnchors.DEMON_ORBS_CLEAVE[clampi(body.frame, 0, 8)]
		"cl_chop":
			pair = BossAnchors.DEMON_ORBS_CLEAVE[9 + clampi(body.frame, 0, 5)]
	var out := []
	for v in pair:
		var p: Vector2 = v + BASE
		if flipped:
			p.x = -p.x
		out.append(p)
	return out

func _core_offset() -> Vector2:
	var v := (CROWN if phase == 3 else FACE) + BASE
	if flipped:
		v.x = -v.x
	return v

func _apply_phase(p: int) -> void:
	phase = p
	zone.on_phase(p)
	body.self_modulate = TINT[p]
	_play(_idle_anim())
	reset_attacks()
	orbs_out = false
	sweep_t = -1.0
	if p == 3:
		global_position = home_pos          # the leaps of phase 2 moved it: back to the chains
	broken = 0
	core.armed = false
	armor.enabled = true
	body_hazard.active = true
	gem_hit = [false, false]
	for g in gems:
		g.armed = (p == 2)
	if p == 3:
		core.accept_fly = false
		core.accept_ret = true
		_pylons_active(true)
		for pl in pylons:
			pl["sw"].accept_fly = false
			pl["sw"].sprite.modulate = Color(1.0, 0.85, 0.7)
	elif p == 2:
		_pylons_active(false)

func _dormant(delta: float) -> void:
	breath += delta
	body.position.y = BASE.y + sin(breath * 1.5) * 1.2
	_face_player()

func _on_start_dummy() -> void:
	pass

# ------------------------------------------------------------------ state entry
func _enter(s: String) -> void:
	if s != "attack":
		sweep_t = -1.0
		breath_fx.visible = false
		orbs_out = false
		for sw in sweeps:
			sw["hazard"].active = false
			sw["pivot"].visible = false
		for f in fists:
			f["haz"].active = false
		if move_tw and move_tw.is_valid():
			move_tw.kill()
		body.position = BASE
	match s:
		"intro":
			Sfx.play("roar")
			Game.add_trauma(0.6)
		"exposed":
			_play("hurt" if phase != 3 else "burn")
			core.position = _core_offset()
			core.armed = true
			body_hazard.active = false
			armor.enabled = false
			Sfx.play("stun")
			Game.add_trauma(0.9)
			Fx.debris(zone.entities, global_position, [Color("8a7e88"), Color("4a4250")], 30)
			for f in fists:
				var tw := create_tween()
				tw.tween_property(f["node"], "position", f["home"] + Vector2(sign(f["home"].x) * 16, 14), 0.5)
				f["spr"].texture = Gfx.tex("bosses/cleaver_down.png")
		"evolve":
			body_hazard.active = false
			core.armed = false
			for g in gems:
				g.armed = false
			armor.enabled = false
			_play("hurt" if phase == 1 else "ignite")
			for f in fists:
				f["haz"].active = false
			for sw in sweeps:
				sw["hazard"].active = false
				sw["pivot"].visible = false
			Sfx.play("shatter")
			Sfx.play("roar", 2.0, 0.6)
			Game.hitstop(0.14)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)
			if phase == 1:
				for p in pylons:
					Fx.sparks(zone.entities, p["sw"].global_position, 14)
			_reset_fists()

func _reset_fists() -> void:
	for f in fists:
		f["spr"].texture = Gfx.tex("bosses/cleaver_up.png")
		create_tween().tween_property(f["node"], "position", f["home"], 0.6)

# ------------------------------------------------------------------ per-frame
func _tick(delta: float) -> void:
	breath += delta
	_face_player()
	if phase == 2 and state != "evolve":
		_track_gems(delta)
	if state == "exposed":
		core.position = _core_offset()
	if phase == 2 and gem_timer > 0.0:
		gem_timer -= delta
		if gem_timer <= 0.0:
			_gems_reset()
	if sweep_t >= 0.0:
		_tick_sweep(delta)
	match state:
		"intro":
			body.position.y = BASE.y + sin(breath * 1.5) * 1.2
			if t > 1.1:
				set_state("gap")
		"gap":
			body.position.y = BASE.y + sin(breath * 1.5) * 1.2
			if t > maxf(0.15, P("gap") - (0.1 * broken if phase != 2 else 0.0)):
				start_attack(pick_attack())
		"exposed":
			core.armed = true
			body.position = BASE + Vector2(randf_range(-0.6, 0.6), 0.0)
			if t > P("expose"):
				_reforge()
		"evolve":
			body.position = BASE + Vector2(randf_range(-1.5, 1.5), randf_range(-1, 1))
			if t >= 1.0 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
				flash_sprite(body, 0.5)
				body_hazard.active = false
				armor.enabled = false
				for g in gems:
					g.armed = false
				Sfx.play("stun", 0.0, 0.7)
				Sfx.play("crash")
				Game.add_trauma(1.0)
				Fx.debris(zone.entities, global_position, [Color("8a7e88"), Color("ff9a30")], 34)
				RingFx.spawn(zone.entities, global_position, Color("ffb040"), 8, 130, 0.6, 4.0)
				Game.show_banner("THE COLOSSUS " + ("BREAKS FREE" if np == 2 else "BURNS"), "PHASE %d" % np)
				Game.say(PHASE_TIPS[np], 6.0)
			if t >= 2.6:
				body.position = BASE
				body_hazard.active = true
				armor.enabled = true
				for g in gems:
					g.armed = (phase == 2)
				set_state("gap")

## the horn flames: on the animation frame normally, on a wide orbit while the demon shoots them
func _track_gems(delta: float) -> void:
	var offs := _orb_offsets()
	if orbs_out:
		orb_ang += delta * 2.6
		for i in 2:
			var a := orb_ang + PI * i
			offs[i] = Vector2(cos(a) * 74.0, sin(a) * 40.0 - 30.0)
	for i in 2:
		gems[i].position = offs[i]
		orb_sprites[i].visible = orbs_out
		orb_sprites[i].position = offs[i]
		orb_sprites[i].scale = Vector2(1.5, 1.5) * (1.0 + 0.15 * sin(breath * 12.0 + i))

func _orb_world(i: int) -> Vector2:
	return global_position + gems[i].position

func _tick_sweep(delta: float) -> void:
	sweep_t += delta
	var k := clampf(sweep_t / sweep_dur, 0.0, 1.0)
	for i in sweep_count:
		var sw: Dictionary = sweeps[i]
		sw["pivot"].visible = true
		sw["pivot"].rotation = lerpf(sw["from"], sw["to"], k)
		sw["hazard"].active = k < 1.0
	if k >= 1.0:
		sweep_t = -1.0
		for sw in sweeps:
			sw["hazard"].active = false
			sw["pivot"].visible = false

func _return_fist(f: Dictionary) -> void:
	f["haz"].active = false
	f["spr"].texture = Gfx.tex("bosses/cleaver_up.png")
	create_tween().tween_property(f["node"], "position", f["home"], 0.6)

func _impact(f: Dictionary) -> void:
	var n: Node2D = f["node"]
	n.global_position = n.global_position + Vector2(0, 30)
	f["spr"].texture = Gfx.tex("bosses/cleaver_down.png")
	f["haz"].active = true
	_play("cl_chop")
	Sfx.play("slam")
	Game.hitstop(0.05)
	Game.add_trauma(0.65)
	var p := n.global_position
	Fx.debris(zone.entities, p, [Color("8a7e88"), Color("4a4250")], 18)
	Fx.dust(zone.entities, p, 10)
	RingFx.spawn(zone.entities, p, Color(1, 1, 1, 0.7), 6, 50, 0.3, 2.0)
	zone.set_floor_tile(Vector2i(int(p.x / 16.0), int(p.y / 16.0)), 11)
	var tw := create_tween()
	tw.tween_interval(0.28)
	tw.tween_callback(func(): f["haz"].active = false)

# ------------------------------------------------------------------ phase 1 / 3: pylons
func _on_pylon_struck(sw: RuneSwitch) -> void:
	if state == "exposed" or state == "evolve" or dead:
		return
	broken += 1
	for p in pylons:
		if p["sw"] == sw:
			var ch: ChainFx = p["chain"]
			Fx.sparks(zone.entities, sw.global_position, 14)
			Fx.debris(zone.entities, (ch.a + ch.b) / 2.0, [Color("7a7a88"), Color("3a3a48")], 10)
			ch.visible = false
	Sfx.play("chain")
	Game.add_trauma(0.5)
	flash_sprite(body, 0.2)
	var tw := create_tween()
	tw.tween_property(body, "position:y", BASE.y + 4.0, 0.06)
	tw.tween_property(body, "position:y", BASE.y, 0.2)
	if broken >= pylons.size():
		Game.hitstop(0.08)
		for sw2 in sweeps:
			sw2["hazard"].active = false
			sw2["pivot"].visible = false
		for f in fists:
			f["haz"].active = false
		set_state("exposed")

func _reforge() -> void:
	broken = 0
	_play(_idle_anim())
	core.armed = false
	body_hazard.active = true
	armor.enabled = true
	body.position = BASE
	Sfx.play("chain")
	Sfx.play("roar", -2.0, 0.8)
	Game.add_trauma(0.7)
	for p in pylons:
		p["sw"].set_on(false)
		p["chain"].visible = true
	_reset_fists()
	Game.say("THE CHAINS RE-FORGE!", 2.0)
	set_state("gap")

# ------------------------------------------------------------------ phase 2: gems
func _on_gem(_kind: String, idx: int) -> void:
	if phase != 2 or gem_hit[idx] or state == "evolve" or dead:
		return
	gem_hit[idx] = true
	gems[idx].armed = false
	var spark := Gfx.sprite("environment/rune_on.png", gems[idx].position)
	spark.name = "GemSpark%d" % idx
	add_child(spark)
	Sfx.play("chain", 0.0, 1.5)
	Game.add_trauma(0.5)
	Fx.sparks(zone.entities, gems[idx].global_position, 14)
	flash_sprite(body, 0.2)
	if gem_hit[0] and gem_hit[1]:
		gem_timer = 0.0
		_clear_sparks()
		phase_pending = 3
		set_state("evolve")
	else:
		gem_timer = P("expose")
		Game.say("ONE FLAME DOUSED - STRIKE THE OTHER!", 2.0)

func _gems_reset() -> void:
	gem_hit = [false, false]
	_clear_sparks()
	for g in gems:
		g.armed = true
	Sfx.play("stun", -4.0, 1.4)
	Game.say("THE FLAMES RELIT!", 1.5)

func _clear_sparks() -> void:
	for i in 2:
		var sp := get_node_or_null("GemSpark%d" % i)
		if sp:
			sp.queue_free()

func _on_weak_struck(_kind: String) -> void:
	# core hit: phase 1 -> 2 (the chains explode), phase 3 -> dead
	if phase == 1:
		phase_pending = 2
		set_state("evolve")
	elif phase == 3:
		kill()

# ------------------------------------------------------------------ helpers for attacks
func _lead(extra := 0.4) -> Vector2:
	return Atk.clamp_in(zone, player.global_position + player.velocity * extra)

func _sweep_setup(count: int, l2r: bool) -> void:
	var a0 := 0.3 if l2r else PI - 0.3
	var a1 := PI - 0.3 if l2r else 0.3
	sweep_count = count
	for i in count:
		var sw: Dictionary = sweeps[i]
		sw["from"] = a0 if i == 0 else a1
		sw["to"] = a1 if i == 0 else a0
		sw["pivot"].rotation = sw["from"]
	WarnFx.wedge(zone.floor_decor, global_position + sweeps[0]["pivot"].position, (a0 + a1) / 2.0, absf(a1 - a0) / 2.0 + 0.05, SWEEP_LEN, 1.0)

# ------------------------------------------------------------------ PHASE 1 - CHAINED
func _atk_cleaver_slam(g: int) -> void:
	for k in 2:
		var f: Dictionary = fists[next_fist]
		next_fist = 1 - next_fist
		f["spr"].texture = Gfx.tex("bosses/cleaver_up.png")
		_play("cl_wind", 1.0 / 0.85)
		var w := WarnFx.circle(zone.floor_decor, player.global_position, 28.0, 0.85)
		w.follow = player
		w.freeze_at = 0.47
		Sfx.play("telegraph", -4.0, 0.8)
		var n: Node2D = f["node"]
		var el := 0.0
		while el < 0.85:
			el += get_physics_process_delta_time()
			if el < 0.47:
				n.global_position = n.global_position.lerp(player.global_position + Vector2(0, -32), 0.2)
			await get_tree().physics_frame
			if not atk_ok(g): return
		_impact(f)
		if not await atk_wait(0.4, g): return
		_return_fist(f)
	await atk_wait(0.3, g)

func _atk_chain_lash(g: int) -> void:
	_sweep_setup(1, randf() < 0.5)
	_play("cl_wind", 1.0 / 1.1)
	Sfx.play("roar", -4.0, 0.9)
	Sfx.play("telegraph", -4.0, 0.7)
	if not await atk_wait(1.1, g): return
	_play("cl_chop")
	sweep_dur = 1.4
	sweep_t = 0.0
	if not await atk_wait(1.6, g): return

func _atk_eruption(g: int) -> void:
	_play("cl_wind", 1.0 / 0.8)
	Sfx.play("roar", -2.0, 0.8)
	if not await atk_wait(0.8, g): return
	_play("cl_chop")
	Game.add_trauma(0.5)
	for i in 6:
		var p: Vector2 = _lead(0.5) if i == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(35.0, 115.0))
		Atk.blast(zone, p, 17.0, 1.0 + 0.1 * i, FIRE, "bosses/flame_col.png", "rise", 0.7)
	if not await atk_wait(1.9, g): return

# ------------------------------------------------------------------ PHASE 2 - UNCHAINED
func _atk_orb_barrage(g: int) -> void:
	_play("cl_wind", 1.0 / 0.7)
	Sfx.play("roar", -2.0, 1.2)
	for i in 2:
		Fx.charge(zone.entities, _orb_world(i), Color("ffc060"), 0.6, 26.0)
	if not await atk_wait(0.7, g): return
	orbs_out = true
	for k in 6:
		Sfx.play("orb", -4.0, 1.1)
		for i in 2:
			var from := _orb_world(i)
			Atk.fan(zone, from, (player.global_position - from).angle(), 3, 0.5, 150.0, "bosses/orb_fire.png", 5.0, 5.0)
		if not await atk_wait(0.62, g): return
	orbs_out = false
	if not await atk_wait(0.4, g): return

func _atk_cleaver_boomerang(g: int) -> void:
	_play("cl_wind", 1.0 / 0.7)
	Sfx.play("telegraph", -2.0, 0.9)
	if not await atk_wait(0.7, g): return
	_play("cl_chop")
	var base := (player.global_position - global_position).angle()
	for k in 2:
		var pr := Atk.shot(zone, global_position + Vector2(0, -10), Vector2.from_angle(base + (0.4 if k == 1 else -0.2)), 235.0, "bosses/cleaver_up.png", 13.0, 5.0)
		pr.rotate_to_vel = false
		pr.spin = 12.0
		pr.boomerang = self
		pr.turn_after = 1.0
		Sfx.play("charge", -2.0, 1.3)
		if not await atk_wait(0.6, g): return
	if not await atk_wait(2.0, g): return

func _atk_leap_slam(g: int) -> void:
	_play("cl_wind", 1.0 / 0.9)
	Sfx.play("roar", 0.0, 0.8)
	if not await atk_wait(0.45, g): return
	var target := _lead(0.35)
	Atk.blast(zone, target, 36.0, 1.0, FIRE, "", "none", 0.3)
	var tw := create_tween().set_parallel(true)
	move_tw = tw
	tw.tween_property(self, "global_position", target + Vector2(0, -4), 0.95).set_trans(Tween.TRANS_SINE)
	var up := create_tween()
	up.tween_property(body, "position:y", BASE.y - 90.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	up.tween_property(body, "position:y", BASE.y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for k in 5:
		Fx.afterimage(zone.entities, body, Color(1.0, 0.6, 0.3, 0.45), 0.35)
		if not await atk_wait(0.19, g): return
	_play("cl_chop")
	Fx.flash(zone.entities, global_position + Vector2(0, 14), Color("ffb040"), 26.0)
	Sfx.play("slam")
	Game.hitstop(0.06)
	Game.add_trauma(0.9)
	zone.camera.punch(0.04, 0.3)
	Fx.debris(zone.entities, global_position, [Color("8a7e88"), Color("ff9a30")], 22)
	var r := RingHazard.spawn(zone.entities, global_position + Vector2(0, 14), FIRE)
	r.expand(95.0, 0.6)
	TimedHazard.spawn(zone.entities, global_position + Vector2(0, 12), 22.0, 3.0, FIRE)
	if not await atk_wait(1.2, g): return

func _atk_fire_wave(g: int) -> void:
	_play("cl_wind", 1.0 / 0.6)
	Sfx.play("telegraph", -2.0, 0.8)
	if not await atk_wait(0.6, g): return
	_play("cl_chop")
	Game.add_trauma(0.5)
	var d := (player.global_position - global_position).normalized()
	breath_fx.position = _core_offset() + Vector2(0, -6)
	breath_fx.rotation = d.angle()
	breath_fx.visible = true
	breath_fx.play("breath")
	for off in [-0.38, 0.0, 0.38]:
		Atk.line_blasts(zone, global_position + Vector2(0, 20), d.rotated(off), 12, 22.0, 14.0, 0.4, 0.06, FIRE, "bosses/flame_col.png", "rise")
	if not await atk_wait(0.9, g):
		breath_fx.visible = false
		return
	breath_fx.visible = false
	if not await atk_wait(0.9, g): return

# ------------------------------------------------------------------ PHASE 3 - BURNING
func _atk_meteor_rain(g: int) -> void:
	_play("burn", 1.6)
	Sfx.play("roar", 2.0, 0.6)
	Fx.charge(zone.entities, global_position + Vector2(0, -50), Color("ef6a2a"), 0.9, 50.0)
	Game.add_trauma(0.6)
	for i in 14:
		var p: Vector2 = _lead(0.5) if i == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 120.0))
		Atk.blast(zone, p, 17.0, 0.95 + 0.09 * i, FIRE, "bosses/fire_drop.png", "fall", 0.35)
	if not await atk_wait(2.6, g): return

func _atk_flame_charge(g: int) -> void:
	_play("cl_wind", 1.0 / 0.5)
	Sfx.play("telegraph", -2.0, 0.7)
	if not await atk_wait(0.5, g): return
	_play("walk", 2.2)                              # a running stride, not a frozen chop
	var d := (player.global_position - global_position).normalized()
	var target := Atk.clamp_in(zone, global_position + d * 280.0, 40.0)
	Sfx.play("charge", 0.0, 0.8)
	var tw := create_tween()
	move_tw = tw
	tw.tween_property(self, "global_position", target, 0.85)
	for i in 12:
		TimedHazard.spawn(zone.entities, global_position + Vector2(0, 14), 10.0, 3.2, FIRE)
		Fx.afterimage(zone.entities, body, Color(1.0, 0.5, 0.2, 0.5), 0.3)
		if not await atk_wait(0.07, g): return
	if not await atk_wait(0.2, g): return
	var back := create_tween()
	move_tw = back
	back.tween_property(self, "global_position", home_pos, 0.9)
	if not await atk_wait(1.0, g): return

func _atk_immolation(g: int) -> void:
	_play("ignite", 1.4)
	Sfx.play("roar", 2.0, 0.5)
	Fx.charge(zone.entities, global_position + Vector2(0, -20), Color("ffc060"), 0.7, 60.0)
	Game.hitstop(0.05)
	Game.add_trauma(0.9)
	if not await atk_wait(0.7, g): return
	_play("burn")
	var r1 := RingHazard.spawn(zone.entities, global_position + Vector2(0, 12), FIRE)
	r1.expand(140.0, 1.0)
	Atk.ring(zone, global_position + Vector2(0, -6), 18, 110.0, "bosses/orb_fire.png", 0.0, 5.0, 4.0)
	if not await atk_wait(0.55, g): return
	var r2 := RingHazard.spawn(zone.entities, global_position + Vector2(0, 12), Color("ffc060"))
	r2.expand(120.0, 0.9)
	Atk.ring(zone, global_position + Vector2(0, -6), 14, 95.0, "bosses/orb_fire.png", 0.2, 5.0, 4.0)
	if not await atk_wait(1.2, g): return

func _atk_hellfire_spiral(g: int) -> void:
	_play("burn", 1.8)
	Sfx.play("roar", 0.0, 0.7)
	if not await atk_wait(0.5, g): return
	for i in 26:
		Atk.ring(zone, global_position + Vector2(0, -8), 3, 118.0, "bosses/orb_fire.png", i * 0.43, 5.0, 4.5)
		if i % 4 == 0:
			Sfx.play("orb", -8.0, 0.9)
		if not await atk_wait(0.12, g): return
	if not await atk_wait(0.6, g): return

func _arena_reaction() -> void:
	super._arena_reaction()
	for p in pylons:
		p["chain"].visible = false

func _death_sequence() -> void:
	_death_by_animation(body, "death", [Color("ffe9a8"), Color("ef8d35")])
