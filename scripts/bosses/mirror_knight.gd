extends BossBase
## MIRROR KNIGHT (Frost Guardian art) - the lord of the frozen vault. Three forms, twelve attacks, none repeated in another form.
## Any arrow that clanks off its guard, plates or body is FROZEN in ice for a few seconds and cannot be recalled.
## The weak point is the eye in its chest; it only counts while the artwork shows it AND the knight is in its window attack:
##   Phase 1  GUARDIAN  lance, icicle clap, ice wall  - and the SLAM: its fist sticks in the ice and the eye shows (any arrow).
##   Phase 2  CARAPACE  glacier roll, blizzard, spike line - and the ROAR: the chest opens for the roar frames (any arrow).
##   Phase 3  PRISM     absolute zero, plate volley, shatter dash - and the BEAM: after it the guardian staggers, eye open,
##                      recalled arrows only.
## Sprite: the sheet faces LEFT; the knight only ever faces left or right, the ice guard (a separate sprite) turns with `angle`.

const SHEET := "bosses/frost.png"      # 96x64 cells, 16 columns: row 0 idle, 1 walk, 2 punch, 3 hurt, 4 death
const ANIMS := {
	"idle": {"frames": [0, 1, 2, 3, 4, 5], "fps": 6},
	"walk": {"frames": [16, 17, 18, 19, 20, 21, 22, 23, 24, 25], "fps": 12},
	"windup": {"frames": [32, 33, 34, 35, 36, 37], "fps": 10, "loop": false},     # punch frames 0-5: eye visible
	"strike": {"frames": [38, 39, 40], "fps": 15, "loop": false},                  # punch frames 6-8: ice lance, eye hidden
	"recover": {"frames": [41, 42, 43, 44, 45], "fps": 10, "loop": false},        # punch frames 9-13: eye back at frame 11
	"kneel": {"frames": [48, 49, 50, 51, 52, 53, 54], "fps": 7},                   # staggered
	"raise": {"frames": [80, 81, 82], "fps": 8, "loop": false},                    # drawn for this game: arms flexed up (tools/gen_drawn.py)
	"clap": {"frames": [83, 84, 85], "fps": 14, "loop": false},                    # drawn: fists brought together
	"carapace": {"frames": [68, 69, 70, 70, 69], "fps": 5},                        # armoured pose, arms up: chest open at 69/70
	"shatter": {"frames": [71, 72, 73, 74], "fps": 6, "loop": false},
	"death": {"frames": [64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79], "fps": 11, "loop": false},
}
const EYE_IDLE := Vector2(-1.0, -8.4)
const EYE_WINDUP := [Vector2(-1.0, -8.4), Vector2(1.5, -8.4), Vector2(4.0, -7.9), Vector2(6.8, -7.9), Vector2(7.8, -7.9), Vector2(7.8, -7.9)]
const EYE_RECOVER := [Vector2(-5.2, -5.9), Vector2(-5.2, -5.9), Vector2(-5.2, -5.9), Vector2(-2.5, -7.4), Vector2(-1.0, -8.4)]
const TINT := {1: Color(1, 1, 1), 2: Color(0.62, 0.74, 1.25), 3: Color(1.25, 1.05, 1.4)}
const ICE := Color("9fd8ff")
const FREEZE_TIME := 2.6

const PHASES := {
	1: {"walk": 44.0, "turn": 3.2, "gap": 0.5},
	2: {"walk": 56.0, "turn": 3.8, "gap": 0.35},
	3: {"walk": 66.0, "turn": 4.6, "gap": 0.22},
}
const ATTACKS := {
	1: ["lance", "icicle_clap", "ice_wall", "slam"],
	2: ["roll", "blizzard", "spike_line", "roar"],
	3: ["beam", "plates_volley", "absolute_zero", "shatter_dash"],
}
const PHASE_TIPS := {
	2: "THE CHEST IS SEALED. THE EYE SHOWS ONLY WHEN IT ROARS - AND ARROWS THAT HIT ITS ARMOUR FREEZE.",
	3: "THE PLATES ORBIT. AFTER EACH BEAM IT STAGGERS - RECALL THE ARROW THROUGH THE EYE.",
}

