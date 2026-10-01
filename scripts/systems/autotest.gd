extends Node
## Scripted playtest harness. Active only with:  godot --path . -- --autotest=<scenario> [--shots=<dir>]
## Scenarios drive the real game (real input actions, real physics) and print PASS/FAIL lines.

var enabled := false
var scenario := ""
var shots_dir := ""
var main: Node
var results: Array = []
var fails := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			scenario = a.substr(11)
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if scenario == "":
		return
	enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

# ------------------------------------------------------------------ helpers
func _run() -> void:
	await get_tree().process_frame
	main = get_tree().root.get_node("Main")
	Sfx.apply_volumes()
	AudioServer.set_bus_mute(0, true)
	Game.new_game()
	Game.playing = true
	main.state = "play"
	print("[autotest] scenario=", scenario)
	if has_method("sc_" + scenario):
		await call("sc_" + scenario)
	else:
		print("[autotest] unknown scenario")
	print("[autotest] DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		fails += 1
		print("  FAIL  ", msg)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func wait(sec: float) -> void:
	await frames(int(sec * 60.0))

func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots_dir)
	img.save_png("%s/%s.png" % [shots_dir, name])

func go(zone_id: String, entry := "start") -> void:
	await main._load_zone(zone_id, entry, 0.05)
	await frames(6)

func zone() -> Zone:
	return main.zone

func player() -> Player:
	return main.zone.player

func tp(pos: Vector2) -> void:
	player().global_position = pos
	player().velocity = Vector2.ZERO
	zone().camera.reset_smoothing()

func hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)

func aim_at(p: Vector2) -> void:
	Game.aim_override = p

func tap(action: String, sec := 0.05) -> void:
	Input.action_press(action)
	await wait(sec)
	Input.action_release(action)
	await frames(2)

func shoot_at(p: Vector2) -> void:
	aim_at(p)
	await tap("shoot", 0.05)

func recall(hold_sec := 1.2) -> void:
	Input.action_press("recall")
	await wait(hold_sec)
	Input.action_release("recall")
	await frames(2)

func arrow() -> Arrow:
	return zone().arrow

func boss() -> BossBase:
	return zone().boss

## make the player unkillable for bot runs that test mechanics rather than dodging
## pick a spot ~dist px from `target` that is inside the arena with an unobstructed line to it
func weak_side_pos(center: Vector2, target: Vector2, dist := 70.0) -> Vector2:
	var space := get_viewport().world_2d.direct_space_state
	var base := (target - center).normalized()
	for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var p: Vector2 = target + base.rotated(ang) * dist
		if p.x < 40 or p.y < 50 or p.x > zone().w * 16 - 40 or p.y > zone().h * 16 - 30:
			continue
		var q := PhysicsRayQueryParameters2D.create(p, target, L.WORLD)
		if space.intersect_ray(q).is_empty():
			return p
	return target + base * dist

func clear_shot_pos(target: Vector2, dist := 70.0) -> Vector2:
	var space := get_viewport().world_2d.direct_space_state
	var best := target + Vector2(0, dist)
	for off in [Vector2(dist, 0), Vector2(-dist, 0), Vector2(0, dist), Vector2(0, -dist), Vector2(dist, dist) * 0.7, Vector2(-dist, dist) * 0.7]:
		var p: Vector2 = target + off
		if p.x < 40 or p.y < 50 or p.x > zone().w * 16 - 40 or p.y > zone().h * 16 - 30:
			continue
		var q := PhysicsRayQueryParameters2D.create(p, target, L.WORLD)
		if space.intersect_ray(q).is_empty():
			return p
	return best

func god(on := true) -> void:
	player().invulnerable = on

func wait_until(cond: Callable, timeout := 10.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return false

## walk the player a little north so the arena fight begins, like a real player would
func begin_fight() -> void:
	hold("move_up", true)
	await wait_until(func(): return main.zone != null and main.zone.fight_started, 4.0)
	hold("move_up", false)
	await wait(0.3)

# ------------------------------------------------------------------ scenarios
func sc_look() -> void:
	for id in ["hub", "path_warden", "path_knight", "path_burrower", "path_colossus", "path_hunter", "path_twins", "path_regent",
			"arena_warden", "arena_knight", "arena_burrower", "arena_colossus", "arena_hunter", "arena_twins", "arena_regent"]:
		await go(id, "start" if not id.begins_with("path") else "from_hub")
		await wait(0.6)
		await shot(id)
		if id.begins_with("path"):
			tp(zone().mark("a") + Vector2(0, 20))
			await wait(0.6)
			await shot(id + "_end")

func sc_smoke() -> void:
	await go("hub")
	check(zone() != null, "hub loads")
	check(Arrow.live_count == 1, "exactly one arrow (%d)" % Arrow.live_count)
	var p := player()
	var start := p.global_position
	hold("move_up", true)
	await wait(0.5)
	hold("move_up", false)
	check(p.global_position.y < start.y - 20.0, "player moves up")
	# shoot & recall
	aim_at(p.global_position + Vector2(100, 0))
	await tap("shoot")
	await wait(0.1)
	check(arrow().state == Arrow.State.FLYING, "arrow flies")
	await tap("shoot")
	check(Arrow.live_count == 1, "still one arrow after second click")
	await wait(1.2)
	check(arrow().state == Arrow.State.GROUND or arrow().state == Arrow.State.STUCK, "arrow landed")
	await recall(1.5)
	check(arrow().state == Arrow.State.HELD, "arrow recalled")
	# dodge
	hold("move_right", true)
	await tap("dodge", 0.05)
	await wait(0.1)
	check(p.dodging > 0.0 or p.dodge_cd > 0.0, "dodge triggers")
	hold("move_right", false)

## put the player right behind the unbroken pillar nearest the boss so its charge crashes into it
func bait_pillar(b: BossBase) -> void:
	var best: Node2D = null
	for p in zone().pillars:
		if is_instance_valid(p) and not p.broken:
			if best == null or p.global_position.distance_to(b.global_position) < best.global_position.distance_to(b.global_position):
				best = p
	if best != null:
		var d: Vector2 = (best.global_position - b.global_position).normalized()
		tp(best.global_position + Vector2(0, -6) + d * 30.0)

func sc_warden() -> void:
	await go("arena_warden")
	god(true)
	await begin_fight()
	check(zone().lair != null and zone().lair.kind == "courtyard", "the rune sanctum lair is active")
	var b: BossBase = boss()
	check(b != null, "warden spawned")
	check(zone().fight_started, "fight starts when player walks in")
	# ---------------- phase 1: the ROLL into a pillar dazes it, the crystal shows
	var n := 0
	while b.state != "stunned" and n < 2400:
		if b.state == "idle":
			b.start_attack("roll")
		if b.state == "idle" or b.state == "tele":
			bait_pillar(b)
		await frames(1)
		n += 1
	check(b.state == "stunned" and b.phase == 1, "P1: the roll crashes into a pillar -> dazed, crystal exposed")
	check(not b.weak.armed, "P1: crystal is still hidden while the golem uncurls")
	check(await wait_until(func(): return b.weak.armed, 1.0) and b.weak.accept_fly, "P1: crystal armed once the animation shows it")
	await shot("warden_p1_stunned")
	var wp: Vector2 = b.weak.global_position
	ensure_arrow()
	tp(weak_side_pos(b.global_position, wp, 70.0))
	await wait(0.1)
	await shoot_at(wp)
	var ok: bool = await wait_until(func(): return b.phase == 2, 3.0)
	check(ok and not b.dead, "P1: crystal hit -> awakens (phase 2)")
	await recall(1.4)
	# ---------------- phase 2: the POUND opens the crystal
	ok = await wait_until(func(): return b.phase == 2 and b.state == "idle", 6.0)
	check(ok, "P2: awakened form idles with lit veins")
	await shot("warden_p2")
	b.start_attack("pound")
	ok = await wait_until(func(): return b.state == "stomp", 6.0)
	check(ok, "P2: ground-pound shockwave")
	check(await wait_until(func(): return b.weak.armed, 1.0), "P2: the crystal opens after the pound")
	await shot("warden_p2_open")
	ensure_arrow()
	tp(b.global_position + Vector2(0, 110))
	await frames(2)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 3, 3.0)
	check(ok and not b.dead, "P2: crystal hit -> molten (phase 3)")
	await recall(1.4)
	# ---------------- phase 3: the OVERHEAT opens the crystal, to a recalled arrow only
	ok = await wait_until(func(): return b.phase == 3 and b.state == "idle", 6.0)
	b.start_attack("overheat")
	ok = await wait_until(func(): return b.weak_window and b.weak.armed, 4.0)
	check(ok and not b.weak.accept_fly and b.weak.accept_ret, "P3: overheat vents steam; the crystal takes only a returning arrow")
	await shot("warden_p3_stunned")
	wp = b.weak.global_position
	ensure_arrow()
	tp(weak_side_pos(b.global_position, wp, 90.0))
	await wait(0.05)
	await shoot_at(wp)                       # a direct shot must NOT kill it
	await wait(0.35)
	check(not b.dead, "P3: a flying arrow cannot kill the molten crystal")
	if not b.weak_window:
		b.set_state("idle")
		b.start_attack("overheat")
		await wait_until(func(): return b.weak_window and b.weak.armed, 4.0)
	wp = b.weak.global_position
	var out: Vector2 = (wp - b.global_position).normalized()
	var perp := out.rotated(PI / 2.0)
	for sgn in [1.0, -1.0]:
		var pp: Vector2 = wp - perp * 70.0 * sgn
		if pp.x > 50 and pp.x < zone().w * 16 - 50 and pp.y > 60 and pp.y < zone().h * 16 - 40:
			tp(pp)
			await _park_arrow(wp + perp * 45.0 * sgn)
			break
	await recall(1.0)
	var dead: bool = await wait_until(func(): return b.dead, 2.0)
	check(dead, "P3: recalled arrow through the crystal kills the warden")
	await wait(4.0)
	check(Game.is_defeated("warden"), "warden marked defeated and saved")

