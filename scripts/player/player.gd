class_name Player
extends CharacterBody2D
## The archer. One hit kills. Owns the single Arrow.

signal died
signal shot

const SPEED := 92.0
const ACCEL := 1100.0
const FRICTION := 1500.0
const DODGE_SPEED := 205.0
const DODGE_TIME := 0.27
const DODGE_IFRAMES := 0.27      # the whole roll: no damage at any moment of the dash
const DODGE_COOLDOWN := 0.28
const SHOOT_BUFFER := 0.12
const STAMINA_MAX := 100.0
const DODGE_COST := 34.0        # three rolls from full
const STAMINA_REGEN := 38.0     # per second
const STAMINA_DELAY := 0.55     # pause before regen starts after a roll
const ARROW_SCENE := preload("res://scenes/weapons/arrow.tscn")

var arrow: Arrow
var sprite: AnimatedSprite2D
var dead := false
var locked := false           # cutscene / fight-not-started lock
var invulnerable := false     # scripted invulnerability (endings)
var face := Vector2.DOWN
var dodging := 0.0
var dodge_dir := Vector2.DOWN
var dodge_cd := 0.0
var stamina := STAMINA_MAX
var stamina_pause := 0.0
var bar: StaminaBar
var shoot_pose := 0.0
var recall_pose := 0.0
var shoot_buffer := 0.0
var step_timer := 0.0
var _hurt_shape: CircleShape2D
var last_input := Vector2.ZERO
# ground modifiers a lair can set every frame (ice: low friction; quicksand: slow)
var speed_mult := 1.0
var accel_mult := 1.0
var friction_mult := 1.0

func _ready() -> void:
	collision_layer = L.PLAYER
	collision_mask = L.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.5
	cs.shape = c
	cs.position = Vector2(0, -3)
	add_child(cs)
	_hurt_shape = CircleShape2D.new()
	_hurt_shape.radius = 3.0
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	sprite.offset = Vector2(0, -11)
	add_child(sprite)
	sprite.play("idle_down")
	bar = StaminaBar.new()
	bar.player = self
	bar.z_index = 20
	add_child(bar)
	arrow = ARROW_SCENE.instantiate() as Arrow
	arrow.target = self
	arrow.name = "Arrow"
	# The zone adds the arrow beside the player so it can be y-sorted with everything else.

func _exit_tree() -> void:
	if arrow and is_instance_valid(arrow) and arrow.get_parent() == null:
		arrow.free()

func _build_frames() -> SpriteFrames:
	var anims := {}
	var dirs := ["down", "up", "side"]
	for d in 3:
		var row := d * 10
		anims["idle_" + dirs[d]] = {"frames": [row, row + 1], "fps": 2.5}
		anims["run_" + dirs[d]] = {"frames": [row + 2, row + 3, row + 4, row + 5], "fps": 11}
		anims["shoot_" + dirs[d]] = {"frames": [row + 6], "fps": 1}
		anims["recall_" + dirs[d]] = {"frames": [row + 7], "fps": 1}
		anims["dodge_" + dirs[d]] = {"frames": [row + 8, row + 9, row + 8, row + 9], "fps": 16, "loop": false}
	anims["death"] = {"frames": [30, 31, 32, 33], "fps": 8, "loop": false}
	return Gfx.sheet_frames("player/player.png", 24, 24, anims)

func aim_point() -> Vector2:
	if Game.aim_override != null:
		return Game.aim_override
	if Game.touch_mode:
		var d := Game.touch_aim if Game.touch_aim != Vector2.ZERO else face
		return global_position + d * 120.0
	return get_global_mouse_position()