var phase := 1
var weak_window := false
var facing_right := false
var mover: CharacterBody2D
var pivot: Node2D
var sprite: AnimatedSprite2D
var guard: Sprite2D
var hazard: Hazard
var slash_hazard: Hazard
var shield: Armor
var body_armor: Armor
var weak: WeakPoint
var weak_shape: CircleShape2D
var shield_shape: RectangleShape2D
var plates: Array = []
var plate_ang := 0.0
var plate_speed := 2.4
var angle := PI / 2.0
var turn_rate := 3.0
var track := false
var bob := 0.0
var phase_pending := 0
var roll_dir := Vector2.ZERO
var roll_bounces := 0
var roll_trail := 0.0
var pull := false

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
	c.radius = 12.0
	cs.shape = c
	mover.add_child(cs)
	add_child(mover)
	pivot = Node2D.new()
	add_child(pivot)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Gfx.sheet_frames(SHEET, 96, 64, ANIMS)
	add_child(sprite)                       # not under the pivot: the art faces left/right, it never rotates
	sprites.append(sprite)
	sprite.play("idle")
	guard = Gfx.sprite("bosses/ice_shield.png", Vector2(27, 0))     # the ice shield: turns with the pivot
	guard.modulate = Color(1, 1, 1, 0.95)
	pivot.add_child(guard)
	hazard = add_hazard_circle(13.0)
	slash_hazard = Hazard.box(Vector2(52, 50), Vector2(34, 6))
	pivot.add_child(slash_hazard)
	slash_hazard.active = false
	shield = Armor.make_box(Vector2(12, 48), Vector2(27, 0), Armor.Mode.BOUNCE, Armor.Mode.DROP)
	shield.normal_fn = func(_p: Vector2) -> Vector2: return Vector2.from_angle(angle)
	shield.clanked.connect(_on_guard_clank)
	pivot.add_child(shield)
	shield_shape = shield.get_child(0).shape
	body_armor = add_armor_circle(13.0, Vector2.ZERO, Armor.Mode.BOUNCE, Armor.Mode.DROP)
	weak = WeakPoint.make(8.0, EYE_IDLE)
	add_child(weak)                         # on the body, not the pivot: the eye stays on the chest
	weak.struck.connect(_on_weak_struck)
	weak_shape = weak.get_child(0).shape
	weak.glow.scale = Vector2(0.55, 0.55)
	weak.glow.modulate = Color(0.7, 1.0, 1.3)
	weak.armed = false
	# phase-3 orbiting prism plates
	for i in 3:
		var n := Node2D.new()
		n.visible = false
		var spr := Gfx.sprite("bosses/mirror_plate.png")
		n.add_child(spr)
		var ar := Armor.make_box(Vector2(10, 30), Vector2.ZERO, Armor.Mode.BOUNCE, Armor.Mode.DROP)
		ar.enabled = false
		ar.normal_fn = func(_p: Vector2) -> Vector2: return Vector2.from_angle(n.rotation)
		ar.clanked.connect(_on_guard_clank)
		n.add_child(ar)
		add_child(n)
		plates.append({"node": n, "armor": ar})
	pivot.rotation = angle

# ------------------------------------------------------------------ helpers
## squash and stretch (feet stay on the floor): raise = tall and thin, slam = short and wide
func _squash(sx: float, sy: float, dur := 0.15) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(sx, sy), dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", 23.0 * (1.0 - sy), dur).set_trans(Tween.TRANS_SINE)

func _play(anim: String, speed := 1.0) -> void:
	sprite.speed_scale = speed
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)

func _idle_anim() -> String:
	return "carapace" if phase == 2 else "idle"

