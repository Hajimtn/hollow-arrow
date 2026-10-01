class_name Lair
extends Node2D
## A boss lair that fights back. Each biome changes how the player moves or how the arrow behaves, and drops its own hazards:
##   crystal   FROZEN VAULT      slippery ice floor; icicles fall from the ceiling
##   colossus  FOUNDRY           lava fissures erupt in the floor
##   sky       AERIE             a shifting gale pushes the player and bends the arrow's flight
##   burrow    CANDLELIT CRYPT   dark; four lanterns (arrow-lit). The Executioner is a ghost: arrows pass through it unless they have
##                       flown through lantern light (a BLESSED arrow). Its wisps snuff the lanterns.
##   twins     OBSERVATORY       sun half speeds the arrow up, moon half slows it and its recall
##   courtyard RUNE SANCTUM      rune pads detonate; the central circle refills stamina
##   final     THE NEXUS         four elemental quadrants (fire / ice / earth / storm) wake in turn: their tiles light up, then
##                       lava vents, icicles + slippery ice, stone spikes or lightning strike inside them
## Everything is strongest from the first second (no warm-up) and the pace rises with the boss's phase.

var zone: Zone
var kind := ""
var phase := 1
var active := false
var t := 0.0
var timer := 2.0
var wind := Vector2.ZERO
var wind_angle := 0.0
var wind_target := 0.0
var wind_timer := 3.0
var lanterns: Array = []          # {sw, light, t, holder}
var dark: CanvasModulate
var player_light: PointLight2D
var sites: Array = []
var rng := RandomNumberGenerator.new()
var quads: Array = []             # the Nexus: {name, cells, awake_t, idx}

func setup(z: Zone, k: String) -> void:
	zone = z
	kind = k
	rng.seed = 91
	match kind:
		"burrow":
			_setup_crypt()
		"colossus":
			for y in z.h:
				for x in z.w:
					if z.ch_at(x, y) == ":":
						sites.append(z.cell_center(x, y))
		"final":
			_setup_nexus()
		"courtyard":
			var c := Vector2(z.w * 8.0, z.h * 8.0 + 4.0)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				sites.append(c + Vector2(cos(a) * 118.0, sin(a) * 66.0))
	queue_redraw()

func start() -> void:
	active = true
	timer = 1.4
	if kind == "burrow" and lanterns.size() >= 2:
		_light(lanterns[0])
		_light(lanterns[lanterns.size() - 1])

func stop() -> void:
	active = false
	_reset_player()

func set_phase(p: int) -> void:
	phase = clampi(p, 1, 3)

func _exit_tree() -> void:
	_reset_player()

func _reset_player() -> void:
	if zone and is_instance_valid(zone.player):
		zone.player.speed_mult = 1.0
		zone.player.accel_mult = 1.0
		zone.player.friction_mult = 1.0
	if zone and is_instance_valid(zone.arrow):
		zone.arrow.wind = Vector2.ZERO
		zone.arrow.fly_mult = 1.0
		zone.arrow.ret_mult = 1.0

func _physics_process(delta: float) -> void:
	t += delta
	var pl: Player = zone.player
	var ar: Arrow = zone.arrow
	if pl == null or pl.dead:
		return
	match kind:
		"crystal":
			pl.friction_mult = 0.07
			pl.accel_mult = 0.28
			if active:
				timer -= delta
				if timer <= 0.0:
					timer = maxf(1.3, 3.3 - 0.6 * phase)
					_icicles()
		"colossus":
			if active:
				timer -= delta
				if timer <= 0.0 and not sites.is_empty():
					timer = maxf(1.3, 3.0 - 0.5 * phase)
					_geysers()
		"sky":
			wind_timer -= delta
			if wind_timer <= 0.0:
				wind_timer = rng.randf_range(3.5, 6.0)
				wind_target = rng.randf() * TAU
			wind_angle = lerp_angle(wind_angle, wind_target, delta * 0.8)
			var strength: float = [46.0, 66.0, 92.0][phase - 1]
			wind = Vector2.from_angle(wind_angle) * strength
			if zone.ambience:
				zone.ambience.wind = wind
			if active and not pl.locked:
				pl.move_and_collide(wind * 0.55 * delta)
			ar.wind = wind * 3.6
		"burrow":
			_tick_crypt(delta, ar)
		"twins":
			var sun := ar.global_position.x < zone.w * 8.0
			ar.fly_mult = 1.4 if sun else 0.68
			ar.ret_mult = 1.25 if sun else 0.6
		"final":
			_tick_nexus(delta, pl)
		"courtyard":
			var c := Vector2(zone.w * 8.0, zone.h * 8.0 + 4.0)
			if pl.global_position.distance_to(c) < 34.0:
				pl.stamina = minf(Player.STAMINA_MAX, pl.stamina + 44.0 * delta)
			if active:
				timer -= delta
				if timer <= 0.0:
					timer = maxf(1.4, 3.2 - 0.5 * phase)
					_rune_pads()

