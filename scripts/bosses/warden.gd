extends BossBase
## STONE WARDEN (Mecha-stone Golem art) - the keeper of the rune sanctum. Three forms, ten attacks, none reused in another form.
## The weak point is always the crystal on its brow, and it is armed ONLY on the animation frames where the crystal is visibly
## exposed (see _crystal_exposed). Each form has ONE attack that exposes it:
##   Phase 1  WARDEN     rocket fist, rock spikes, and the ROLL: it curls into a ball; a crash into a pillar makes it uncurl, dazed.
##   Phase 2  AWAKENED   laser (the veins charge, then a ricocheting beam), shard volley, and the POUND: after it the crystal opens.
##   Phase 3  MOLTEN     fist boomerang, lava rivers, meteor rocks, and the OVERHEAT: it vents steam and the crystal opens -
##                       to a RECALLED arrow only.
## Sprite rows in golem.png (100x100 cells): 0 idle, 1 veins charging, 2 arm punch, 3 curl into a ball, 4 arm tears off,
## 5 dazed (crystal flickers), 6 slam (windup + cracks glowing), 7 crumble.

const PHASES := {
	1: {"track": 40.0, "charge": 280.0, "tele": 0.9, "lock": 0.55, "idle": 0.8, "hz": 17.0, "armor": 22.0},
	2: {"track": 50.0, "charge": 330.0, "tele": 0.75, "lock": 0.45, "idle": 0.5, "hz": 19.0, "armor": 24.0},
	3: {"track": 60.0, "charge": 400.0, "tele": 0.55, "lock": 0.3, "idle": 0.35, "hz": 20.0, "armor": 26.0},
}
const ATTACKS := {
	1: ["roll", "rocket_fist", "rock_spikes"],
	2: ["pound", "laser", "shard_volley"],
	3: ["overheat", "fist_boomerang", "lava_rivers", "meteor_rocks"],
}
const PHASE_TIPS := {
	2: "THE VEINS ARE LIT. DODGE THE POUND - THEN SHOOT THE GLOWING CRYSTAL BEFORE IT CLOSES.",
	3: "IT OVERHEATS AND VENTS STEAM. RECALL THE ARROW THROUGH THE OPEN CRYSTAL.",
}
const SHEET := "bosses/golem.png"
const ANIMS := {
	"idle": {"frames": [0, 1, 2, 3], "fps": 5},
	"idle2": {"frames": [13, 14, 15, 14], "fps": 6},                       # veins lit
	"idle3": {"frames": [66, 67, 68, 69, 68, 67], "fps": 6},               # glowing cracks
	"tele": {"frames": [10, 11, 12, 13, 14, 15], "fps": 6, "loop": false}, # veins charge up
	"curl": {"frames": [30, 31, 32, 33, 34, 35, 36, 37], "fps": 30, "loop": false},
	"uncurl": {"frames": [37, 36, 35, 34, 33, 32, 31, 30], "fps": 30, "loop": false},
	"hurt": {"frames": [50, 51, 52, 53, 54, 55, 56], "fps": 7},            # crystal flickers
	"windup": {"frames": [60, 61, 62, 63, 64], "fps": 6, "loop": false},
	"impact": {"frames": [65, 66, 67, 68, 69], "fps": 5, "loop": false},
	"throw": {"frames": [20, 21, 22, 23, 24, 25, 26, 27, 28], "fps": 10, "loop": false},
	"armoff": {"frames": [40, 41, 42, 43, 44, 45, 46], "fps": 9, "loop": false},           # the arm tears off (fist boomerang)
	"death": {"frames": [70, 71, 72, 73, 74, 75, 76, 77, 78, 79], "fps": 7, "loop": false},
}
const CRYSTAL := Vector2(0, -23)      # brow crystal, measured from the sheet (tools/analyze_boss_art.py): cell (51,33)
const TINT := {1: Color(1, 1, 1), 2: Color(1, 1, 1), 3: Color(1.4, 0.82, 0.6)}
const LAVA := Color("ef6a2a")

