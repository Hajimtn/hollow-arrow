class_name ExitPortal
extends Node2D
## Appears after a boss dies; step in to return to the hub.

var zone: Node
var target_zone := "hub"
var target_entry := "start"
var armed_after := 0.8
var t := 0.0
var used := false

func setup(z: Node, target: String, entry: String) -> void:
	zone = z
	target_zone = target
	target_entry = entry
	var s := Gfx.strip("environment/portal.png", 36, 4, 8.0)
	add_child(s)
	scale = Vector2(0.01, 0.01)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("portal")

func _physics_process(delta: float) -> void:
	t += delta
	var p = zone.get("player")
	if used or p == null or bool(p.get("dead")) or t < armed_after:
		return
	if p.global_position.distance_to(global_position + Vector2(0, -6)) < 16.0:
		used = true
		zone.request_zone.emit(target_zone, target_entry)