func sc_warden_hits_armor() -> void:
	await go("arena_warden")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	tp(b.global_position + Vector2(0, 70))
	await wait(0.1)
	await shoot_at(b.global_position)
	await wait(0.5)
	check(not b.dead, "armored body deflects the arrow")
	check(arrow().state == Arrow.State.GROUND or arrow().state == Arrow.State.FLYING, "arrow dropped by armor")

func knight_fwd(b: BossBase) -> Vector2:
	return Vector2.from_angle(b.angle)

## make sure the player is holding the arrow (a recall can be blocked by a boss's shield)
func ensure_arrow() -> void:
	if not arrow().is_held():
		arrow().force_hold()

## remove the knight's ice slabs so a scripted shot has a clear line
func clear_ice() -> void:
	for n in get_tree().get_nodes_in_group("crystal"):
		if n is IceSlab:
			n.queue_free()

func sc_knight() -> void:
	await go("arena_knight")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	check(zone().lair != null and zone().lair.kind == "crystal", "the frozen vault lair is active")
	check(zone().player.friction_mult < 0.2, "ice floor: the player slides")
	# ---- arrows that clank off the knight freeze
	tp(b.global_position + Vector2(56, 30))       # (the two central crystal blocks would swallow a shot from the south)
	await wait(0.6)
	b.set_state("idle")
	clear_ice()
	b.active = false                     # hold the AI still: no ice wall between us
	await shoot_at(b.global_position + Vector2(0, -6))
	b.active = true
	check(not b.dead, "P1: body/guard shot does no harm")
	check(arrow().frozen, "P1: an arrow that hits the guardian is frozen in ice")
	await recall(0.5)
	check(arrow().state != Arrow.State.RETURNING and arrow().state != Arrow.State.HELD, "frozen arrow cannot be recalled")
	var ok: bool = await wait_until(func(): return not arrow().frozen, 4.0)
	check(ok, "the ice thaws")
	await recall(1.4)
	# ---- phase 1: only the SLAM opens the eye
	b.set_state("idle")
	b.start_attack("lance")
	await wait(0.3)
	check(not b.weak.armed, "P1: the eye stays shut during an ordinary attack")
	b.set_state("idle")
	b.start_attack("slam")
	ok = await wait_until(func(): return b.weak.armed, 4.0)
	check(ok, "P1: the slam sticks its fist in the ice and the eye opens")
	clear_ice()
	ensure_arrow()
	tp(b.global_position + Vector2(58, 6))
	await frames(1)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 2, 3.0)
	check(ok and not b.dead, "P1: eye hit -> carapace form (phase 2)")
	await recall(1.4)
	# ---- phase 2: the chest opens only on the roar
	ok = await wait_until(func(): return b.phase == 2 and b.state == "idle", 6.0)
	check(not b.weak.armed, "P2: chest sealed")
	b.start_attack("roar")
	ok = await wait_until(func(): return b.weak.armed, 3.0)
	check(ok, "P2: the eye shows on the roar frames")
	clear_ice()
	ensure_arrow()
	tp(b.global_position - Vector2.from_angle(b.angle) * 52.0)      # behind the guard: it does not track during the roar
	await frames(1)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 3, 3.0)
	check(ok and not b.dead, "P2: eye hit on the roar -> prism form (phase 3)")
	await recall(1.4)
	# ---- phase 3: after the beam it staggers; only a recalled arrow through the eye counts
	ok = await wait_until(func(): return b.phase == 3 and b.state == "idle", 6.0)
	tp(b.global_position + Vector2(110, 20))
	b.start_attack("beam")
	ok = await wait_until(func(): return b.weak.armed, 5.0)
	check(ok and not b.weak.accept_fly and b.weak.accept_ret, "P3: the beam leaves it staggered; eye takes recalled arrows only")
	await shot("knight_p3_recoil")
	ensure_arrow()
	tp(b.global_position + Vector2(80, 6))
	await frames(2)
	await shoot_at(b.weak.global_position)
	await wait(0.3)
	check(not b.dead, "P3: a flying arrow cannot hurt the eye")
	await recall(1.0)
	if not b.weak_window:
		b.set_state("idle")
		b.start_attack("beam")
		await wait_until(func(): return b.weak.armed, 5.0)
	var eye: Vector2 = b.weak.global_position
	tp(eye + Vector2(70, 0))
	await _park_arrow(eye + Vector2(-40, 0))
	await recall(1.0)
	var dead: bool = await wait_until(func(): return b.dead, 2.0)
	check(dead, "P3: recall through the eye kills the knight")
	await wait(4.0)
	check(Game.is_defeated("knight"), "knight defeated")

## every attack of every rewritten boss runs to completion without error, and no attack is reused in another phase
func sc_attacks_all() -> void:
	for id in ["warden", "knight", "hunter", "colossus", "burrower", "twins", "regent"]:
		await go("arena_" + id)
		god(true)
		await begin_fight()
		var b: BossBase = boss()
		var atks: Dictionary = b.all_attacks()
		var seen := {}
		for p in atks:
			for a in atks[p]:
				check(not seen.has(a), "%s: attack '%s' is not repeated across phases" % [id, a])
				seen[a] = p
		for p in atks:
			if id == "twins" and p == 1:
				pass                                  # phase 1 is the starting state of the twins
			elif b.has_method("_apply_phase"):
				b._apply_phase(p)
			else:
				b._begin_phase(p)                     # the regent
			b.set_state("idle")
			for a in atks[p]:
				tp(b.global_position + Vector2(0, 100))
				await wait(0.2)
				b.set_state("idle")
				b.start_attack(a)
				var done: bool = await wait_until(func(): return b.state != "attack", 14.0)
				check(done, "%s P%d: attack '%s' completes" % [id, p, a])
				await wait(0.3)