var phase := 1
var mover: CharacterBody2D
var body: AnimatedSprite2D
var weak_window := false
var hazard: Hazard
var weak: WeakPoint
var weak_shape: CircleShape2D
var armor: Armor
var armor_shape: CircleShape2D
var hazard_shape: CircleShape2D
var line: Line2D
var dir := Vector2.RIGHT
var facing := 1.0
var speed := 0.0
var bob := 0.0
var stun_time := 4.0
var puff := 0.0
var phase_pending := 0
var move_tw: Tween
var charge_orb: AnimatedSprite2D          # the crystal charging before a laser (from the pack's laser sheet)

func attack_list() -> Array:
	return ATTACKS[phase]

func all_attacks() -> Dictionary:
	return ATTACKS

func _build() -> void:
	mover = CharacterBody2D.new()
	mover.collision_layer = L.BODY
	mover.collision_mask = L.WORLD
	mover.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	mover.add_child(cs)
	add_child(mover)
	body = AnimatedSprite2D.new()
	body.sprite_frames = Gfx.sheet_frames(SHEET, 100, 100, ANIMS)
	body.position = Vector2(0, -6)
	add_child(body)
	sprites.append(body)
	body.animation_finished.connect(_on_anim_done)
	body.play("idle")
	hazard = add_hazard_circle(17.0)
	hazard_shape = hazard.shape_node.shape
	armor = add_armor_circle(22.0)
	armor_shape = armor.get_child(0).shape
	weak = add_weak(9.0, CRYSTAL)
	weak_shape = weak.get_child(0).shape
	weak.glow.scale = Vector2(0.6, 0.6)                 # the crystal is small: a tight cyan halo, not a big blob
	weak.glow.modulate = Color(0.6, 1.0, 1.3)
	charge_orb = AnimatedSprite2D.new()
	var lf := SpriteFrames.new()
	lf.remove_animation("default")
	lf.add_animation("charge")
	lf.set_animation_speed("charge", 7.0)
	lf.set_animation_loop("charge", false)
	for i in 7:
		var at := AtlasTexture.new()
		at.atlas = Gfx.tex("bosses/laser_charge.png")
		at.region = Rect2(i * 64, 0, 64, 64)
		lf.add_frame("charge", at)
	charge_orb.sprite_frames = lf
	charge_orb.position = CRYSTAL + Vector2(0, -6)
	charge_orb.z_index = 4
	charge_orb.visible = false
	add_child(charge_orb)
	line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(1, 0.5, 0.2, 0.0)
	line.z_index = -1
	line.visible = Game.SHOW_AIM_TELEGRAPHS
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	add_child(line)

func _on_start() -> void:
	_apply_phase(1)
	set_state("idle")

# ------------------------------------------------------------------ helpers
func P(key: String) -> float:
	return PHASES[phase][key]

func _play(anim: String, speed_ := 1.0) -> void:
	body.speed_scale = speed_
	body.play(anim)

func _play_idle() -> void:
	_play("idle" if phase == 1 else "idle%d" % phase)

## The brow crystal only counts as a weak point on frames where the artwork shows it open.
func _crystal_exposed() -> bool:
	match body.animation:
		"uncurl":
			return body.frame >= 3        # frames 0-2 are still a closed ball
		"hurt", "impact":
			return true
		_:
			return false

func _on_anim_done() -> void:
	match body.animation:
		"uncurl":
			if state == "stunned":
				_play("hurt")
		"impact":
			if state == "stomp":
				_play("hurt")
			elif state == "attack":
				_play_idle()
		"throw":
			if state == "attack":
				_play_idle()

func _apply_phase(p: int) -> void:
	phase = p
	zone.on_phase(p)
	seq_reset()
	hazard_shape.radius = P("hz")
	armor_shape.radius = P("armor")
	armor.enabled = true
	hazard.active = true
	weak.armed = false
	weak_window = false
	body.self_modulate = TINT[p]
	_play_idle()
	line.width = 3.0 + p

