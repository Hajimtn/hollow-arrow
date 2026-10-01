class_name Gate
extends Node2D
## A stone gate. Walk into it (when unlocked) to change zone.

var zone: Node
var target_zone := ""
var target_entry := "start"
var boss_id := ""
var big := false
var locked := false
var sprite: Sprite2D
var lights: Array[Sprite2D] = []
var _cool := 0.0
var _msg_cool := 0.0

func setup(z: Node, target: String, entry: String, boss: String, is_big: bool, is_locked: bool) -> void:
	zone = z
	target_zone = target
	target_entry = entry
	boss_id = boss
	big = is_big
	locked = is_locked
	sprite = Gfx.base_sprite(_tex())
	add_child(sprite)
	if boss_id != "" and not big:
		# small rune above the arch: lit when the guardian has fallen
		var l := Gfx.sprite("environment/rune_on.png" if Game.is_defeated(boss_id) else "environment/rune_off.png", Vector2(0, -sprite.texture.get_height() - 6))
		add_child(l)
		lights.append(l)

func _tex() -> String:
	var b := "gate_final" if big else "gate"
	return "environment/%s_%s.png" % [b, "locked" if locked else "open"]

func unlock(with_fx := true) -> void:
	locked = false
	sprite.texture = Gfx.tex(_tex())
	if with_fx:
		Sfx.play("unlock")
		Game.add_trauma(0.5)
		Fx.debris(get_parent(), global_position + Vector2(0, -24), [Color("8a7060"), Color("4a3a30")], 18)
		Fx.dust(get_parent(), global_position, 12)
		RingFx.spawn(get_parent(), global_position + Vector2(0, -20), Color("ffd070"), 4, 60, 0.6, 3.0)

func _physics_process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	_msg_cool = maxf(0.0, _msg_cool - delta)
	var p = zone.get("player")
	if p == null or bool(p.get("dead")):
		return
	var d: Vector2 = p.global_position - global_position
	var half := 30.0 if big else 20.0
	if absf(d.x) < half and d.y > -2.0 and d.y < 20.0:
		if locked:
			if _msg_cool <= 0.0:
				_msg_cool = 3.0
				Sfx.play("thud", -6.0)
				Game.say(_locked_text())
		elif _cool <= 0.0:
			_cool = 1.0
			zone.request_zone.emit(target_zone, target_entry)

func _locked_text() -> String:
	if boss_id == "twins":
		return "THE SEAL HOLDS. FELL %d GUARDIANS (%d/%d)" % [Game.TWINS_REQUIRED, Game.main_count(), Game.TWINS_REQUIRED]
	return "THE FINAL SEAL HOLDS. SIX GUARDIANS MUST FALL."