func sc_burrower() -> void:
	await go("arena_burrower")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	var lair: Lair = zone().lair
	check(lair != null and lair.kind == "burrow" and lair.lanterns.size() == 4, "the candlelit crypt: four lanterns")
	check(lair.lit_positions().size() == 2, "two lanterns burn at the start")
	# ---- light a lantern with an arrow
	var dark_l: Dictionary = {}
	for e in lair.lanterns:
		if e["t"] <= 0.0:
			dark_l = e
	tp(dark_l["holder"].global_position + Vector2(0, 80))
	await wait(0.2)
	await shoot_at(dark_l["sw"].global_position)
	await wait(0.7)
	check(dark_l["t"] > 0.0, "an arrow through a dark lantern lights it")
	# ---- blessing: an arrow lying in lantern light is blessed
	ensure_arrow()
	await _park_arrow(lair.lit_positions()[0])
	await wait(0.3)
	check(arrow().blessed_t > 0.0, "an arrow in lantern light is blessed")
	ensure_arrow()
	arrow().blessed_t = 0.0
	# ---- phase 1: it rises out of a lit lantern; only a BLESSED arrow hurts the eyes
	b.set_state("swim")
	b.start_attack("ring_erupt")
	var ok: bool = await wait_until(func(): return b.weak_window and b.ate_arrow, 8.0)
	check(ok, "P1: the ghost rises out of a lit lantern and raises the scythe")
	check(await wait_until(func(): return b.weak.armed, 1.5), "P1: eyes armed on the raised-scythe frames")
	arrow().blessed_t = 0.0
	check(not b.weak.try_hit("fly", arrow()), "P1: an ordinary arrow passes through the ghost")
	await shot("burrower_exposed")
	ensure_arrow()
	arrow().blessed_t = 6.0
	tp(b.weak.global_position + Vector2(0, 60))
	await frames(1)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 2, 4.0)
	check(ok and not b.dead, "P1: blessed arrow through the eyes -> bristling form (phase 2)")
	# ---- phase 2: crest erupt, scythe up briefly
	ok = await wait_until(func(): return b.phase == 2 and b.state == "swim", 8.0)
	ensure_arrow()
	b.start_attack("crest_erupt")
	ok = await wait_until(func(): return b.weak_window, 8.0)
	check(ok, "P2: crest erupt raises the scythe")
	check(await wait_until(func(): return b.weak.armed, 1.5) and b.weak.accept_fly, "P2: eyes take a blessed shot")
	await shot("burrower_p2_crest")
	arrow().blessed_t = 6.0
	tp(b.weak.global_position + Vector2(0, 60))
	await frames(1)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 3, 4.0)
	check(ok and not b.dead, "P2: eyes hit -> devourer form (phase 3)")
	await recall(1.4)
	# ---- phase 3: decoy erupts out of a lantern; blessed AND recalled arrow only
	ok = await wait_until(func(): return b.phase == 3 and b.state == "swim", 8.0)
	ensure_arrow()
	lair._light(lair.lanterns[0])
	b.start_attack("decoy_erupts")
	ok = await wait_until(func(): return b.weak_window and b.ate_arrow, 10.0)
	check(ok, "P3: the devourer rises out of the flame")
	check(await wait_until(func(): return b.weak.armed, 1.5) and not b.weak.accept_fly and b.weak.accept_ret, "P3: only a recalled arrow counts")
	await shot("burrower_p3_maw")
	var eye: Vector2 = b.weak.global_position
	arrow().blessed_t = 6.0
	tp(eye + Vector2(0, -70))
	await _park_arrow(eye + Vector2(0, 40))
	arrow().blessed_t = 6.0
	await recall(1.2)
	var dead: bool = await wait_until(func(): return b.dead, 2.5)
	check(dead, "P3: blessed, recalled arrow through the eyes kills the executioner")
	await wait(4.0)
	check(Game.is_defeated("burrower"), "executioner defeated")

func sc_colossus() -> void:
	await go("arena_colossus")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	await wait(1.5)
	await shot("colossus_fight")
	# ---- phase 1: cut the three chains with flying arrows, then strike the core
	for idx in [2, 0, 1]:
		var sw: RuneSwitch = b.pylons[idx]["sw"]
		tp(Vector2(280, 205))
		await wait(0.1)
		await shoot_at(sw.global_position)
		var hit: bool = await wait_until(func(): return sw.on, 1.6)
		check(hit, "P1: pylon %d struck by arrow" % idx)
		await recall(1.6)
		await wait(0.2)
	check(b.state == "exposed", "P1: all chains broken -> colossus collapses (state=%s)" % b.state)
	tp(Vector2(280, 205))
	await wait(0.1)
	await shoot_at(b.core.global_position)
	var ok: bool = await wait_until(func(): return b.phase == 2, 4.0)
	check(ok and not b.dead, "P1: core hit -> unchained form (phase 2)")
	# pick the dropped arrow up again
	tp(arrow().global_position + Vector2(0, 6))
	await wait(0.3)
	# ---- phase 2: hit BOTH horn flames within the timer (hold the AI still so the flames stay put)
	ok = await wait_until(func(): return b.phase == 2 and b.state == "gap", 8.0)
	await shot("colossus_p2")
	for i in 2:
		b.set_state("gap")               # cancel any attack: the flames go back to their horns
		await frames(3)
		b.active = false
		ensure_arrow()
		var gpos: Vector2 = b.gems[i].global_position
		tp(gpos + Vector2(-90.0 if gpos.x < b.global_position.x else 90.0, 0.0))    # level with the flame, on its own side
		await frames(2)
		await shoot_at(b.gems[i].global_position)
		var got: bool = await wait_until(func(): return b.gem_hit[i] or b.phase == 3 or b.state == "evolve", 1.5)
		check(got, "P2: horn flame %d doused" % i)
		b.active = true
		if i == 0:
			await recall(0.9)
	ok = await wait_until(func(): return b.phase == 3, 5.0)
	check(ok and not b.dead, "P2: both flames -> burning form (phase 3)")
	await recall(1.2)
	# ---- phase 3: runes and core answer only to a recalled arrow
	ok = await wait_until(func(): return b.phase == 3 and (b.state == "gap" or b.state == "slam" or b.state == "sweep"), 6.0)
	await shot("colossus_p3")
	var rune: RuneSwitch = b.pylons[2]["sw"]
	tp(Vector2(280, 205))
	await wait(0.1)
	await shoot_at(rune.global_position)
	await wait(0.5)
	check(not rune.on, "P3: a flying arrow cannot cut the chain")
	tp(arrow().global_position + Vector2(0, 6))
	await wait(0.2)
	b.set_state("gap")                    # hold the demon still while the chains are cut: its moves must not cross the arrow's path
	await frames(3)
	b.active = false
	for idx in [2, 0, 1]:
		var sw2: RuneSwitch = b.pylons[idx]["sw"]
		var stand: Vector2 = sw2.global_position + Vector2(0, 100) if idx == 2 else Vector2(280, 205)
		tp(stand)
		await frames(2)
		var away: Vector2 = (sw2.global_position - stand).normalized()
		await _park_arrow(sw2.global_position + away * 30.0)
		await recall(1.0)
		check(sw2.on, "P3: recalled arrow cuts pylon %d" % idx)
		await wait(0.2)
	b.active = true
	await frames(2)
	check(b.state == "exposed", "P3: all chains cut -> core exposed (state=%s)" % b.state)
	await shot("colossus_p3_exposed")
	check(b.core.armed and not b.core.accept_fly, "P3: core takes only a recalled arrow")
	tp(Vector2(280, 205))
	await frames(2)
	await shoot_at(b.core.global_position)
	await wait(0.4)
	check(not b.dead, "P3: flying arrow bounces off the core")
	tp(Vector2(280, 205))
	await _park_arrow(Vector2(280, 62))
	await recall(1.2)
	var dead: bool = await wait_until(func(): return b.dead, 2.5)
	check(dead, "P3: recalled arrow through the core kills the colossus")
	await wait(4.0)
	check(Game.is_defeated("colossus"), "colossus defeated")