func seq_reset() -> void:
	reset_attacks()

func _set_weak(pos: Vector2, r: float, fly: bool, ret: bool, armed: bool) -> void:
	weak.position = pos
	weak_shape.radius = r
	weak.accept_fly = fly
	weak.accept_ret = ret
	weak.armed = armed

func _sync_mover() -> void:
	position += mover.position
	mover.position = Vector2.ZERO

func _face(d: Vector2) -> void:
	if absf(d.x) > 0.15:
		facing = signf(d.x)
	body.flip_h = facing < 0.0

func _dormant(delta: float) -> void:
	bob += delta * 2.0
	body.position.y = -6.0 + sin(bob) * 0.8

func _lead(extra := 0.4) -> Vector2:
	return Atk.clamp_in(zone, player.global_position + player.velocity * extra)

# ------------------------------------------------------------------ state entry
func _enter(s: String) -> void:
	weak_window = false
	if s != "charge":
		body.rotation = 0.0
	if s != "attack":
		if move_tw and move_tw.is_valid():
			move_tw.kill()
		body.position = Vector2(0, -6)
	match s:
		"idle":
			_play_idle()
			hazard.active = true
			armor.enabled = true
			weak.armed = false
			line.default_color.a = 0.0
		"tele":
			_play("tele", 1.0 / P("tele"))
			Sfx.play("telegraph", 0.0, 1.0 + 0.15 * phase)
			Sfx.play("roar", -6.0, 1.3 - 0.15 * phase)
		"charge":
			_play("curl")
			speed = 50.0
			line.default_color.a = 0.0
			Sfx.play("charge", 0.0, 1.0 + 0.1 * phase)
		"stunned":
			_play("uncurl")
			hazard.active = false
			armor.enabled = false
			# any arrow, but only while the crystal shows
			_set_weak(CRYSTAL, 10.0, true, true, false)
			weak_window = true
			Sfx.play("stun")
		"recover":
			_play_idle()
			hazard.active = true
			armor.enabled = true
			weak.armed = false
		"stomp_tele":
			_play("windup", (5.0 / 6.0) / 0.9)
			Sfx.play("telegraph", 0.0, 0.7)
			Sfx.play("roar", -2.0, 0.7)
			WarnFx.circle(zone.floor_decor, global_position, 132.0, 0.9, Color(1.0, 0.45, 0.15))
		"stomp":
			_do_pound()
		"evolve":
			hazard.active = false
			weak.armed = false
			armor.enabled = true
			line.default_color.a = 0.0
			_play("tele")
			Sfx.play("shatter")
			Sfx.play("roar", 2.0, 0.6)
			Game.hitstop(0.14)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)
			for p in zone.pillars:
				if is_instance_valid(p) and p.broken:
					p.restore()