func input_vec() -> Vector2:
	if locked or dead:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return
	dodge_cd = maxf(0.0, dodge_cd - delta)
	stamina_pause = maxf(0.0, stamina_pause - delta)
	if stamina_pause <= 0.0 and dodging <= 0.0:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
	shoot_pose = maxf(0.0, shoot_pose - delta)
	recall_pose = maxf(0.0, recall_pose - delta)
	shoot_buffer = maxf(0.0, shoot_buffer - delta)

	var iv := input_vec()
	last_input = iv
	if not locked:
		if Input.is_action_just_pressed("shoot"):
			shoot_buffer = SHOOT_BUFFER
		var want_recall := Input.is_action_pressed("recall")
		if want_recall and arrow.is_out():
			recall_pose = 0.15
		arrow.recall_input(want_recall)
		if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0 and dodging <= 0.0:
			if stamina >= DODGE_COST:
				_start_dodge(iv)
			else:
				bar.flash = 1.0
				Sfx.play("thud", -10.0, 1.6)
		if shoot_buffer > 0.0 and dodging <= 0.0 and arrow.is_held():
			_shoot()
	else:
		arrow.recall_input(false)

	if dodging > 0.0:
		dodging -= delta
		var k := clampf(dodging / DODGE_TIME, 0.0, 1.0)
		velocity = dodge_dir * DODGE_SPEED * (0.55 + 0.45 * k)
		if dodging <= 0.0:
			dodge_cd = DODGE_COOLDOWN
	else:
		if iv != Vector2.ZERO:
			velocity = velocity.move_toward(iv * SPEED * speed_mult, ACCEL * accel_mult * delta)
			face = iv
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * friction_mult * delta)
	move_and_slide()

	if not dead and not invulnerable:
		_check_hazards()
	_update_anim(iv, delta)

func _shoot() -> void:
	shoot_buffer = 0.0
	var origin := global_position + Arrow.HOLD_OFFSET
	var d := aim_point() - origin
	if d.length() < 4.0:
		d = face
	face = d.normalized()
	if arrow.fire(origin, d):
		shoot_pose = 0.16
		shot.emit()
		velocity -= face * 12.0

func _start_dodge(iv: Vector2) -> void:
	dodge_dir = iv if iv != Vector2.ZERO else (velocity.normalized() if velocity.length() > 10.0 else face.normalized())
	if dodge_dir == Vector2.ZERO:
		dodge_dir = Vector2.DOWN
	dodging = DODGE_TIME
	stamina -= DODGE_COST
	stamina_pause = STAMINA_DELAY
	face = dodge_dir
	Sfx.play("dodge")
	Fx.dust(get_parent(), global_position, 5)

func is_invulnerable() -> bool:
	return invulnerable or dodging > 0.0

func _check_hazards() -> void:
	if is_invulnerable():
		return
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _hurt_shape
	q.transform = Transform2D(0.0, global_position + Vector2(0, -5))
	q.collision_mask = L.HAZARD
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var res := get_world_2d().direct_space_state.intersect_shape(q, 8)
	for r in res:
		var h = r["collider"]
		if h is Hazard and h.active:
			die()
			return

func die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	sprite.play("death")
	sprite.flip_h = false
	Sfx.play("player_death")
	Game.hitstop(0.09)
	Game.add_trauma(0.7)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), [Color("dfe8f4"), Color("8fa8bf")], 22, 90.0, 0.7, 2.0, 120.0)
	RingFx.spawn(get_parent(), global_position + Vector2(0, -8), Color(1, 1, 1, 0.9), 2, 30, 0.25, 2.0)
	died.emit()

func _update_anim(iv: Vector2, delta: float) -> void:
	if dead:
		return
	var dir_name := "down"
	var flip := false
	var f := face
	if shoot_pose > 0.0 or recall_pose > 0.0:
		var a := aim_point() - global_position
		if a.length() > 2.0:
			f = a
	if absf(f.x) > absf(f.y) * 1.1:
		dir_name = "side"
		flip = f.x < 0.0
	elif f.y < 0.0:
		dir_name = "up"
	sprite.flip_h = flip
	var anim := "idle_" + dir_name
	if dodging > 0.0:
		anim = "dodge_" + dir_name
		sprite.flip_h = dodge_dir.x < 0.0
	elif shoot_pose > 0.0:
		anim = "shoot_" + dir_name
	elif recall_pose > 0.0:
		anim = "recall_" + dir_name
	elif velocity.length() > 12.0:
		anim = "run_" + dir_name
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.26
			Sfx.play("step", -14.0, 1.0, 0.15)
			Fx.dust(get_parent(), global_position, 1)
	if sprite.animation != anim:
		sprite.play(anim)