func sc_hunter() -> void:
	await go("arena_hunter")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	check(zone().lair != null and zone().lair.kind == "sky", "the aerie lair (gale) is active")
	await wait(1.0)
	await shot("hunter_fight")
	tp(Vector2(300, 250))
	await shoot_at(b.global_position)
	await wait(0.6)
	check(not b.dead, "P1: flying hunter cannot be hit")
	await recall(1.4)
	# ---- the arrow thief
	ensure_arrow()
	tp(Vector2(240, 235))
	await _park_arrow(Vector2(330, 200))
	b.set_state("hover")
	b.start_attack("thief")
	var ok: bool = await wait_until(func(): return arrow().stolen_by == b, 4.0)
	check(ok, "P1: the thief snatches the arrow off the floor")
	tp(Vector2(240, 235))
	await recall(1.2)
	check(arrow().stolen_by == null and (arrow().state == Arrow.State.HELD or arrow().state == Arrow.State.RETURNING), "P1: recall pulls the arrow out of its hands")
	ensure_arrow()
	# ---- phase 1: quiver empty -> it lands and kneels -> head
	b.ammo = 0
	b.set_state("reload")
	ok = await wait_until(func(): return b.weak.armed and b.landed, 4.0)
	check(ok, "P1: empty quiver: it lands and kneels")
	await shot("hunter_grounded")
	var wp: Vector2 = b.weak.global_position
	tp(weak_side_pos(b.global_position, wp, 70.0))
	await wait(0.1)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 2, 4.0)
	check(ok and not b.dead, "P1: head hit -> storm form (phase 2)")
	ensure_arrow()
	# ---- phase 2: the QUIVER
	ok = await wait_until(func(): return b.phase == 2 and b.state == "hover", 6.0)
	b.ammo = 0
	b.set_state("reload")
	ok = await wait_until(func(): return b.weak.armed and b.landed, 4.0)
	check(ok, "P2: empty quiver again")
	await shot("hunter_p2_grounded")
	check(b.weak.position.x * b.facing < 0.0, "P2: weak point is the quiver on its back (x=%.0f, facing %.0f)" % [b.weak.position.x, b.facing])
	wp = b.weak.global_position
	tp(weak_side_pos(b.global_position, wp, 70.0))
	await wait(0.1)
	await shoot_at(b.weak.global_position)
	ok = await wait_until(func(): return b.phase == 3, 4.0)
	check(ok and not b.dead, "P2: quiver hit -> tempest form (phase 3)")
	ensure_arrow()
	# ---- phase 3: head, recalled arrows only, ~2 s
	ok = await wait_until(func(): return b.phase == 3 and b.state == "hover", 6.0)
	b.ammo = 0
	b.set_state("reload")
	ok = await wait_until(func(): return b.weak.armed and b.landed, 4.0)
	check(ok, "P3: the quiver runs dry a third time")
	await shot("hunter_p3_grounded")
	check(b.weak.armed and not b.weak.accept_fly, "P3: head accepts only a recalled arrow")
	wp = b.weak.global_position
	tp(wp + Vector2(0, 75))
	await _park_arrow(wp + Vector2(0, -45))
	await recall(1.0)
	var dead: bool = await wait_until(func(): return b.dead, 2.5)
	check(dead, "P3: recalled arrow across the head kills the hunter")
	await wait(4.0)
	check(Game.is_defeated("hunter"), "hunter defeated")

func sc_twins() -> void:
	await go("arena_twins")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	await wait(0.5)
	await shot("twins_fight")
	# ---- phase 1: lure one twin's beam through the other
	check(zone().lair != null and zone().lair.kind == "twins", "the observatory lair (sun / moon halves) is active")
	b.set_state("idle")
	b.start_attack("link_beam")
	var ok: bool = await wait_until(func(): return b.attacker != null, 3.0)
	check(ok, "P1: a twin begins a beam attack")
	var a = b.attacker
	var o = b.other_of(a)
	var n := 0
	while n < 240 and not o.overloaded:
		var dir: Vector2 = (o.global_position - a.global_position).normalized()
		tp(o.global_position + dir * 36.0)
		await frames(1)
		n += 1
	check(o.overloaded, "P1: beam blocked by twin overloads it")
	await shot("twins_overloaded")
	ensure_arrow()
	tp(o.global_position + Vector2(0, 80))
	await wait(0.1)
	await shoot_at(o.weak.global_position)
	await wait(0.5)
	check(not o.alive, "P1: exposed twin dies to one arrow")
	check(not b.dead, "P1: boss lives on")
	ok = await wait_until(func(): return b.phase == 2, 4.0)
	check(ok, "P1: a twin falls -> the survivor evolves (phase 2)")
	await recall(1.5)
	# ---- phase 2: the lone twin's beams recoil and expose it
	var s2 = a
	ok = await wait_until(func(): return b.phase == 2 and b.state == "idle", 6.0)
	b.start_attack("gravity_well")
	ok = await wait_until(func(): return s2.overloaded, 8.0)
	check(ok, "P2: the gravity well leaves the lone wizard spent")
	await shot("twins_p2")
	ensure_arrow()
	tp(s2.global_position + Vector2(0, 80))
	await wait(0.1)
	await shoot_at(s2.weak.global_position)
	ok = await wait_until(func(): return b.phase == 3, 5.0)
	check(ok and not b.dead, "P2: survivor falls -> ECLIPSE (phase 3)")
	await recall(1.5)
	# ---- phase 3: the fused core takes only a recalled arrow
	var e = b.tw.back()
	ok = await wait_until(func(): return b.phase == 3 and b.state == "idle", 6.0)
	b.start_attack("eclipse_beams")
	ok = await wait_until(func(): return e.overloaded, 12.0)
	check(ok, "P3: eclipse spins its beams, then its shell parts")
	await shot("twins_p3_open")
	check(e.weak.armed and not e.weak.accept_fly, "P3: core accepts only a recalled arrow")
	var wp: Vector2 = e.weak.global_position
	ensure_arrow()
	tp(wp + Vector2(0, 90))
	await frames(2)
	await shoot_at(wp)
	await wait(0.4)
	check(not b.dead, "P3: a flying arrow cannot hurt the core")
	tp(arrow().global_position + Vector2(0, 6))
	await wait(0.1)
	if not e.overloaded:
		ok = await wait_until(func(): return e.overloaded, 40.0)
	wp = e.weak.global_position
	tp(wp + Vector2(0, 80))
	await _park_arrow(wp + Vector2(0, -45))
	await recall(1.0)
	var dead: bool = await wait_until(func(): return b.dead, 2.5)
	check(dead, "P3: recalled arrow across the core kills the eclipse")
	await wait(4.0)
	check(Game.is_defeated("twins"), "twins defeated")

var _ending_seen := false