## The eye only counts as a weak point on frames where the artwork shows it.
func _eye_open() -> bool:
	match sprite.animation:
		"strike", "raise", "clap":
			return false
		"windup", "idle", "walk":
			return phase != 2
		"recover":
			return phase != 2 and sprite.frame >= 2
		"carapace":
			return sprite.frame >= 1 and sprite.frame <= 3
		"kneel":
			return true
		_:
			return phase != 2

func _eye_offset() -> Vector2:
	var o := EYE_IDLE
	match sprite.animation:
		"windup":
			o = EYE_WINDUP[clampi(sprite.frame, 0, 5)]
		"recover":
			o = EYE_RECOVER[clampi(sprite.frame, 0, 4)]
		"kneel":
			o = Vector2(2.0, -6.0)
	return Vector2(-o.x if facing_right else o.x, o.y)

func _face_sprite() -> void:
	facing_right = cos(angle) > 0.0
	sprite.flip_h = facing_right

func _set_weak(pos: Vector2, r: float, fly: bool, ret: bool) -> void:
	weak.position = pos
	weak_shape.radius = r
	weak.accept_fly = fly
	weak.accept_ret = ret

func _apply_phase(p: int) -> void:
	phase = p
	zone.on_phase(p)
	sprite.self_modulate = TINT[p]
	weak_window = false
	track = false
	roll_dir = Vector2.ZERO
	sprite.rotation = 0.0
	_play(_idle_anim())
	reset_attacks()
	body_armor.enabled = true
	hazard.active = true
	match p:
		1:
			shield.enabled = true
			guard.visible = true
			_set_weak(EYE_IDLE, 9.0, true, true)
		2:
			shield.enabled = true
			guard.texture = Gfx.tex("bosses/ice_shield2.png")
			guard.position = Vector2(31, 0)
			shield_shape.size = Vector2(14, 60)
			shield.position = Vector2(31, 0)
			_set_weak(EYE_IDLE, 9.0, true, true)
		3:
			shield.enabled = false
			guard.visible = false
			for pl in plates:
				pl["node"].visible = true
				pl["armor"].enabled = true
			_set_weak(EYE_IDLE, 10.0, false, true)

func _sync_mover() -> void:
	position += mover.position
	mover.position = Vector2.ZERO

func _turn_toward(target_angle: float, rate: float, delta: float) -> void:
	var diff := angle_difference(angle, target_angle)
	angle += clampf(diff, -rate * delta, rate * delta)
	pivot.rotation = angle

func _snap_side() -> void:
	angle = 0.0 if player.global_position.x >= global_position.x else PI
	pivot.rotation = angle
	_face_sprite()

func _dormant(delta: float) -> void:
	_turn_toward((player.global_position - global_position).angle(), 1.0, delta)
	_face_sprite()

func _on_start() -> void:
	_apply_phase(1)
	set_state("idle")

## Frozen arrows: whatever clanks off the guard, the plates or the body is encased in ice.
func _on_guard_clank(_pos: Vector2, _kind: String) -> void:
	if zone.arrow:
		zone.arrow.freeze(FREEZE_TIME)
	flash_sprite(sprite, 0.1)

func _on_armor_clank(pos: Vector2, kind: String) -> void:
	_on_guard_clank(pos, kind)

func _strike(size: Vector2, pos: Vector2, dur: float, g: int) -> bool:
	slash_hazard.set_size(size)
	slash_hazard.position = pos
	slash_hazard.active = true
	_play("strike")
	_squash(1.12, 0.94, 0.05)
	Fx.flash(zone.entities, global_position + Vector2.from_angle(angle) * 30.0 + Vector2(0, -8), Color("bfe4ff"), 12.0)
	Sfx.play("charge", -2.0, 1.6)
	var ok := await atk_wait(dur, g)
	slash_hazard.active = false
	_squash(1.0, 1.0, 0.2)
	return ok

func _recover(sec: float, g: int) -> bool:
	_play("recover", 0.5 / sec)
	return await atk_wait(sec, g)

