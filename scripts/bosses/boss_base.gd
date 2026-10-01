class_name BossBase
extends Node2D
## Shared boss architecture: state machine helpers, hazard/weak-point/armour factories, death sequence.
## Standard states: idle, telegraph, attack, recovery, stunned, exposed, dead (bosses may add more).

signal defeated

var zone: Zone
var player: Player
var arrow: Arrow
var state := "idle"
var t := 0.0
var active := false
var dead := false
var sprites: Array[CanvasItem] = []

func setup(z: Zone) -> void:
	zone = z
	player = z.player
	arrow = z.arrow
	_build()

## Override: create sprites, hazards, weak points.
func _build() -> void:
	pass

func start_fight() -> void:
	active = true
	_on_start()

func _on_start() -> void:
	set_state("idle")

func set_state(s: String) -> void:
	if s != "attack":
		atk_gen += 1
	state = s
	t = 0.0
	_enter(s)

func _enter(_s: String) -> void:
	pass

func _physics_process(delta: float) -> void:
	if dead or player == null or player.dead:
		return
	t += delta
	if not active:
		_dormant(delta)
		return
	_tick(delta)

func _dormant(_delta: float) -> void:
	pass

func _tick(_delta: float) -> void:
	pass

# ------------------------------------------------------------------ attack framework
## Each boss lists its attacks per phase in `attack_list()`. The lists are disjoint: no attack is reused in another phase.
## An attack is an async function `_atk_<name>(g)`; after every await it must check `atk_wait(...)` so a phase change, death
## or hit-stun can cancel it (atk_gen is bumped whenever the state machine leaves "attack").
var atk_gen := 0
var last_attack := ""
var _bag: Array = []

func attack_list() -> Array:
	return []

func all_attacks() -> Dictionary:
	return {}

func pick_attack() -> String:
	if _bag.is_empty():
		_bag = attack_list().duplicate()
		_bag.shuffle()
		if _bag.size() > 1 and _bag[0] == last_attack:
			_bag.append(_bag.pop_front())
	return _bag.pop_front()

func reset_attacks() -> void:
	_bag = []
	atk_gen += 1

## true while the attack that called it is still the current one
func atk_wait(sec: float, g: int) -> bool:
	await get_tree().create_timer(sec).timeout
	return atk_ok(g)

func atk_ok(g: int) -> bool:
	return g == atk_gen and not dead and is_inside_tree() and active

func start_attack(attack_name: String) -> void:
	atk_gen += 1
	var g := atk_gen
	last_attack = attack_name
	set_state("attack")
	await call("_atk_" + attack_name, g)
	if atk_ok(g) and state == "attack":
		_attack_done(attack_name)

func _attack_done(_attack_name: String) -> void:
	set_state("idle")

# ------------------------------------------------------------------ factories
func add_sprite(path: String, pos := Vector2.ZERO) -> Sprite2D:
	var s := Gfx.sprite(path, pos)
	add_child(s)
	sprites.append(s)
	return s

func add_hazard_circle(r: float, pos := Vector2.ZERO, on := true) -> Hazard:
	var h := Hazard.circle(r, pos)
	add_child(h)
	h.active = on
	return h

func add_hazard_box(size: Vector2, pos := Vector2.ZERO, on := true) -> Hazard:
	var h := Hazard.box(size, pos)
	add_child(h)
	h.active = on
	return h

func add_weak(r: float, pos := Vector2.ZERO, fly := true, ret := true) -> WeakPoint:
	var w := WeakPoint.make(r, pos, fly, ret)
	add_child(w)
	w.struck.connect(_on_weak_struck)
	return w

func add_armor_circle(r: float, pos := Vector2.ZERO, fly := Armor.Mode.DROP, ret := Armor.Mode.DROP) -> Armor:
	var a := Armor.make_circle(r, pos, fly, ret)
	add_child(a)
	a.clanked.connect(_on_armor_clank)
	return a