func _park_arrow(pos: Vector2) -> void:
	arrow().global_position = pos
	arrow().vel = Vector2.ZERO
	arrow()._set_state(Arrow.State.STUCK)
	await wait(0.1)

func sc_regent() -> void:
	Game.mark_defeated("warden")
	await go("arena_regent")
	zone().ending_requested.connect(func(): _ending_seen = true)
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	check(zone().lair != null and zone().lair.kind == "final" and zone().lair.quads.size() == 4, "the Nexus lair: four elemental quadrants")
	check(b.shrines.size() == 4, "four elemental shrines stand in the corners")
	check(b.body.texture.get_size() == Vector2(96, 144), "the titan is drawn at 1.5x (96x144)")
	await shot("regent_p1")
	# ---- phase 1: a wrong shrine backfires, the water shrine splits the shell, any arrow at the core
	b.set_state("idle")
	b.shrines["earth"]["sw"].strike()
	await wait(0.3)
	check(b.state != "window", "P1: the earth shrine is the wrong element - it backfires, the core stays sealed")
	tp(b.shrines["water"]["pos"] + Vector2(-70, 40))
	await wait(0.3)
	ensure_arrow()
	await shoot_at(b.shrines["water"]["sw"].global_position)
	var ok: bool = await wait_until(func(): return b.state == "window", 2.0)
	check(ok, "P1: an arrow into the water shrine opens the fire titan's core")
	check(b.weak.armed and b.weak.accept_fly, "P1: the core takes any arrow while open")
	await shot("regent_p1_open")
	ensure_arrow()
	tp(b.global_position + Vector2(0, 30 + 100))
	await frames(2)
	await shoot_at(b.weak.global_position + Vector2(0, b.body.position.y))
	ok = await wait_until(func(): return b.phase == 2, 4.0)
	check(ok and not b.dead, "P1: core hit breaks seal 1 (boss not dead: %s)" % str(b.dead))
	# ---- phase 2: the FIRE shrine
	ok = await wait_until(func(): return b.phase == 2 and b.state == "idle", 6.0)
	check(ok, "P2 begins")
	await shot("regent_p2")
	b.shrines["water"]["sw"].strike()
	await wait(0.3)
	check(b.state != "window", "P2: the water shrine is wrong for the tide elemental")
	b.shrines["fire"]["sw"].strike()
	ok = await wait_until(func(): return b.state == "window", 2.0)
	check(ok, "P2: the fire shrine opens the core")
	ensure_arrow()
	tp(b.global_position + Vector2(0, 130))
	await frames(2)
	await shoot_at(b.weak.global_position + Vector2(0, b.body.position.y))
	ok = await wait_until(func(): return b.phase == 3, 4.0)
	check(ok and not b.dead, "P2: core hit breaks seal 2")
	# ---- phase 3: both shrines, then a recalled arrow only
	ok = await wait_until(func(): return b.phase == 3 and b.state == "idle", 6.0)
	await shot("regent_p3")
	b.shrines["fire"]["sw"].strike()
	await wait(0.4)
	check(b.state != "window", "P3: one shrine is not enough")
	b.shrines["water"]["sw"].strike()
	ok = await wait_until(func(): return b.state == "window", 2.0)
	check(ok, "P3: fire + water together open the core")
	check(b.weak.armed and not b.weak.accept_fly and b.weak.accept_ret, "P3: only a returning arrow counts")
	await shot("regent_p3_pulse")
	ensure_arrow()
	tp(b.global_position + Vector2(0, 130))
	await frames(2)
	await shoot_at(b.weak.global_position + Vector2(0, b.body.position.y))
	await wait(0.4)
	check(not b.dead, "P3: a flying arrow cannot kill the core")
	if b.state != "window":
		b.set_state("idle")
		b.shrines["fire"]["sw"].strike()
		b.shrines["water"]["sw"].strike()
		await wait_until(func(): return b.state == "window", 2.0)
	var c: Vector2 = b.weak.global_position + Vector2(0, b.body.position.y)
	tp(c + Vector2(0, 110))
	await _park_arrow(c + Vector2(0, -60))
	await recall(1.2)
	var dead: bool = await wait_until(func(): return b.dead, 2.5)
	check(dead, "P3: returning arrow through the core kills the Regent")
	await wait(1.0)
	await shot("regent_death")
	await wait(6.0)
	check(Game.is_defeated("regent") and Game.finished, "regent defeated, finished flag saved")
	check(_ending_seen, "ending is requested after the kill")

# ------------------------------------------------------------------ full-flow scenarios
func press_action(a: String) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = a
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)

func enter_boss(id: String) -> void:
	await go("hub", "start")
	var g: Gate = null
	for x in zone().gates:
		if x.boss_id == id:
			g = x
	check(g != null, "hub has a gate for %s" % id)
	check(not g.locked, "gate for %s is open" % id)
	tp(g.global_position + Vector2(0, 8))
	var ok: bool = await wait_until(func(): return main.zone != null and main.zone.zone_id == "path_" + id and not main.transitioning, 6.0)
	check(ok, "gate leads to path_%s" % id)
	await wait(0.4)
	tp(zone().gates[0].global_position + Vector2(0, 10))
	ok = await wait_until(func(): return main.zone != null and main.zone.zone_id == "arena_" + id and not main.transitioning, 6.0)
	check(ok, "path leads to arena_%s" % id)
	await wait(0.4)

func win_boss(id: String) -> void:
	await begin_fight()
	check(zone().fight_started, "%s fight starts" % id)
	var b: BossBase = boss()
	await wait(1.0)
	b.kill()   # kill pipeline itself is exercised with real arrows in the per-boss scenarios
	await wait(5.0)
	check(Game.is_defeated(id), "%s marked defeated" % id)
	var portal: Node = null
	for c in zone().entities.get_children():
		if c is ExitPortal:
			portal = c
	if id != "regent":
		check(portal != null, "%s: exit portal appears" % id)
		tp(portal.global_position + Vector2(0, 4))
		var ok: bool = await wait_until(func(): return main.zone != null and main.zone.zone_id == "hub" and not main.transitioning, 6.0)
		check(ok, "%s: portal returns to hub" % id)
		await wait(1.0)

func sc_flow() -> void:
	Game.new_game()
	Game.playing = true
	await go("hub", "start")
	var twins_gate: Gate = null
	var regent_gate: Gate = null
	for g in zone().gates:
		if g.boss_id == "twins": twins_gate = g
		if g.boss_id == "regent": regent_gate = g
	check(twins_gate.locked and regent_gate.locked, "twins + final gates start sealed")
	tp(regent_gate.global_position + Vector2(0, 8))
	await wait(1.0)
	check(main.zone.zone_id == "hub", "sealed final gate does not open")
	for id in ["warden", "knight", "burrower"]:
		await enter_boss(id)
		await win_boss(id)
	await go("hub", "from_burrower")
	await wait(4.0)
	twins_gate = null
	for g in zone().gates:
		if g.boss_id == "twins": twins_gate = g
	check(not twins_gate.locked, "twins gate unlocks after %d guardians" % Game.TWINS_REQUIRED)
	check(Game.seen_unlocked.has("twins"), "unlock recorded")
	for id in ["colossus", "hunter", "twins"]:
		await enter_boss(id)
		await win_boss(id)
	await go("hub", "from_twins")
	await wait(4.0)
	for g in zone().gates:
		if g.boss_id == "regent": regent_gate = g
	check(not regent_gate.locked, "final gate unlocks once all six have fallen")
	Game.save_game()
	var before := Game.defeated.keys().size()
	Game.defeated = {}
	check(Game.load_game(), "save file loads")
	check(Game.defeated.keys().size() == before and before == 6, "all six victories persisted (%d)" % Game.defeated.keys().size())
	await enter_boss("regent")
	await begin_fight()
	await wait(1.0)
	boss().kill()
	var ok: bool = await wait_until(func(): return main.state == "ending", 12.0)
	check(ok, "ending sequence starts")
	ok = await wait_until(func(): return main.state == "title", 120.0)
	check(ok, "credits finish and return to the title screen")
	check(Game.finished, "finished flag set")
	check(Game.has_save(), "save exists for CONTINUE")