# ------------------------------------------------------------------ state entry
func _enter(s: String) -> void:
	if s != "attack":
		weak_window = false
		track = false
		roll_dir = Vector2.ZERO
		pull = false
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE
		sprite.modulate.a = 1.0
		slash_hazard.active = false
	match s:
		"idle":
			turn_rate = P("turn")
			hazard.active = true
			body_armor.enabled = true
			if phase < 3:
				shield.enabled = true
				guard.modulate.a = 0.95
			for pl in plates:
				pl["armor"].enabled = phase == 3
				pl["node"].modulate = Color.WHITE
			plate_speed = 2.4
			if phase == 3:
				_set_weak(EYE_IDLE, 10.0, false, true)
		"evolve":
			hazard.active = false
			weak.armed = false
			for pl in plates:
				pl["armor"].enabled = false
			_play("carapace" if phase == 1 else "shatter", 1.0)
			Sfx.play("shatter")
			Sfx.play("roar", 2.0, 0.7)
			Game.hitstop(0.14)
			Game.add_trauma(1.0)
			zone.camera.punch(0.06, 0.6)

# ------------------------------------------------------------------ per-frame
func _tick(delta: float) -> void:
	_face_sprite()
	weak.position = _eye_offset()
	weak.armed = weak_window and _eye_open()
	body_armor.enabled = not weak.armed        # while the eye shows, arrows pass through the ice body to reach it
	var to_player := (player.global_position - global_position)
	if phase == 3:
		plate_ang += delta * plate_speed
		for i in plates.size():
			var a := plate_ang + TAU * i / plates.size()
			var n: Node2D = plates[i]["node"]
			n.position = Vector2.from_angle(a) * 32.0
			n.rotation = a
	match state:
		"idle":
			bob += delta * 8.0
			_turn_toward(to_player.angle(), turn_rate, delta)
			var speed: float = P("walk") if to_player.length() > 36.0 else 0.0
			mover.velocity = Vector2.from_angle(angle) * speed
			mover.move_and_slide()
			_sync_mover()
			sprite.position.y = sin(bob) * 0.8
			_play("walk" if speed > 0.0 and phase != 2 else _idle_anim(), 1.0)
			if t > P("gap"):
				start_attack(pick_attack())
		"attack":
			if track:
				_turn_toward(to_player.angle(), turn_rate, delta)
			if pull:
				var to_me := (global_position - player.global_position).normalized()
				player.move_and_collide(to_me * 44.0 * delta)
			if roll_dir != Vector2.ZERO:
				_tick_roll(delta)
		"evolve":
			sprite.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
			if t >= 1.0 and phase_pending > 0:
				var np := phase_pending
				phase_pending = 0
				_apply_phase(np)
				hazard.active = false
				weak.armed = false
				flash_sprite(sprite, 0.5)
				Sfx.play("stun", 0.0, 0.7)
				Sfx.play("crash")
				Game.add_trauma(1.0)
				Fx.burst(zone.entities, global_position, [Color("e0f8ff"), Color("6ad0ff")], 40, 150.0, 0.8, 3.0)
				RingFx.spawn(zone.entities, global_position, Color("a8e0ff"), 8, 110, 0.6, 4.0)
				Game.show_banner("THE KNIGHT " + ("SHATTERS" if np == 2 else "ASCENDS"), "PHASE %d" % np)
				Game.say(PHASE_TIPS[np], 6.0)
			if t >= 2.4:
				sprite.position = Vector2.ZERO
				set_state("idle")

func _tick_roll(delta: float) -> void:
	sprite.rotation += (1.0 if roll_dir.x >= 0.0 else -1.0) * 14.0 * delta
	var col := mover.move_and_collide(roll_dir * 330.0 * delta)
	_sync_mover()
	roll_trail -= delta
	if roll_trail <= 0.0:
		roll_trail = 0.09
		Fx.afterimage(zone.entities, sprite, Color(0.6, 0.85, 1.0, 0.4), 0.3)
		TimedHazard.spawn(zone.entities, global_position + Vector2(0, 8), 8.0, 1.7, Color("bfe4ff"))
	if col != null:
		Game.add_trauma(0.3)
		Sfx.play("crash", -4.0)
		Fx.debris(zone.entities, col.get_position(), [Color("e8f8ff"), Color("6ad0ff")], 10)
		roll_bounces += 1
		if roll_bounces > 2:
			roll_dir = Vector2.ZERO
		else:
			roll_dir = roll_dir.bounce(col.get_normal()).normalized()