# ------------------------------------------------------------------ per-frame
func _tick(delta: float) -> void:
	if weak_window:
		weak.armed = _crystal_exposed()
	match state:
		"idle":
			bob += delta * 6.0
			body.position.y = -6.0 + sin(bob) * 1.2
			var d := player_dir()
			_face(d)
			mover.velocity = d * P("track")
			mover.move_and_slide()
			_sync_mover()
			if t > P("idle") and (phase > 1 or player_dist() > 30.0):
				start_attack(pick_attack())
		"attack":
			_face(player_dir())
		"tele":
			body.position = Vector2(randf_range(-1, 1), -6.0)
			if t < P("lock"):
				dir = player_dir()
				_face(dir)
			puff -= delta
			if puff <= 0.0:
				puff = 0.09
				Fx.dust(zone.entities, global_position + Vector2(-dir.x * 12, 12), 2)
			if t >= P("tele"):
				body.position = Vector2(0, -6)
				set_state("charge")
		"charge":
			speed = move_toward(speed, P("charge"), 900.0 * delta)
			body.rotation += (1.0 if dir.x >= 0.0 else -1.0) * speed * delta / 16.0   # rolls like a ball
			var col := mover.move_and_collide(dir * speed * delta)
			_sync_mover()
			puff -= delta
			if puff <= 0.0:
				puff = 0.05
				Fx.dust(zone.entities, global_position + Vector2(-dir.x * 14, 12), 2)
			if col:
				_crash(col)
			elif t > 1.6:
				body.rotation = 0.0
				set_state("recover")
		"stunned":
			body.rotation = 0.0
			body.position = Vector2(randf_range(-0.5, 0.5), -6.0)
			if t >= stun_time:
				set_state("recover")
		"recover":
			body.rotation = 0.0
			if t > 0.5:
				set_state("idle")
		"stomp_tele":
			body.position = Vector2(randf_range(-1, 1), -6.0 + randf_range(-1, 0))
			_face(player_dir())
			if t >= 0.9:
				body.position = Vector2(0, -6)
				set_state("stomp")
		"stomp":
			if t >= 2.0:
				set_state("recover")
		"evolve":
			body.position = Vector2(randf_range(-2, 2), -6.0 + randf_range(-1, 1))
			if t >= 1.0 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
				flash_sprite(body, 0.5)
				Sfx.play("stun", 0.0, 0.7)
				Sfx.play("crash")
				Game.add_trauma(1.0)
				Fx.debris(zone.entities, global_position, [Color("9a96a4"), Color("ff9a30")], 34)
				RingFx.spawn(zone.entities, global_position, Color("ffb040"), 8, 120, 0.6, 4.0)
				hazard.active = false
				Game.show_banner("THE WARDEN " + ("AWAKENS" if np == 2 else "BURNS"), "PHASE %d" % np)
				Game.say(PHASE_TIPS[np], 6.0)
			if t >= 2.4:
				set_state("idle")

# ------------------------------------------------------------------ crash / weak point (phase 1 roll)
func _crash(col: KinematicCollision2D) -> void:
	var c := col.get_collider()
	var hit_pos := col.get_position()
	body.rotation = 0.0
	Game.hitstop(0.08)
	Game.add_trauma(0.7)
	zone.camera.punch(0.03, 0.25)
	Sfx.play("crash")
	Fx.debris(zone.entities, hit_pos, [Color("9a96a4"), Color("5a566a")], 16)
	Fx.dust(zone.entities, hit_pos, 8)
	RingFx.spawn(zone.entities, hit_pos, Color(1, 1, 1, 0.7), 4, 44, 0.3, 2.0)
	var pillar_hit: bool = c is Pillar and c.breakable and not c.broken
	if pillar_hit:
		c.shatter(dir)
	var left := 0
	for p in zone.pillars:
		if is_instance_valid(p) and not p.broken:
			left += 1
	if pillar_hit:
		stun_time = 4.0
		set_state("stunned")
	elif left == 0:
		stun_time = 2.6
		set_state("stunned")
	else:
		set_state("recover")

func _on_weak_struck(_kind: String) -> void:
	if phase < 3:
		phase_pending = phase + 1
		set_state("evolve")
	else:
		kill()

func _on_armor_clank(_pos: Vector2, _kind: String) -> void:
	flash_sprite(body, 0.08)

func _ring(seconds: float, big := 140.0, col := Color(1.0, 0.5, 0.15)) -> void:
	var r := RingHazard.spawn(zone.entities, global_position + Vector2(0, 10), col)
	r.expand(big, seconds)
	Sfx.play("slam", 0.0, 0.9)