## fingers: press/drag/release at a position of the 480x270 canvas
func finger(id: int, pos: Vector2, kind: String) -> void:
	var ev: InputEvent
	if kind == "drag":
		var d := InputEventScreenDrag.new()
		d.index = id
		d.position = pos
		ev = d
	else:
		var t := InputEventScreenTouch.new()
		t.index = id
		t.position = pos
		t.pressed = kind == "down"
		ev = t
	main.get_viewport().push_input(ev, true)
	await frames(2)

func sc_touch() -> void:
	Game.new_game()
	Game.touch_mode = true
	await go("arena_warden")
	main.touch._show()
	await begin_fight()
	main.get_node("/root").get_tree()
	var b := boss()
	b.active = false
	b.set_state("gap")
	god(true)
	check(main.touch.is_gameplay(), "touch controls are live during a fight")
	# move stick: drag to the right, the hero runs right; let go, it stops
	tp(zone().mark("a") + Vector2(0, -40) if zone().mark("a") != Vector2.ZERO else player().global_position)
	var x0 := player().global_position.x
	await finger(1, Vector2(84, 210), "down")
	await finger(1, Vector2(84 + 90, 204), "drag")          # far past the stick's edge
	await wait(0.4)
	check(main.touch.fingers[1]["origin"] == TouchControls.MOVE_C, "the stick is fixed in place, however the thumb lands or drags")
	check(player().global_position.x > x0 + 8.0, "the move stick runs the hero right (%.1f -> %.1f)" % [x0, player().global_position.x])
	await finger(1, Vector2(120, 204), "up")
	await wait(0.5)
	check(player().velocity.length() < 5.0, "letting go of the stick stops the hero")
	# aim stick: drag left, release -> the arrow leaves to the left
	ensure_arrow()
	var ox := player().global_position.x
	await finger(2, Vector2(408, 204), "down")
	await finger(2, Vector2(408 - 30, 204), "drag")
	main.touch.pad.queue_redraw()                                     # draws the dotted aim line from the hero
	await frames(2)
	check(Game.touch_aim.x < -0.9, "dragging the shoot stick left aims left")
	await finger(2, Vector2(378, 204), "up")
	await wait(0.25)
	check(zone().arrow.is_out(), "releasing the aim stick shoots")
	check(zone().arrow.global_position.x < ox - 6.0, "the arrow flies where the aim stick pointed (x %.1f vs hero %.1f)" % [zone().arrow.global_position.x, ox])
	# the arrow is out: the same spot on the right is now RECALL, where the thumb lands
	check(zone().arrow.is_out(), "the arrow is away")
	await finger(3, Vector2(408, 204), "down")
	check(Input.is_action_pressed("recall"), "with the arrow out, touching the shoot control holds recall")
	check(main.touch.fingers[3]["role"] == "recall", "and it is a recall button, not an aim stick")
	await finger(3, Vector2(408, 204), "up")
	check(not Input.is_action_pressed("recall"), "letting go stops the recall")
	check(not Input.is_action_pressed("shoot"), "and does not shoot")
	# roll button
	player().stamina = Player.STAMINA_MAX
	await wait(0.4)
	await finger(4, Vector2(320, 228), "down")
	check(player().dodging > 0.0, "the ROLL button rolls")
	await finger(4, Vector2(320, 228), "up")
	await wait(0.5)
	# pause button opens the pause menu, a tap on RESUME closes it
	await finger(5, Vector2(240, 12), "down")
	await finger(5, Vector2(240, 12), "up")
	await wait(0.3)
	check(get_tree().paused and main.pause_root != null, "the pause button pauses")
	check(not main.touch.is_gameplay(), "controls step aside while paused")
	var lab: Label = null
	var menu_node: Menu = null
	for c in main.pause_root.get_children():
		if c is Menu:
			menu_node = c
	check(menu_node != null, "pause menu is up")
	if menu_node != null:
		var first_item: String = menu_node.labels[0].text
		var r := menu_node.labels[0].position + Vector2(70, 22)       # off to the side and a fingertip low: still RESUME
		await finger(6, r, "down")
		await finger(6, r, "up")
		await wait(0.3)
		check(not get_tree().paused, "tapping RESUME with a finger resumes (%s)" % first_item)

func sc_ui_look() -> void:
	Game.new_game()
	Game.boss_deaths = {"warden": 3}
	Game.deaths = 7
	await go("arena_warden")
	await begin_fight()
	await wait(0.5)
	main._refresh_deaths()
	await shot("ui_deaths")
	main._open_pause()
	await frames(6)
	await shot("ui_pause")
	main._resume()

func sc_run_away() -> void:
	Game.new_game()
	await go("arena_warden")
	await begin_fight()
	await wait(0.4)
	check(main.deaths_label.visible and main.deaths_label.text.contains("DEATHS  0"), "the death counter is on screen (%s)" % main.deaths_label.text.replace("\n", " / "))
	var z0_id := zone().get_instance_id()
	var h := Hazard.circle(40.0)
	zone().entities.add_child(h)
	h.global_position = player().global_position
	await frames(3)
	check(player().dead, "one hit kills the player")
	var ok: bool = await wait_until(func(): return main.zone != null and main.zone.get_instance_id() != z0_id and not main.transitioning, 4.0)
	check(ok, "arena reloads after death")
	check(Game.deaths == 1 and int(Game.boss_deaths.get("warden", 0)) == 1, "the death is counted in total and against the warden")
	await wait(0.4)
	check(main.deaths_label.text.contains("DEATHS  1") and main.deaths_label.text.contains("THIS FIGHT  1"), "the counter shows it (%s)" % main.deaths_label.text.replace("\n", " / "))
	Game.save_game()
	Game.boss_deaths = {}
	Game.deaths = 0
	check(Game.load_game() and Game.deaths == 1 and int(Game.boss_deaths.get("warden", 0)) == 1, "death counts survive a save and load")
	# ---- RUN AWAY: out of the boss fight to the first screen, without counting as a death
	main._open_pause()
	check(main.pause_root != null and get_tree().paused, "pause menu open")
	await main._run_away()
	ok = await wait_until(func(): return main.zone != null and main.zone.zone_id == "hub" and not main.transitioning, 4.0)
	check(ok, "RUN AWAY leads to the hub (the first screen)")
	check(not get_tree().paused and main.pause_root == null, "the game is unpaused")
	check(Game.deaths == 1, "running away is not a death")
	main._open_pause()
	await frames(2)
	check(main.menu != null, "in the hub the pause menu still opens")
	main._resume()