# ------------------------------------------------------------------ PHASE 1 - GUARDIAN
func _atk_lance(g: int) -> void:
	_snap_side()
	_play("windup", 0.6 / 0.5)
	_squash(0.95, 1.06, 0.4)
	Fx.charge(zone.entities, global_position + Vector2(0, -12), Color("bfe4ff"), 0.5, 26.0)
	Sfx.play("telegraph", -4.0, 1.3)
	if not await atk_wait(0.5, g): return
	Atk.shot(zone, global_position + Vector2.from_angle(angle) * 30.0 + Vector2(0, -6), Vector2.from_angle(angle), 240.0, "bosses/ice_shard.png", 5.0, 2.6)
	if not await _strike(Vector2(80, 26), Vector2(48, 4), 0.24, g): return
	await _recover(0.5, g)

func _atk_icicle_clap(g: int) -> void:
	_play("raise", 1.4)
	_squash(0.97, 1.05, 0.55)                                 # both arms up...
	Fx.charge(zone.entities, global_position + Vector2(0, -24), Color("cfeaff"), 0.6, 34.0)
	Sfx.play("telegraph", -4.0, 0.9)
	if not await atk_wait(0.6, g): return
	_play("clap")
	_squash(1.2, 0.82, 0.06)                                  # ...and the clap
	Fx.flash(zone.entities, global_position + Vector2(0, -14), Color("ffffff"), 22.0)
	Game.add_trauma(0.4)
	Sfx.play("shatter", -2.0, 0.9)
	var pl := player
	for i in 8:
		var p: Vector2 = pl.global_position + pl.velocity * 0.5 if i == 0 else pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 110.0)
		Atk.blast(zone, Atk.clamp_in(zone, p), 15.0, 1.0 + 0.07 * i, Color("bfe4ff"), "bosses/icicle_fall.png", "fall", 0.25)
	if not await atk_wait(0.4, g): return
	await _recover(0.7, g)

func _atk_ice_wall(g: int) -> void:
	track = true
	_play("raise", 1.2)
	_squash(0.95, 1.06, 0.5)
	Sfx.play("telegraph", -4.0, 0.8)
	if not await atk_wait(0.6, g): return
	track = false
	_play("strike")
	_squash(1.15, 0.86, 0.06)
	var d := (player.global_position - global_position).normalized()
	var perp := d.rotated(PI / 2.0)
	for k in [-1, 0, 1]:
		IceSlab.spawn(zone, Atk.clamp_in(zone, global_position + d * 60.0 + perp * k * 22.0), 7.5)
	Game.add_trauma(0.3)
	if not await atk_wait(0.3, g): return
	await _recover(0.7, g)

func _atk_slam(g: int) -> void:
	_play("raise", 0.9)
	_squash(0.92, 1.1, 0.7)
	Fx.charge(zone.entities, global_position + Vector2(0, -30), Color("bfe4ff"), 0.75, 42.0)
	Sfx.play("telegraph", -2.0, 0.7)
	Sfx.play("roar", -4.0, 0.9)
	if not await atk_wait(0.75, g): return
	_play("strike")
	_squash(1.22, 0.78, 0.06)
	Sfx.play("slam")
	Game.hitstop(0.06)
	Game.add_trauma(0.9)
	zone.camera.punch(0.04, 0.3)
	Fx.debris(zone.entities, global_position, [Color("e8f8ff"), Color("6ad0ff")], 20)
	var r := RingHazard.spawn(zone.entities, global_position + Vector2(0, 10), Color("bfe4ff"))
	r.expand(105.0, 0.75)
	if not await atk_wait(0.3, g): return
	# the fist is stuck in the ice: the guard drops and the eye shows
	shield.enabled = false
	guard.modulate.a = 0.35
	weak_window = true
	_play("kneel")
	Sfx.play("stun")
	if not await atk_wait(1.9, g): return
	weak_window = false
	shield.enabled = true
	guard.modulate.a = 0.95
	await _recover(0.4, g)