## phase 2's exposure: the ground pound, then the crystal opens
func _do_pound() -> void:
	_play("impact")
	hazard.active = true
	Sfx.play("slam")
	Game.hitstop(0.06)
	Game.add_trauma(0.9)
	zone.camera.punch(0.04, 0.3)
	Fx.debris(zone.entities, global_position, [Color("9a96a4"), Color("ff9a30")], 22)
	Fx.dust(zone.entities, global_position, 14)
	_ring(0.85)
	hazard.active = false
	armor.enabled = false
	_set_weak(CRYSTAL, 13.0, true, true, true)
	weak_window = true
	Sfx.play("stun", -2.0, 1.3)

# ------------------------------------------------------------------ PHASE 1 - WARDEN
func _atk_roll(g: int) -> void:
	set_state("tele")             # hands over to the legacy roll: tele -> charge -> crash / recover

func _atk_rocket_fist(g: int) -> void:
	for k in 2:
		_play("throw", 1.0)
		Sfx.play("telegraph", -2.0, 1.2)
		if not await atk_wait(0.6, g): return
		var d := (_lead(0.3) - global_position).normalized()
		var pr := Atk.shot(zone, global_position + Vector2(0, -8), d, 230.0, "bosses/golem_fist.png", 7.0, 3.2)
		pr.spin = 0.0
		Fx.flash(zone.entities, global_position + Vector2(18.0 * facing, -12.0), Color("ffc060"), 12.0)
		Sfx.play("charge", -2.0, 1.5)
		Game.add_trauma(0.25)
		if not await atk_wait(0.35, g): return
	await atk_wait(0.4, g)

func _atk_rock_spikes(g: int) -> void:
	_play("windup", (5.0 / 6.0) / 0.7)
	Sfx.play("telegraph", -2.0, 0.8)
	if not await atk_wait(0.7, g): return
	_play("impact")
	Game.add_trauma(0.5)
	Sfx.play("slam", -2.0, 1.1)
	for i in 6:
		var p: Vector2 = _lead(0.5) if i == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0))
		Atk.blast(zone, p, 15.0, 1.0 + 0.12 * i, Color("9aa6b0"), "bosses/stone_spike.png", "rise", 0.5)
	if not await atk_wait(1.9, g): return

# ------------------------------------------------------------------ PHASE 2 - AWAKENED
func _atk_pound(g: int) -> void:
	set_state("stomp_tele")       # hands over to the legacy pound: windup -> slam -> crystal opens

func _atk_laser(g: int) -> void:
	_play("tele", 1.0 / 1.0)
	Sfx.play("telegraph", 0.0, 0.9)
	Sfx.play("roar", -4.0, 1.0)
	charge_orb.visible = true
	charge_orb.speed_scale = 1.0
	charge_orb.play("charge")
	Fx.charge(zone.entities, global_position + Vector2(0, -30) + CRYSTAL, Color("6ae8f0"), 0.9, 40.0)
	if not await atk_wait(1.0, g):
		charge_orb.visible = false
		return
	charge_orb.visible = false
	Fx.flash(zone.entities, global_position + Vector2(0, -6) + CRYSTAL, Color("6ae8f0"), 16.0)
	for k in 2:
		var from := global_position + Vector2(0, -20)
		var d := ((_lead(0.15) + Vector2(0, -6)) - from).normalized().rotated(0.0 if k == 0 else 0.42)
		var segs := BeamShot.compute(self, from, d, 1)
		BeamShot.fire(zone.entities, segs, 8.0, 0.55, Color(0.4, 0.95, 1.0))
		Sfx.play("beam", 0.0, 1.0)
		Game.add_trauma(0.4)
		for sg in segs:
			Fx.sparks(zone.entities, sg[1], 8)
		if not await atk_wait(0.55, g): return
	await atk_wait(0.5, g)

func _atk_shard_volley(g: int) -> void:
	for k in 3:
		_play("throw", 1.4)
		Sfx.play("orb", 0.0, 0.8)
		var from := global_position + Vector2(0, -12)
		var base := (_lead(0.2) - from).angle()
		Atk.fan(zone, from, base, 5 + k, 0.9 + 0.15 * k, 150.0 + 18.0 * k, "bosses/rock.png", 5.0, 5.0)
		Game.add_trauma(0.3)
		if not await atk_wait(0.6, g): return
	await atk_wait(0.4, g)