func sc_death() -> void:
	await go("arena_warden")
	await begin_fight()
	var z0_id := zone().get_instance_id()
	var b0_id := boss().get_instance_id()
	await wait(0.5)
	var f0 := Engine.get_physics_frames()
	var h := Hazard.circle(40.0)
	zone().entities.add_child(h)
	h.global_position = player().global_position
	await frames(3)
	check(player().dead, "one hit kills the player")
	var deaths0 := Game.deaths
	var ok: bool = await wait_until(func(): return main.zone != null and main.zone.get_instance_id() != z0_id and not main.transitioning, 4.0)
	check(ok, "arena reloads after death")
	var secs := float(Engine.get_physics_frames() - f0) / 60.0
	print("   (death -> playable again in ~", snappedf(secs, 0.01), "s game time)")
	check(secs < 2.2, "retry within ~2 seconds (%.2fs)" % secs)
	check(main.zone.boss.get_instance_id() != b0_id and main.zone.boss.state == "idle" and not main.zone.boss.active, "boss fully reset")
	check(Arrow.live_count == 1, "exactly one arrow after reset (%d)" % Arrow.live_count)
	check(Game.deaths == deaths0, "death counted")
	await wait(0.3)
	var z1_id := zone().get_instance_id()
	await press_action("restart")
	ok = await wait_until(func(): return main.zone != null and main.zone.get_instance_id() != z1_id and not main.transitioning, 3.0)
	check(ok, "R restarts the fight")

