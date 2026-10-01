class_name Arrow
extends Node2D
## The player's single arrow. HELD -> FLYING -> (GROUND | STUCK) -> RETURNING -> HELD.
## Exactly one exists per player; it is created only by Player._ready().

enum State { HELD, FLYING, GROUND, STUCK, RETURNING }

signal caught
signal fired
signal state_changed(new_state: int)

const FLY_SPEED := 340.0
const RANGE := 250.0
const RET_MIN := 140.0
const RET_MAX := 440.0
const RET_ACCEL := 560.0
const COMMIT_TIME := 0.16
const MAX_BOUNCES := 5
const HOLD_OFFSET := Vector2(0, -7)

static var live_count := 0

var state: int = State.HELD
var target: Node2D            # the player
var vel := Vector2.ZERO
var dir := Vector2.RIGHT
var traveled := 0.0
var bounces := 0
var ret_speed := 0.0
var recall_pressed := false
var _recall_prev := false
var recall_time := 0.0
var ignore_armor: Armor = null
var ignore_time := 0.0
var sprite: Sprite2D
var trail: Line2D
var glint := 0.0
var _shape: CircleShape2D
var zone_fx: Node = null      # node used as parent for particles
# status effects a lair or boss can put on the arrow
var block_t := 0.0            # >0: cannot be recalled (frozen in ice / digging out of the sand)
var frozen := false
var buried := false
var wind := Vector2.ZERO      # px/s^2 sideways push while flying
var fly_mult := 1.0           # flight speed multiplier of the ground it is over
var ret_mult := 1.0
var _wait_recall := false
var ice: Sprite2D
var blessed_t := 0.0          # >0: the arrow carries lantern light and can hurt a ghost
var bless_fx: Node2D
var stolen_by: Node2D = null   # the Sky Hunter carries the arrow; recall pulls it back from its hands

func _init() -> void:
	live_count += 1
	if live_count > 1:
		push_error("More than one arrow exists!")

func _exit_tree() -> void:
	live_count -= 1

func _ready() -> void:
	z_index = 2
	sprite = Gfx.sprite("player/arrow.png")
	add_child(sprite)
	bless_fx = Node2D.new()
	bless_fx.visible = false
	bless_fx.z_index = -1
	bless_fx.draw.connect(func():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		bless_fx.draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.85, 0.4, 0.22 + 0.15 * pulse))
		bless_fx.draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.95, 0.7, 0.45)))
	add_child(bless_fx)
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 2.0
	trail.z_index = 1
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.9, 0.6, 0.0), Color(1, 0.95, 0.75, 0.9)])
	trail.gradient = g
	add_child(trail)
	_shape = CircleShape2D.new()
	_shape.radius = 2.5
	_set_state(State.HELD)

func is_held() -> bool:
	return state == State.HELD

func is_out() -> bool:
	return state != State.HELD

func fire(from: Vector2, direction: Vector2) -> bool:
	if state != State.HELD:
		return false
	dir = direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	vel = dir * FLY_SPEED
	global_position = from
	traveled = 0.0
	bounces = 0
	ignore_armor = null
	_set_state(State.FLYING)
	sprite.rotation = dir.angle()
	Sfx.play("shoot")
	fired.emit()
	return true

func force_hold() -> void:
	_set_state(State.HELD)

func _set_state(s: int) -> void:
	state = s
	visible = s != State.HELD
	if s == State.HELD:
		trail.clear_points()
		vel = Vector2.ZERO
	if s == State.STUCK or s == State.GROUND:
		vel = vel if s == State.GROUND else Vector2.ZERO
	state_changed.emit(s)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	blessed_t = maxf(0.0, blessed_t - delta)
	bless_fx.visible = blessed_t > 0.0 and state != State.HELD
	if bless_fx.visible:
		bless_fx.queue_redraw()
	ignore_time = maxf(0.0, ignore_time - delta)
	if ignore_time <= 0.0:
		ignore_armor = null
	var pressed := recall_pressed
	if block_t > 0.0:
		block_t -= delta
		if block_t <= 0.0:
			_thaw()
	if pressed and (not _recall_prev or _wait_recall) and (state == State.FLYING or state == State.GROUND or state == State.STUCK):
		_begin_recall()
	_recall_prev = pressed
	match state:
		State.HELD:
			global_position = target.global_position + HOLD_OFFSET
		State.FLYING:
			_step_flying(delta)
		State.GROUND:
			if stolen_by != null and is_instance_valid(stolen_by):
				global_position = stolen_by.global_position + Vector2(0, -22)
				glint += delta
				sprite.modulate = Color.WHITE.lerp(Color(1.4, 1.3, 1.0), 0.5 + 0.5 * sin(glint * 10.0))
			else:
				stolen_by = null
				_step_ground(delta)
		State.RETURNING:
			_step_returning(delta)
		State.STUCK:
			glint += delta
			sprite.modulate = Color.WHITE.lerp(Color(1.4, 1.3, 1.0), 0.5 + 0.5 * sin(glint * 6.0))
	_update_trail()