# ------------------------------------------------------------------ PHASE 3 - MOLTEN
func _atk_overheat(g: int) -> void:
	_play("windup", (5.0 / 6.0) / 0.8)
	Sfx.play("telegraph", -2.0, 0.6)
	Fx.charge(zone.entities, global_position + Vector2(0, -30), Color("ffc060"), 0.8, 46.0)
	if not await atk_wait(0.8, g): return
	_play("hurt")
	Sfx.play("stun")
	Game.add_trauma(0.6)
	_ring(0.7, 80.0, Color("ffc060"))
	hazard.active = false
	armor.enabled = false
	_set_weak(CRYSTAL, 10.0, false, true, false)
	weak_window = true
	for i in 6:
		Fx.burst(zone.entities, global_position + Vector2(randf_range(-14, 14), -14), [Color("ffffff"), Color("c8d0d8")], 8, 40.0, 0.7, 2.0, -40.0, Vector2.UP, 30.0)
		if not await atk_wait(0.4, g): return
	weak_window = false
	hazard.active = true
	armor.enabled = true

func _atk_fist_boomerang(g: int) -> void:
	_play("armoff", 1.0)                        # the arm tears off...
	Sfx.play("telegraph", -2.0, 1.0)
	if not await atk_wait(0.75, g): return
	Fx.flash(zone.entities, global_position + Vector2(20.0 * facing, -14.0), Color("ffc060"), 12.0)
	var base := (_lead(0.2) - global_position).angle()
	for k in 2:
		var pr := Atk.shot(zone, global_position + Vector2(0, -8), Vector2.from_angle(base + (0.35 if k == 1 else -0.15)), 250.0, "bosses/golem_fist.png", 8.0, 5.0)
		pr.boomerang = self
		pr.turn_after = 0.95
		Sfx.play("charge", -2.0, 1.2)
		if not await atk_wait(0.55, g): return
	await atk_wait(1.9, g)
	_play_idle()                                # ...and is back on

func _atk_lava_rivers(g: int) -> void:
	_play("windup", (5.0 / 6.0) / 0.7)
	Sfx.play("roar", 0.0, 0.7)
	if not await atk_wait(0.7, g): return
	_play("impact")
	Game.add_trauma(0.7)
	var base := (player.global_position - global_position).angle()
	for off in [-0.6, 0.0, 0.6]:
		Atk.line_blasts(zone, global_position + Vector2(0, 14), Vector2.from_angle(base + off), 13, 22.0, 15.0, 0.4, 0.06, LAVA, "bosses/flame_col.png", "rise")
	if not await atk_wait(1.0, g): return
	for off in [-0.3, 0.3]:
		Atk.line_blasts(zone, global_position + Vector2(0, 14), Vector2.from_angle(base + off), 13, 22.0, 15.0, 0.4, 0.06, LAVA, "bosses/flame_col.png", "rise")
	if not await atk_wait(1.6, g): return

func _atk_meteor_rocks(g: int) -> void:
	_play("tele", 1.4)
	Sfx.play("roar", 0.0, 0.6)
	Fx.charge(zone.entities, global_position + Vector2(0, -34), Color("ef6a2a"), 0.6, 44.0)
	if not await atk_wait(0.6, g): return
	for i in 12:
		var p: Vector2 = _lead(0.5) if i == 0 else Atk.clamp_in(zone, player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 115.0))
		Atk.blast(zone, p, 18.0, 1.0 + 0.1 * i, LAVA, "bosses/rock.png", "fall", 0.35)
	if not await atk_wait(2.4, g): return

func _death_sequence() -> void:
	_death_by_animation(body, "death", [Color("ffe9a8"), Color("9a96a4")])