# ------------------------------------------------------------------ PHASE 2 - CARAPACE
func _atk_roll(g: int) -> void:
	_play("carapace", 1.6)
	Sfx.play("telegraph", -2.0, 1.1)
	if not await atk_wait(0.55, g): return
	roll_dir = (player.global_position - global_position).normalized()
	roll_bounces = 0
	Sfx.play("charge", 0.0, 0.9)
	if not await atk_wait(1.5, g): return
	roll_dir = Vector2.ZERO
	sprite.rotation = 0.0
	await _recover(0.6, g)

func _atk_blizzard(g: int) -> void:
	_play("carapace", 1.4)
	Sfx.play("roar", -2.0, 0.7)
	if not await atk_wait(0.5, g): return
	pull = true
	for i in 5:
		Atk.fan(zone, global_position + Vector2(0, -8), (player.global_position - global_position).angle(), 5, 0.75, 150.0, "bosses/ice_shard.png", 5.0, 4.0)
		Sfx.play("orb", -6.0, 1.4)
		if not await atk_wait(0.62, g): return
	pull = false
	await _recover(0.6, g)

func _atk_spike_line(g: int) -> void:
	track = true
	_play("windup", 0.6 / 0.65)
	_squash(1.1, 0.88, 0.5)
	Sfx.play("telegraph", -2.0, 0.9)
	if not await atk_wait(0.65, g): return
	track = false
	_play("strike")
	Game.add_trauma(0.5)
	var d := (player.global_position - global_position).normalized()
	Atk.line_blasts(zone, global_position, d, 11, 22.0, 13.0, 0.35, 0.07, ICE, "bosses/ice_spike.png", "rise")
	if not await atk_wait(0.7, g): return
	for s in [-0.42, 0.42]:
		Atk.line_blasts(zone, global_position, d.rotated(s), 10, 22.0, 13.0, 0.3, 0.07, ICE, "bosses/ice_spike.png", "rise")
	if not await atk_wait(0.9, g): return
	await _recover(0.7, g)

func _atk_roar(g: int) -> void:
	_play("carapace", 1.0)
	_squash(1.14, 1.14, 0.2)
	Fx.charge(zone.entities, global_position + Vector2(0, -20), Color("ffffff"), 0.5, 50.0)
	Sfx.play("roar", 2.0, 0.6)
	Game.hitstop(0.05)
	Game.add_trauma(0.8)
	weak_window = true                   # the eye only shows on the carapace frames 1-3
	var r := RingHazard.spawn(zone.entities, global_position + Vector2(0, 10), Color("bfe4ff"))
	r.expand(115.0, 0.95)
	for i in 6:
		var p := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 100.0)
		Atk.blast(zone, Atk.clamp_in(zone, p), 15.0, 1.0 + 0.1 * i, Color("bfe4ff"), "bosses/icicle_fall.png", "fall", 0.25)
	if not await atk_wait(1.7, g): return
	weak_window = false
	await _recover(0.5, g)