func _update_trail() -> void:
	if state == State.FLYING or state == State.RETURNING:
		trail.add_point(global_position)
		while trail.get_point_count() > 8:
			trail.remove_point(0)
	elif trail.get_point_count() > 0:
		trail.remove_point(0)

# ------------------------------------------------------------------ queries
func _ray(a: Vector2, b: Vector2):
	var q := PhysicsRayQueryParameters2D.create(a, b, L.WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	return r if not r.is_empty() else null

func _areas_at(p: Vector2) -> Array:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape
	q.transform = Transform2D(0.0, p)
	q.collision_mask = L.WEAK | L.ARMOR | L.SWITCH
	q.collide_with_areas = true
	q.collide_with_bodies = false
	return get_world_2d().direct_space_state.intersect_shape(q, 12)

## Returns true when the arrow's step should stop (contact consumed the motion).
func _handle_areas(p: Vector2, kind: String) -> bool:
	var hits := _areas_at(p)
	if hits.is_empty():
		return false
	var weak: WeakPoint = null
	var sw: RuneSwitch = null
	var armor: Armor = null
	for h in hits:
		var c = h["collider"]
		if c is WeakPoint and c.armed and weak == null:
			weak = c
		elif c is RuneSwitch and sw == null:
			sw = c
		elif c is Armor and c.enabled and c != ignore_armor and armor == null:
			armor = c
	if weak and weak.try_hit(kind, self):
		global_position = p
		_on_weak_hit(kind)
		return kind == "fly"
	if sw and sw.enabled and not (sw.on and sw.one_shot) and not sw.accepts(kind):
		# a rune that only answers to a recalled arrow: a flying one just clinks off
		global_position = p
		Sfx.play("arrow_clink")
		Fx.sparks(_fx_parent(), p, 6)
		_drop(-dir * 40.0)
		return true
	if sw and sw.enabled and not (sw.on and sw.one_shot):
		global_position = p
		sw.strike()
		Fx.sparks(_fx_parent(), p, 8)
		Sfx.play("switch")
		Game.add_trauma(0.25)
		if kind == "fly":
			_drop(-dir * 20.0)
			return true
		return false
	if armor:
		var m: int = armor.mode_for(kind)
		if m == Armor.Mode.PASS:
			return false
		var n: Vector2 = armor.normal_at(p)
		global_position = p
		armor.clanked.emit(p, kind)
		match m:
			Armor.Mode.BOUNCE:
				if kind == "fly":
					vel = vel.bounce(n) if vel.dot(n) < 0.0 else vel
					dir = vel.normalized()
					sprite.rotation = dir.angle()
					global_position = p + n * 3.0
					ignore_armor = armor
					ignore_time = 0.08
					Sfx.play("reflect")
					Fx.sparks(_fx_parent(), p, 8)
					Game.add_trauma(0.12)
					return true
				_drop(n * 70.0)
				return true
			Armor.Mode.STICK:
				_stick(p)
				return true
			_:
				Sfx.play("arrow_clink")
				Fx.sparks(_fx_parent(), p, 6)
				Game.add_trauma(0.15)
				_drop(n * 80.0)
				return true
	return false

func _on_weak_hit(kind: String) -> void:
	Fx.sparks(_fx_parent(), global_position, 16)
	Sfx.play("weak_hit")
	Game.hitstop(0.09)
	Game.add_trauma(0.6)
	if kind == "fly":
		vel = Vector2.ZERO
		_set_state(State.GROUND)

func _fx_parent() -> Node:
	return get_parent() if get_parent() else self

func _drop(push: Vector2) -> void:
	vel = push
	_set_state(State.GROUND)

func _stick(p: Vector2) -> void:
	global_position = p
	vel = Vector2.ZERO
	_set_state(State.STUCK)
	Sfx.play("arrow_wall")
	Fx.dust(_fx_parent(), p, 4)
	Game.add_trauma(0.12)

# ------------------------------------------------------------------ steps
func _step_flying(delta: float) -> void:
	if wind != Vector2.ZERO:
		vel = (vel + wind * delta).normalized() * vel.length()
		dir = vel.normalized()
	var motion := vel * delta * fly_mult
	var from := global_position
	var wall = _ray(from, from + motion + motion.normalized() * 1.5)
	var frac_wall := 9.0
	if wall != null:
		frac_wall = from.distance_to(wall["position"]) / maxf(motion.length(), 0.001)
	for f in [0.34, 0.67, 1.0]:
		if f > frac_wall:
			break
		if _handle_areas(from + motion * f, "fly"):
			return
	if wall != null:
		_hit_wall(wall)
		return
	global_position = from + motion
	traveled += motion.length()
	sprite.rotation = vel.angle()
	if traveled > RANGE:
		_set_state(State.GROUND)
		# keep sliding a little

func _hit_wall(hit: Dictionary) -> void:
	var col = hit["collider"]
	var n: Vector2 = hit["normal"]
	if col is Node and (col as Node).is_in_group("crystal") and bounces < MAX_BOUNCES:
		bounces += 1
		vel = vel.bounce(n)
		dir = vel.normalized()
		global_position = hit["position"] + n * 1.5
		sprite.rotation = dir.angle()
		traveled = maxf(0.0, traveled - 60.0)
		Sfx.play("reflect")
		Fx.burst(_fx_parent(), global_position, [Color("e0f8ff"), Color("6ad0ff")], 8, 90.0, 0.3, 2.0)
		Game.add_trauma(0.1)
		return
	_stick(hit["position"] + vel.normalized() * 2.0)
	if col is Node and (col as Node).has_method("on_arrow_stuck"):
		(col as Node).on_arrow_stuck(self)

func _step_ground(delta: float) -> void:
	glint += delta
	sprite.modulate = Color.WHITE.lerp(Color(1.4, 1.3, 1.0), 0.5 + 0.5 * sin(glint * 6.0))
	if vel.length() > 3.0:
		var motion := vel * delta
		var wall = _ray(global_position, global_position + motion + motion.normalized() * 1.5)
		if wall != null:
			_stick(wall["position"] + motion.normalized() * 1.5)
			return
		global_position += motion
		vel = vel.move_toward(Vector2.ZERO, 420.0 * delta)
		sprite.rotation = vel.angle() if vel.length() > 20.0 else sprite.rotation
	# walk-over pickup
	if not bool(target.get("dead")) and target.global_position.distance_to(global_position + Vector2(0, 6)) < 11.0:
		_catch()

## Encases the arrow in ice: it cannot be recalled until it thaws.
func freeze(seconds: float) -> void:
	if state == State.HELD or state == State.RETURNING:
		return
	frozen = true
	block_t = maxf(block_t, seconds)
	if ice == null:
		ice = Gfx.sprite("bosses/ice_slab.png")
		ice.scale = Vector2(0.55, 0.42)
		ice.modulate = Color(1, 1, 1, 0.85)
		ice.z_index = 1
		add_child(ice)
	ice.visible = true
	Sfx.play("shatter", -12.0, 1.6)
	Fx.burst(_fx_parent(), global_position, [Color("e8f8ff"), Color("8fd0ff")], 8, 50.0, 0.4, 2.0)

func bury() -> void:
	if buried or state == State.HELD:
		return
	buried = true
	sprite.modulate.a = 0.55
	Fx.dust(_fx_parent(), global_position, 6)

func _thaw() -> void:
	if frozen:
		frozen = false
		if ice:
			ice.visible = false
		Sfx.play("shatter", -10.0, 1.3)
		Fx.burst(_fx_parent(), global_position, [Color("ffffff"), Color("8fd0ff")], 10, 70.0, 0.4, 2.0)

func _begin_recall() -> void:
	if block_t > 0.0:
		if not _wait_recall:
			Sfx.play("arrow_clink", -6.0, 1.4)
			_wait_recall = true
		return
	if buried:
		buried = false
		sprite.modulate.a = 1.0
		block_t = 0.55            # digging it out
		_wait_recall = true
		Fx.dust(_fx_parent(), global_position, 8)
		return
	_wait_recall = false
	ret_speed = RET_MIN
	recall_time = 0.0
	ignore_armor = null
	if stolen_by != null and is_instance_valid(stolen_by):
		# recalled out of the thief's hands: fly straight through it (its armour must not swallow the arrow)
		var ar = stolen_by.get("armor")
		if ar is Armor:
			ignore_armor = ar
			ignore_time = 0.5
	stolen_by = null
	sprite.modulate = Color.WHITE
	_set_state(State.RETURNING)
	Sfx.play("recall")

func _step_returning(delta: float) -> void:
	recall_time += delta
	if not recall_pressed and recall_time > COMMIT_TIME:
		# released early: leave the arrow where it is (placement)
		vel = dir * ret_speed * 0.35
		_set_state(State.GROUND)
		return
	var goal: Vector2 = target.global_position + HOLD_OFFSET
	ret_speed = minf(RET_MAX, ret_speed + RET_ACCEL * delta) * 1.0
	var to_goal := goal - global_position
	var dist := to_goal.length()
	if dist < 9.0:
		_catch()
		return
	dir = to_goal / dist
	var step := minf(dist, ret_speed * ret_mult * delta)
	var from := global_position
	var motion := dir * step
	for f in [0.34, 0.67, 1.0]:
		if _handle_areas(from + motion * f, "ret"):
			return
	global_position = from + motion
	sprite.rotation = dir.angle()

func _catch() -> void:
	buried = false
	frozen = false
	block_t = 0.0
	if ice:
		ice.visible = false
	sprite.modulate.a = 1.0
	_set_state(State.HELD)
	sprite.modulate = Color.WHITE
	Sfx.play("catch")
	caught.emit()

func recall_input(pressed: bool) -> void:
	recall_pressed = pressed