func sc_menu() -> void:
	Game.defeated = {}
	if FileAccess.file_exists(Game.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	main.show_title()
	await wait(1.2)
	await shot("title")
	check(main.menu != null and main.menu.items.size() >= 3, "title menu has entries")
	check(not main.menu.items[1].get("enabled", true), "CONTINUE disabled without a save")
	await press_action("ui_down")
	check(main.menu.index != 1, "menu skips disabled CONTINUE")
	await press_action("ui_up")
	await press_action("ui_down")
	await press_action("ui_accept")
	await wait(0.2)
	check(main.settings_menu != null, "settings menu opens")
	await shot("settings")
	var before: float = Game.settings["master"]
	await press_action("ui_left")
	check(Game.settings["master"] < before or before <= 0.0, "slider changes master volume")
	await press_action("ui_cancel")
	check(main.settings_menu == null, "settings closes")
	await press_action("ui_up")
	await press_action("ui_accept")
	for i in 14:
		await wait(0.25)
		await press_action("ui_accept")
		if main.state == "play" and main.zone != null:
			break
	var ok: bool = await wait_until(func(): return main.state == "play" and main.zone != null and main.zone.kind == "hub" and not main.transitioning, 15.0)
	check(ok, "NEW GAME: intro then hub")
	await wait(1.0)
	await press_action("pause")
	check(get_tree().paused and main.pause_root != null, "pause menu opens and pauses the game")
	await shot("pause")
	await press_action("pause")
	check(not get_tree().paused, "pause toggles off")
	await press_action("pause")
	for i in 2:
		await press_action("ui_down")   # RESTART FIGHT is disabled outside arenas
	await press_action("ui_accept")
	ok = await wait_until(func(): return main.state == "title" and main.menu != null, 5.0)
	check(ok, "RETURN TO MENU works")
	await wait(0.8)
	check(main.menu.items[1].get("enabled", false), "CONTINUE now enabled")
	await press_action("ui_down")
	await press_action("ui_accept")
	ok = await wait_until(func(): return main.state == "play" and main.zone != null and not main.transitioning, 6.0)
	check(ok, "CONTINUE loads the save")

func sc_dodge() -> void:
	await go("arena_warden")
	var p := player()
	hold("move_right", true)
	await tap("dodge", 0.03)
	var h := Hazard.circle(300.0)
	zone().entities.add_child(h)
	h.global_position = p.global_position
	await wait(0.12)
	check(not p.dead, "dodge i-frames protect the player at 0.12s")
	await wait(0.25)
	hold("move_right", false)
	check(p.dead, "player dies once i-frames end while still inside the hazard")

func sc_dash_iframes() -> void:
	await go("arena_warden")
	var p := player()
	p.locked = false
	Input.action_press("move_right")
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(p.dodging > 0.0, "the roll started")
	var h := TimedHazard.spawn(zone().entities, p.global_position + Vector2(0, -5), 40.0, 3.0)
	var alive := true
	for i in 13:                                  # into the last 0.06 s of the 0.27 s dash (the old i-frames ended before it)
		await frames(1)
		if p.dead:
			alive = false
	Input.action_release("move_right")
	check(alive, "no damage during the dash, even inside a hazard")
	h.queue_free()

func sc_stamina() -> void:
	await go("arena_warden")
	var p := player()
	check(is_equal_approx(p.stamina, Player.STAMINA_MAX), "starts with full stamina")
	hold("move_right", true)
	for i in 5:
		p.dodge_cd = 0.0
		await tap("dodge", 0.03)
		await wait(0.35)
	hold("move_right", false)
	check(p.stamina < Player.DODGE_COST, "stamina drained by rolling (%.0f)" % p.stamina)
	p.dodge_cd = 0.0
	await tap("dodge", 0.03)
	await wait(0.1)
	check(p.dodging <= 0.0, "cannot roll with too little stamina")
	await wait(4.6)
	check(is_equal_approx(p.stamina, Player.STAMINA_MAX), "stamina refills completely")

## dev helper: a red square on every armed weak point and a green one on the boss origin, to eyeball art/hit-circle alignment
func _mark_weak(b: BossBase) -> void:
	for w in b.find_children("*", "WeakPoint", true, false):
		if w.armed:
			print("LOOK ", b.name, " weak armed at ", w.global_position, " boss ", b.global_position)
			var r := ColorRect.new()
			r.color = Color(1, 0, 0, 0.9)
			r.size = Vector2(3, 3)
			r.z_index = 100
			zone().entities.add_child(r)
			r.global_position = w.global_position - Vector2(1.5, 1.5)
	var g := ColorRect.new()
	g.color = Color(0, 1, 0, 0.9)
	g.size = Vector2(3, 3)
	g.z_index = 100
	zone().entities.add_child(g)
	g.global_position = b.global_position - Vector2(1.5, 1.5)

func sc_look_hunter() -> void:
	await go("arena_hunter")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	var ok: bool = await wait_until(func(): return b.state == "grounded" and b.phase == 1, 30.0)
	await wait(0.3)
	print("LOOK boss=", b.global_position, " body=", b.body.position, " weak=", b.weak.position, " frame=", b.body.frame, " anim=", b.body.animation)
	_mark_weak(b)
	await shot("look_hunter")

func sc_look_all() -> void:
	# warden: dazed after a pillar crash
	await go("arena_warden")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	b.dir = Vector2.RIGHT
	b.set_state("stunned")
	await wait_until(func(): return b.weak.armed, 2.0)
	await wait(0.2)
	_mark_weak(b)
	await shot("look_warden")
	# knight: eye armed while idle
	await go("arena_knight")
	god(true)
	await begin_fight()
	b = boss()
	await wait_until(func(): return b.weak.armed, 4.0)
	_mark_weak(b)
	await shot("look_knight")
	# burrower: scythe raised
	await go("arena_burrower")
	god(true)
	await begin_fight()
	b = boss()
	b.head.visible = true
	b.facing = 1.0
	b.set_state("exposed")
	await wait_until(func(): return b.weak.armed, 3.0)
	_mark_weak(b)
	await shot("look_burrower")
	# colossus: phase 2, the two horn flames
	await go("arena_colossus")
	god(true)
	await begin_fight()
	b = boss()
	b._apply_phase(2)
	b.set_state("gap")
	await wait(0.6)
	_mark_weak(b)
	await shot("look_colossus")
	# twins: one wizard cracked open
	await go("arena_twins")
	god(true)
	await begin_fight()
	b = boss()
	b._overload(b.tw[0])
	await wait(0.4)
	_mark_weak(b)
	await shot("look_twins")

func sc_lairs() -> void:
	for id in ["warden", "knight", "burrower", "colossus", "hunter", "twins", "regent"]:
		await go("arena_" + id)
		god(true)
		await begin_fight()
		await wait(1.2)
		await shot("lair_%s_1" % id)
		zone().on_phase(2)
		await wait(2.2)
		await shot("lair_%s_2" % id)
		zone().on_phase(3)
		await wait(2.6)
		await shot("lair_%s_3" % id)
	for id in ["warden", "knight", "burrower", "colossus", "hunter", "twins", "regent"]:
		await go("path_" + id, "from_hub")
		tp(zone().mark("a") + Vector2(0, 110))
		await wait(1.0)
		await shot("lair_path_" + id)

## screenshots in the middle of the new attacks (windowed run)
func sc_show_attacks() -> void:
	var plan := [
		["knight", 1, "icicle_clap", 1.3], ["knight", 1, "ice_wall", 1.0], ["knight", 2, "spike_line", 1.0], ["knight", 3, "absolute_zero", 2.0],
		["hunter", 1, "skid", 1.0], ["hunter", 2, "arrow_rain", 1.5], ["hunter", 2, "trap_arrows", 1.2], ["hunter", 3, "pin_down", 1.6],
		["colossus", 2, "orb_barrage", 2.0], ["colossus", 2, "fire_wave", 1.2], ["colossus", 3, "meteor_rain", 1.6],
		["burrower", 1, "condemned", 1.6], ["burrower", 3, "grave_hands", 1.8], ["burrower", 3, "cage_drop", 1.5],
		["twins", 2, "claw_lattice", 1.8], ["twins", 3, "moon_fall", 2.0], ["twins", 3, "arcane_grid", 1.4],
		["warden", 1, "rock_spikes", 1.4], ["warden", 2, "laser", 1.2], ["warden", 3, "lava_rivers", 1.4],
	]
	var cur := ""
	var b: BossBase = null
	for e in plan:
		if e[0] != cur:
			cur = e[0]
			await go("arena_" + cur)
			god(true)
			await begin_fight()
			b = boss()
		if e[0] == "twins" and e[1] == 1:
			pass
		elif b.has_method("_apply_phase") and b.phase != e[1]:
			b._apply_phase(e[1])
		b.set_state("idle")
		tp(b.global_position + Vector2(70, 60))
		await wait(0.3)
		b.set_state("idle")
		b.start_attack(e[2])
		await wait(e[3])
		await shot("atk_%s_%s" % [cur, e[2]])
		b.set_state("idle")
		await wait(0.3)

func sc_crypt_look() -> void:
	await go("arena_burrower")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	await wait(1.0)
	await shot("crypt_a")
	b.set_state("swim")
	b.start_attack("ring_erupt")
	await wait(2.2)
	await shot("crypt_b")
	b.set_state("swim")
	b._apply_phase(3)
	b.start_attack("grave_hands")
	await wait(1.6)
	await shot("crypt_c")

func sc_regent_look() -> void:
	await go("arena_regent")
	god(true)
	await begin_fight()
	var b: BossBase = boss()
	await wait(2.5)
	await shot("rl_1_idle")
	b.set_state("idle")
	tp(b.global_position + Vector2(70, 40))
	b.start_attack("magma_fist")
	await wait(1.4)
	await shot("rl_1_magma")
	b._apply_phase(2)
	b.set_state("idle")
	b.start_attack("tidal_wave")
	await wait(1.5)
	await shot("rl_2_wave")
	b.set_state("idle")
	b.start_attack("frost_orbs")
	await wait(1.2)
	await shot("rl_2_orbs")
	b._apply_phase(3)
	b.set_state("idle")
	b.start_attack("storm_grid")
	await wait(1.6)
	await shot("rl_3_grid")
	b.set_state("idle")
	b.start_attack("shadow_clones")
	await wait(0.6)
	await shot("rl_3_clones")

func sc_anim_look() -> void:
	var plan := [
		["knight", 1, "icicle_clap", 0.45], ["knight", 1, "slam", 0.6], ["hunter", 2, "arrow_rain", 0.5], ["hunter", 1, "skid", 0.5],
		["warden", 2, "laser", 0.75], ["warden", 3, "fist_boomerang", 0.9], ["burrower", 1, "condemned", 0.9], ["burrower", 3, "grave_hands", 0.5],
		["twins", 2, "claw_lattice", 0.4], ["colossus", 3, "flame_charge", 0.9], ["regent", 1, "magma_fist", 0.5],
	]
	var cur := ""
	var b: BossBase = null
	for e in plan:
		if e[0] != cur:
			cur = e[0]
			await go("arena_" + cur)
			god(true)
			await begin_fight()
			b = boss()
		if e[0] == "twins" and e[1] == 1:
			pass
		elif b.has_method("_apply_phase") and b.phase != e[1]:
			b._apply_phase(e[1])
		b.set_state("idle")
		tp(b.global_position + Vector2(70, 60))
		await wait(0.3)
		b.set_state("idle")
		b.start_attack(e[2])
		await wait(e[3])
		await shot("an_%s_%s" % [cur, e[2]])
		b.set_state("idle")
		await wait(0.3)

func sc_anim_look2() -> void:
	var plan := [
		["regent", 1, "quake_line", 0.55], ["regent", 1, "boulder_toss", 0.8], ["regent", 2, "tidal_wave", 0.5], ["regent", 3, "shadow_clones", 0.5],
		["knight", 1, "icicle_clap", 0.55], ["knight", 1, "slam", 0.6], ["colossus", 2, "fire_wave", 0.75],
	]
	var cur := ""
	var b: BossBase = null
	for e in plan:
		if e[0] != cur:
			cur = e[0]
			await go("arena_" + cur)
			god(true)
			await begin_fight()
			b = boss()
		if e[0] == "twins" and e[1] == 1:
			pass
		elif b.has_method("_apply_phase") and b.phase != e[1]:
			b._apply_phase(e[1])
		b.set_state("idle")
		b.global_position = Vector2(zone().w * 8.0, zone().h * 8.0 - 20.0)
		tp(b.global_position + Vector2(95, 15))
		await wait(0.3)
		b.set_state("idle")
		b.start_attack(e[2])
		await wait(e[3])
		print("POS boss=", b.global_position, " player=", player().global_position, " cam=", zone().camera.get_screen_center_position(), " zone=", zone().w, "x", zone().h)
		await shot("an2_%s_%s" % [cur, e[2]])
		b.set_state("idle")
		await wait(0.3)

func sc_tour() -> void:
	for id in ["knight", "burrower", "colossus", "hunter", "twins", "regent"]:
		await go("arena_" + id)
		god(true)
		await begin_fight()
		await wait(3.0)
		await shot("tour_" + id)

func sc_path_reach() -> void:
	for id in ["warden", "knight", "burrower", "colossus", "hunter", "twins", "regent"]:
		await go("path_" + id, "from_hub")
		var z := zone()
		var start := Vector2i(int(z.spawn_pos.x / 16.0), int(z.spawn_pos.y / 16.0))
		var goal := Vector2i(int(z.mark("a").x / 16.0), int(z.mark("a").y / 16.0))
		var seen := {start: true}
		var q := [start]
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= z.w or n.y >= z.h:
					continue
				if z.is_wall(n.x, n.y):
					continue
				seen[n] = true
				q.append(n)
		check(seen.has(goal), "%s: the main route from the hub to the arena gate stays walkable" % id)

func sc_checkpoint_align() -> void:
	for id in ["arena_warden", "arena_regent"]:
		await go(id)
		var cp: Node2D = null
		for c in zone().floor_decor.get_children():
			if c is AnimatedSprite2D:
				cp = c
		check(cp != null and cp.global_position.distance_to(zone().spawn_pos) < 6.0, "%s: the checkpoint ring sits under the spawn point (off by %.1f px)" % [id, cp.global_position.distance_to(zone().spawn_pos)])