# ------------------------------------------------------------------ PHASE 3 - PRISM
func _atk_beam(g: int) -> void:
	track = true
	turn_rate = 3.0
	_play("windup", 0.6 / 0.95)
	Sfx.play("telegraph", 0.0, 0.8)
	if not await atk_wait(0.6, g): return
	track = false
	if not await atk_wait(0.35, g): return
	_play("strike")
	var segs := BeamShot.compute(self, global_position, Vector2.from_angle(angle), 1)
	BeamShot.fire(zone.entities, segs, 7.0, 0.5)
	Sfx.play("beam")
	Game.add_trauma(0.4)
	for s in segs:
		Fx.sparks(zone.entities, s[1], 8)
	if not await atk_wait(0.5, g): return
	# recoil: the plates go dark, the guardian staggers, its eye opens to a RECALLED arrow
	for pl in plates:
		pl["armor"].enabled = false
		pl["node"].modulate = Color(0.4, 0.4, 0.5)
	plate_speed = 0.6
	_set_weak(EYE_IDLE, 10.0, false, true)
	weak_window = true
	_play("kneel")
	Sfx.play("stun")
	Game.add_trauma(0.4)
	if not await atk_wait(1.7, g): return
	weak_window = false
	plate_speed = 2.4
	for pl in plates:
		pl["armor"].enabled = true
		pl["node"].modulate = Color.WHITE

func _atk_plates_volley(g: int) -> void:
	_play("windup", 1.2)
	Sfx.play("telegraph", -2.0, 1.4)
	plate_speed = 6.0
	if not await atk_wait(0.5, g): return
	for k in 4:
		Sfx.play("orb", -4.0, 1.5)
		for i in plates.size():
			var pn: Node2D = plates[i]["node"]
			var out := (pn.global_position - global_position).angle()
			Atk.fan(zone, pn.global_position, out, 3, 0.5, 125.0 + 10.0 * k, "bosses/ice_shard.png", 4.0, 5.0)
		if not await atk_wait(0.5, g): return
	plate_speed = 2.4
	await _recover(0.4, g)

func _atk_absolute_zero(g: int) -> void:
	_play("carapace", 1.4)
	Sfx.play("roar", 2.0, 0.5)
	Game.add_trauma(0.8)
	Game.hitstop(0.05)
	for i in 20:
		var a := i * 0.62
		var rad := 26.0 + i * 8.5
		var p := global_position + Vector2.from_angle(a) * rad
		Atk.blast(zone, Atk.clamp_in(zone, p), 14.0, 0.9 + i * 0.11, Color("cfeaff"), "bosses/icicle_fall.png", "fall", 0.25)
	if not await atk_wait(3.2, g): return
	await _recover(0.5, g)

func _atk_shatter_dash(g: int) -> void:
	sprite.modulate.a = 0.0
	Fx.burst(zone.entities, global_position, [Color("ffffff"), Color("8fd0ff")], 22, 120.0, 0.5, 2.0)
	Sfx.play("shatter", 0.0, 1.5)
	hazard.active = false
	if not await atk_wait(0.35, g): return
	var side := -1.0 if player.global_position.x > global_position.x else 1.0
	var target := Atk.clamp_in(zone, player.global_position + Vector2(46.0 * side, 0.0))
	Fx.afterimage(zone.entities, sprite, Color(0.7, 0.9, 1.0, 0.5), 0.5)
	global_position = target
	sprite.modulate.a = 1.0
	hazard.active = true
	Fx.burst(zone.entities, global_position, [Color("ffffff"), Color("8fd0ff")], 22, 120.0, 0.5, 2.0)
	_snap_side()
	_play("windup", 1.5)
	Sfx.play("telegraph", -2.0, 1.6)
	if not await atk_wait(0.4, g): return
	Atk.shot(zone, global_position + Vector2.from_angle(angle) * 30.0 + Vector2(0, -6), Vector2.from_angle(angle), 280.0, "bosses/ice_shard.png", 5.0, 2.2)
	if not await _strike(Vector2(84, 28), Vector2(50, 4), 0.24, g): return
	await _recover(0.35, g)

# ------------------------------------------------------------------ hits
func _on_weak_struck(_kind: String) -> void:
	if phase < 3:
		phase_pending = phase + 1
		set_state("evolve")
	else:
		kill()

func _death_sequence() -> void:
	_death_by_animation(sprite, "death", [Color("e0f8ff"), Color("6ad0ff")])