func _on_weak_struck(_kind: String) -> void:
	kill()

func _on_armor_clank(_pos: Vector2, _kind: String) -> void:
	pass

func player_dir() -> Vector2:
	return (player.global_position + Vector2(0, -6) - global_position).normalized()

func player_dist() -> float:
	return player.global_position.distance_to(global_position)

func flash_sprite(s: CanvasItem, dur := 0.12) -> void:
	s.modulate = Color(3, 3, 3)
	create_tween().tween_property(s, "modulate", Color.WHITE, dur)

func wall_distance(from: Vector2, dir: Vector2, max_len := 500.0) -> float:
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * max_len, L.WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return max_len
	return from.distance_to(r["position"])

# ------------------------------------------------------------------ death
func kill() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	_on_death_begin()
	Game.hitstop(0.16)
	Game.slowmo(0.22, 1.7)
	Game.add_trauma(1.0)
	if zone.camera:
		zone.camera.punch(0.07, 0.7)
	Sfx.play("boss_death")
	defeated.emit()
	_death_sequence()

func _on_death_begin() -> void:
	for h in find_children("*", "Hazard", true, false):
		h.active = false
	for w in find_children("*", "WeakPoint", true, false):
		w.armed = false
	for pr in get_tree().get_nodes_in_group("projectile"):
		Fx.burst(zone.entities, pr.global_position, [Color("ffffff"), Color("ffb040")], 5, 50.0, 0.3, 2.0)
		pr.queue_free()

func _death_sequence() -> void:
	for s in sprites:
		s.modulate = Color(4, 4, 4)
	for i in 14:
		var off := Vector2(randf_range(-22, 22), randf_range(-22, 22))
		Fx.death_burst(zone.entities, global_position + off) if i % 5 == 0 else Fx.burst(zone.entities, global_position + off, [Color("ffe9a8"), Color("ff7a30")], 14, 120.0, 0.7, 2.0, 60.0)
		for s in sprites:
			if is_instance_valid(s):
				s.position += Vector2(randf_range(-1, 1), randf_range(-1, 1))
		Game.add_trauma(0.15)
		await get_tree().create_timer(0.11, true, false, true).timeout
		if not is_inside_tree():
			return
		if i == 6:
			for s in sprites:
				if is_instance_valid(s):
					create_tween().tween_property(s, "modulate", Color(1, 1, 1, 0), 0.9)
	_arena_reaction()
	Fx.death_burst(zone.entities, global_position)
	for s in sprites:
		if is_instance_valid(s):
			s.visible = false

## Death that plays a sprite-sheet animation (instead of the white flash) while the usual bursts and shake run.
func _death_by_animation(spr: AnimatedSprite2D, anim: String, burst_cols: Array) -> void:
	spr.rotation = 0.0
	spr.self_modulate = Color.WHITE
	spr.speed_scale = 1.0
	spr.play(anim)
	var home := spr.position
	for i in 14:
		var off := Vector2(randf_range(-22, 22), randf_range(-22, 22))
		Fx.death_burst(zone.entities, global_position + off) if i % 5 == 0 else Fx.burst(zone.entities, global_position + off, burst_cols, 14, 120.0, 0.7, 2.0, 60.0)
		spr.position = home + Vector2(randf_range(-1, 1), randf_range(-1, 1))
		Game.add_trauma(0.15)
		await get_tree().create_timer(0.11, true, false, true).timeout
		if not is_inside_tree():
			return
		if i == 9:
			create_tween().tween_property(spr, "modulate", Color(1, 1, 1, 0), 0.5)
	_arena_reaction()
	Fx.death_burst(zone.entities, global_position)
	spr.visible = false

## Override for arena-specific death reactions.
func _arena_reaction() -> void:
	Game.add_trauma(0.6)
	for b in zone.entities.get_children():
		if b.has_method("shatter") and b is Pillar and not b.broken:
			b.breakable = true
			b.shatter()