func _icicles() -> void:
	var pl := zone.player
	var n := 2 + phase
	for i in n:
		var p: Vector2
		if i == 0:
			p = pl.global_position + pl.velocity * 0.45          # on ice the player keeps sliding: aim where they will be
		else:
			p = pl.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 95.0)
		Atk.blast(zone, Atk.clamp_in(zone, p), 15.0, 1.05, Color("bfe4ff"), "bosses/icicle_fall.png", "fall", 0.25)

func _geysers() -> void:
	var pl := zone.player
	var pool := sites.duplicate()
	pool.sort_custom(func(a, b): return a.distance_to(pl.global_position) < b.distance_to(pl.global_position))
	var n := 2 + phase
	for i in mini(n, pool.size()):
		var p: Vector2 = pool[i] if i < 2 else pool[rng.randi() % pool.size()]
		Atk.blast(zone, p, 17.0, 1.0, Color("ef6a2a"), "bosses/flame_col.png", "rise", 0.7)

func _rune_pads() -> void:
	var pool := sites.duplicate()
	pool.shuffle()
	for i in 1 + phase:
		Atk.blast(zone, pool[i], 24.0, 1.25, Color("5fe0e0"), "bosses/stone_spike.png", "rise", 0.55)

func _draw() -> void:
	if kind == "courtyard":
		for s2 in sites:
			draw_arc(s2, 20.0, 0.0, TAU, 28, Color(0.37, 0.88, 0.88, 0.55), 1.0)
			draw_arc(s2, 12.0, 0.0, TAU, 20, Color(0.37, 0.88, 0.88, 0.35), 1.0)

# ------------------------------------------------------------------ candlelit crypt
const LIT_TIME := [16.0, 11.0, 8.0]
const POOL_R := 48.0

static func _light_texture() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t

func _setup_crypt() -> void:
	dark = CanvasModulate.new()
	dark.color = Color(0.36, 0.36, 0.52)
	zone.add_child(dark)
	var tex := _light_texture()
	for pos in zone.marks.get("l", []):
		var holder := Node2D.new()
		holder.position = pos + Vector2(0, 8)
		zone.entities.add_child(holder)
		var sw := RuneSwitch.make(9.0, "environment/lantern_off.png", "environment/lantern_on.png")
		sw.one_shot = false
		sw.sprite.position = Vector2(0, 20)
		sw.position = Vector2(0, -20)
		holder.add_child(sw)
		var l := PointLight2D.new()
		l.texture = tex
		l.texture_scale = POOL_R / 64.0 * 1.15
		l.energy = 1.5
		l.color = Color(1.0, 0.82, 0.5)
		l.position = Vector2(0, -6)
		l.enabled = false
		holder.add_child(l)
		var entry := {"sw": sw, "light": l, "t": 0.0, "holder": holder}
		sw.struck.connect(_on_lantern.bind(entry))
		lanterns.append(entry)
	# a small lamp of the player's own so the floor under their feet is never black
	player_light = PointLight2D.new()
	player_light.texture = tex
	player_light.texture_scale = 0.3
	player_light.energy = 0.85
	player_light.color = Color(0.7, 0.8, 1.0)
	player_light.position = Vector2(0, -8)
	zone.player.add_child(player_light)

func _on_lantern(_sw: RuneSwitch, entry: Dictionary) -> void:
	_light(entry)

func _light(entry: Dictionary) -> void:
	entry["t"] = LIT_TIME[phase - 1]
	entry["sw"].set_on(true)
	entry["light"].enabled = true
	Fx.sparks(zone.entities, entry["holder"].global_position + Vector2(0, -20), 8)

func _snuff(entry: Dictionary) -> void:
	if entry["t"] <= 0.0:
		return
	entry["t"] = 0.0
	entry["sw"].set_on(false)
	entry["light"].enabled = false
	Fx.burst(zone.entities, entry["holder"].global_position + Vector2(0, -20), [Color("6a6a80"), Color("2a2a3a")], 8, 30.0, 0.6, 2.0, -20.0)
	Sfx.play("shatter", -12.0, 0.6)

## centres of the lanterns that are lit right now
func lit_positions() -> Array:
	var out := []
	for e in lanterns:
		if e["t"] > 0.0:
			out.append(e["holder"].global_position + Vector2(0, -8))
	return out

func in_light(p: Vector2) -> bool:
	for pos in lit_positions():
		if p.distance_to(pos) < POOL_R:
			return true
	return false

