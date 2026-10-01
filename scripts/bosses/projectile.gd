class_name Projectile
extends Hazard
## A moving deadly orb/feather. Dies on walls or when its life runs out.

var vel := Vector2.ZERO
var life := 6.0
var sprite: Sprite2D
var rotate_to_vel := true
var spin := 0.0
var homing := 0.0                  # steering rate (rad/s) toward `target`; 0 = straight
var target: Node2D
var boomerang: Node2D              # when set: fly out for `turn_after` seconds, then come back to this node
var turn_after := 0.0
var speed_now := 0.0
var bounces_left := 0              # ricochets off walls instead of dying

static func spawn(parent: Node, pos: Vector2, velocity: Vector2, tex: String, radius := 4.0, lifetime := 6.0) -> Projectile:
	var p := Projectile.new()
	p.set_radius(radius)
	p.vel = velocity
	p.life = lifetime
	p.sprite = Gfx.sprite(tex)
	p.add_child(p.sprite)
	p.z_index = 2
	p.add_to_group("projectile")
	parent.add_child(p)
	p.global_position = pos
	return p

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if homing > 0.0 and target != null and is_instance_valid(target):
		var want := (target.global_position + Vector2(0, -6) - global_position).angle()
		vel = vel.rotated(clampf(angle_difference(vel.angle(), want), -homing * delta, homing * delta))
	if boomerang != null:
		if is_instance_valid(boomerang) and turn_after > 0.0:
			turn_after -= delta
			if turn_after <= 0.0:
				speed_now = vel.length()
		elif is_instance_valid(boomerang):
			var back := (boomerang.global_position - global_position)
			if back.length() < 10.0:
				queue_free()
				return
			vel = vel.lerp(back.normalized() * speed_now * 1.15, clampf(delta * 5.0, 0.0, 1.0))
	var to := global_position + vel * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, to + vel.normalized() * 2.0, L.WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		if bounces_left > 0:
			bounces_left -= 1
			vel = vel.bounce(r["normal"])
			global_position = r["position"] + r["normal"] * 2.0
			Fx.sparks(get_parent(), r["position"], 4)
			return
		Fx.burst(get_parent(), r["position"], [Color("ffffff"), Color("ffb040")], 5, 50.0, 0.25, 2.0)
		queue_free()
		return
	global_position = to
	if rotate_to_vel:
		sprite.rotation = vel.angle()
	else:
		sprite.rotation += spin * delta
