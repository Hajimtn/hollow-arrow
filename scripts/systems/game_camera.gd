class_name GameCamera
extends Camera2D
## Follows the player with smoothing, clamps to the zone, shakes on trauma, punches zoom on impacts.

var base_zoom := 1.0
var zoom_tween: Tween

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	make_current()

func set_bounds(r: Rect2i) -> void:
	limit_left = r.position.x
	limit_top = r.position.y
	limit_right = r.position.x + r.size.x
	limit_bottom = r.position.y + r.size.y

func _process(_d: float) -> void:
	var t: float = Game.trauma
	if t > 0.0:
		var m := t * t * 9.0
		offset = Vector2(roundf(randf_range(-m, m)), roundf(randf_range(-m, m)))
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO

func punch(amount := 0.05, seconds := 0.3) -> void:
	if zoom_tween:
		zoom_tween.kill()
	zoom = Vector2.ONE * (base_zoom + amount)
	zoom_tween = create_tween().set_ignore_time_scale(true)
	zoom_tween.tween_property(self, "zoom", Vector2.ONE * base_zoom, seconds).set_ease(Tween.EASE_OUT)

func snap_to(p: Vector2) -> void:
	global_position = p
	reset_smoothing()