func _tick_crypt(delta: float, ar: Arrow) -> void:
	var wisps := get_tree().get_nodes_in_group("wisp")
	for e in lanterns:
		if e["t"] <= 0.0:
			continue
		e["t"] -= delta
		var flick := 0.9 + 0.1 * sin(t * 13.0 + e["holder"].position.x)
		e["light"].energy = 1.5 * flick * (1.0 if e["t"] > 2.0 else clampf(e["t"] / 2.0, 0.2, 1.0))
		if e["t"] <= 0.0:
			_snuff_forced(e)
			continue
		for w in wisps:
			if is_instance_valid(w) and (w as Node2D).global_position.distance_to(e["holder"].global_position + Vector2(0, -14)) < 16.0:
				_snuff(e)
				w.queue_free()
				break
	if ar.state != Arrow.State.HELD and in_light(ar.global_position):
		ar.blessed_t = 3.0

func _snuff_forced(entry: Dictionary) -> void:
	entry["t"] = 0.0
	entry["sw"].set_on(false)
	entry["light"].enabled = false

# ------------------------------------------------------------------ the Nexus (final arena)
const NEXUS_ACTIVE := {1: ["fire", "earth"], 2: ["ice", "storm"], 3: ["fire", "ice", "earth", "storm"]}

func _setup_nexus() -> void:
	var chars := {"f": 0, "i": 1, "e": 2, "s": 3}
	var names := ["fire", "ice", "earth", "storm"]
	for k in 4:
		quads.append({"name": names[k], "cells": [], "awake_t": 0.0, "idx": k})
	for y in zone.h:
		for x in zone.w:
			var ch := zone.ch_at(x, y)
			if chars.has(ch):
				quads[chars[ch]]["cells"].append(Vector2i(x, y))

func _quad(name: String) -> Dictionary:
	for q in quads:
		if q["name"] == name:
			return q
	return {}

func _wake(q: Dictionary) -> void:
	q["awake_t"] = 3.8
	for c in q["cells"]:
		zone.set_floor_tile(c, 16 + int(q["idx"]))
	Sfx.play("stun", -10.0, 0.7 + 0.15 * int(q["idx"]))
	var pl := zone.player
	var cells: Array = q["cells"]
	var picks := []
	for i in 7:
		var cc: Vector2i = cells[rng.randi() % cells.size()]
		picks.append(zone.cell_center(cc.x, cc.y))
	picks.sort_custom(func(a, b): return a.distance_to(pl.global_position) < b.distance_to(pl.global_position))
	var n := 5 + phase
	for i in mini(n, picks.size()):
		var p: Vector2 = picks[i] if i < 2 else picks[rng.randi() % picks.size()]
		match q["name"]:
			"fire":
				Atk.blast(zone, p, 17.0, 1.25 + 0.08 * i, Color("ef6a2a"), "bosses/flame_col.png", "rise", 0.7)
			"ice":
				Atk.blast(zone, p, 15.0, 1.25 + 0.08 * i, Color("bfe4ff"), "bosses/icicle_fall.png", "fall", 0.25)
			"earth":
				Atk.blast(zone, p, 15.0, 1.25 + 0.08 * i, Color("c09a4a"), "bosses/stone_spike.png", "rise", 0.5)
			"storm":
				Atk.blast(zone, p, 20.0, 1.25 + 0.08 * i, Color("fff0a0"), "bosses/bolt.png", "rise", 0.3)

func _sleep(q: Dictionary) -> void:
	q["awake_t"] = 0.0
	for c in q["cells"]:
		zone.set_floor_tile(c, 12 + int(q["idx"]))

func _tick_nexus(delta: float, pl: Player) -> void:
	var ice := _quad("ice")
	var on_ice := false
	for q in quads:
		if q["awake_t"] > 0.0:
			q["awake_t"] -= delta
			if q["awake_t"] <= 0.0:
				_sleep(q)
	if not ice.is_empty() and ice["awake_t"] > 0.0:
		var pc := Vector2i(int(pl.global_position.x / 16.0), int(pl.global_position.y / 16.0))
		on_ice = ice["cells"].has(pc)
	pl.friction_mult = 0.07 if on_ice else 1.0
	pl.accel_mult = 0.28 if on_ice else 1.0
	if not active:
		return
	timer -= delta
	if timer <= 0.0:
		timer = maxf(1.5, 3.4 - 0.45 * phase)
		var pool: Array = []
		for n in NEXUS_ACTIVE[phase]:
			var q := _quad(n)
			if q["awake_t"] <= 0.0:
				pool.append(q)
		pool.shuffle()
		for i in mini(2 if phase == 3 else 1, pool.size()):
			_wake(pool[i])
