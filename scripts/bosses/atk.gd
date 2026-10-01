class_name Atk
## Attack building blocks shared by every boss. A boss's personality lives in WHICH blocks it chains and with which animation.

static func shot(zone: Zone, pos: Vector2, dir: Vector2, speed: float, tex: String, r := 4.0, life := 6.0) -> Projectile:
	return Projectile.spawn(zone.entities, pos, dir.normalized() * speed, tex, r, life)

static func fan(zone: Zone, pos: Vector2, base: float, n: int, spread: float, speed: float, tex: String, r := 4.0, life := 6.0) -> void:
	for i in n:
		var a := base + (lerpf(-spread / 2.0, spread / 2.0, float(i) / float(n - 1)) if n > 1 else 0.0)
		Projectile.spawn(zone.entities, pos, Vector2.from_angle(a) * speed, tex, r, life)

static func ring(zone: Zone, pos: Vector2, n: int, speed: float, tex: String, off := 0.0, r := 4.0, life := 6.0) -> void:
	for i in n:
		Projectile.spawn(zone.entities, pos, Vector2.from_angle(TAU * i / n + off) * speed, tex, r, life)

static func homing(zone: Zone, pos: Vector2, dir: Vector2, speed: float, tex: String, turn: float, target: Node2D, r := 5.0, life := 5.0) -> Projectile:
	var p := Projectile.spawn(zone.entities, pos, dir.normalized() * speed, tex, r, life)
	p.homing = turn
	p.target = target
	return p

static func blast(zone: Zone, pos: Vector2, r: float, delay: float, col := Color(1.0, 0.45, 0.2), tex := "", mode := "fall", burst_life := 0.3) -> Blast:
	return Blast.spawn(zone.entities, pos, r, delay, col, tex, mode, burst_life)

## blasts along a line from `from` in `dir`, each one a little later than the last (a wave that travels)
static func line_blasts(zone: Zone, from: Vector2, dir: Vector2, n: int, gap: float, r: float, first: float, step_delay: float, col: Color, tex := "", mode := "rise") -> void:
	for i in n:
		var p := from + dir.normalized() * gap * (i + 1)
		p = Vector2(clampf(p.x, 20.0, zone.w * 16.0 - 20.0), clampf(p.y, 36.0, zone.h * 16.0 - 24.0))
		blast(zone, p, r, first + step_delay * i, col, tex, mode)

## a delayed ricocheting beam: `delay` after this call the path is computed from the boss node and fired
static func beam(boss: Node2D, zone: Zone, from: Vector2, dir: Vector2, delay: float, width: float, life: float, col: Color, bounces := 1) -> void:
	boss.get_tree().create_timer(delay).timeout.connect(func():
		if not is_instance_valid(boss) or not boss.is_inside_tree() or (boss as BossBase).dead:
			return
		var segs := BeamShot.compute(boss, from, dir, bounces)
		BeamShot.fire(zone.entities, segs, width, life, col)
		Sfx.play("beam", -2.0, 1.1)
		Game.add_trauma(0.25)
		for s in segs:
			Fx.sparks(zone.entities, s[1], 6))

static func clamp_in(zone: Zone, p: Vector2, margin := 22.0) -> Vector2:
	return Vector2(clampf(p.x, margin, zone.w * 16.0 - margin), clampf(p.y, 38.0, zone.h * 16.0 - 26.0))
