class_name StaminaBar
extends Node2D
## Tiny pixel bar under the archer showing dodge stamina. Fades out when full.

var player: Player
var alpha := 0.0
var flash := 0.0

func _process(delta: float) -> void:
	if player == null:
		return
	var full: bool = player.stamina >= Player.STAMINA_MAX - 0.01
	var target := 0.0 if full else 1.0
	alpha = move_toward(alpha, target, delta * (6.0 if not full else 2.5))
	flash = maxf(0.0, flash - delta * 4.0)
	visible = alpha > 0.01
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var w := 22.0
	var h := 3.0
	var origin := Vector2(-w / 2.0, 5.0)
	var k := clampf(player.stamina / Player.STAMINA_MAX, 0.0, 1.0)
	var ready: bool = player.stamina >= Player.DODGE_COST
	var col := Color("ffd45a") if ready else Color("e8503a")
	if flash > 0.0:
		col = Color.WHITE
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0.07, 0.05, 0.1, 0.85 * alpha))
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0.2, 0.17, 0.27, 0.9 * alpha))
	draw_rect(Rect2(origin, Vector2(roundf(w * k), h)), Color(col, alpha))
	# tick showing how much one roll costs
	var tx := roundf(w * Player.DODGE_COST / Player.STAMINA_MAX)
	draw_rect(Rect2(origin + Vector2(tx, 0), Vector2(1, h)), Color(0.07, 0.05, 0.1, 0.9 * alpha))
