class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets, all fixed in place: the move stick bottom left, the shoot stick bottom right, ROLL beside it and a
## pause button. While the arrow is in hand the shoot stick aims (drag, let go to shoot, a quick tap shoots along the last aim) and a dotted
## line from the hero shows the shot in the game; once the arrow is out, the next touch on it is RECALL (hold).
## Outside gameplay (title, menus, cutscenes) a tap is turned into a mouse click so every menu works with a finger.
## The controls appear at the first touch, so desktop players never see them.

const MOVE_C := Vector2(76, 204)
const AIM_C := Vector2(408, 204)
const BTN_R := 29.0
const BTN_POS := {"dodge": Vector2(320, 228)}
const PAUSE_RECT := Rect2(220, 3, 40, 26)
const STICK_R := 44.0
const GRAB_R := 62.0                    # a thumb landing this close to a stick's centre takes it
const KNOB_R := 17.0
const KNOB_MAX := 38.0
const FIRE_MIN := 9.0
const AIM_LINE_MAX := 420.0
const INK := Color("f7efdf")
const SHADE := Color("242020")

var main: Node
var pad: Control
var rotate_label: Label
var shown := false
var was_playing := false
var fingers := {}                     # finger id -> {"role": String, "origin": Vector2, "pos": Vector2}
var held := {}                        # action -> strength currently pressed by us

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad = Control.new()
	pad.size = Vector2(480, 270)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.draw.connect(_draw_pad)
	add_child(pad)
	var back := ColorRect.new()
	back.name = "RotateBack"
	back.color = Color(SHADE, 0.96)
	back.size = Vector2(480, 270)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.visible = false
	add_child(back)
	rotate_label = Menu.make_label("TURN YOUR DEVICE SIDEWAYS", true, Menu.PAL_CREAM)
	rotate_label.position = Vector2(0, 118)
	back.add_child(rotate_label)
	if Game.touch_mode:
		_show()

func _show() -> void:
	if shown:
		return
	shown = true
	Game.touch_mode = true
	# a phone screen is not a multiple of 480x270: let the picture fill it instead of sitting small in the middle
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL

func _hide() -> void:
	shown = false
	Game.touch_mode = false
	_release_all()
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER

func is_gameplay() -> bool:
	return main != null and main.state == "play" and main.zone != null and not main.transitioning and not get_tree().paused

func _process(_delta: float) -> void:
	var playing := shown and is_gameplay()
	if was_playing and not playing:
		_release_all()
	was_playing = playing
	var win := get_window().size
	var portrait := shown and win.y > win.x
	get_node("RotateBack").visible = portrait
	if portrait and playing and not Autotest.enabled:
		main._open_pause()                        # nobody fights a boss through a letterbox
	pad.visible = shown and not portrait
	if pad.visible:
		pad.queue_redraw()

# ------------------------------------------------------------------ events
func _input(event: InputEvent) -> void:
	if shown and not Game.touch_debug and event is InputEventKey and event.pressed:
		_hide()                                   # a keyboard means this is a laptop after all
		return
	var id := -1
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var drag := false
	if event is InputEventScreenTouch:
		id = event.index
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag:
		id = event.index
		pos = event.position
		drag = true
	elif Game.touch_debug and is_gameplay():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			id = 99
			pos = event.position
			down = event.pressed
			up = not event.pressed
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			id = 99
			pos = event.position
			drag = true
	if id < 0:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_show()
	if not is_gameplay():
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			_as_mouse(pos, down, up)
		return
	get_viewport().set_input_as_handled()
	if down:
		_touch_down(id, pos)
	elif up:
		_touch_up(id, pos)
	elif drag and fingers.has(id):
		_touch_move(id, pos)

## menus, title and cutscenes only understand the mouse
func _as_mouse(pos: Vector2, down: bool, up: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if not up else 0
	get_viewport().push_input(m, true)
	if down or up:
		var b := InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(b, true)

func _role_at(pos: Vector2) -> String:
	for k in BTN_POS:
		if pos.distance_to(BTN_POS[k]) <= BTN_R + 8.0:
			return k
	if PAUSE_RECT.grow(8.0).has_point(pos):
		return "pause"
	if pos.distance_to(MOVE_C) <= GRAB_R:
		return "move"
	if pos.distance_to(AIM_C) <= GRAB_R:
		return "aim"
	return ""

func _arrow_out() -> bool:
	return main != null and main.zone != null and main.zone.arrow != null and main.zone.arrow.is_out()

func _has_role(role: String) -> bool:
	for f in fingers.values():
		if f["role"] == role:
			return true
	return false

func _touch_down(id: int, pos: Vector2) -> void:
	var role := _role_at(pos)
	if role == "aim" and _arrow_out():
		role = "recall"                          # the shoot control doubles as the recall button while the arrow is away
	if role == "" or _has_role(role) or (role == "recall" and _has_role("aim")):
		return
	var fixed := {"move": MOVE_C, "aim": AIM_C, "recall": AIM_C}
	fingers[id] = {"role": role, "origin": fixed.get(role, pos), "pos": pos}
	match role:
		"dodge":
			_tap("dodge")
		"recall":
			_set_action("recall", 1.0)
		"pause":
			_tap("pause")
		"aim":
			_update_aim(id)

func _touch_move(id: int, pos: Vector2) -> void:
	fingers[id]["pos"] = pos
	match fingers[id]["role"]:
		"move":
			_update_move(id)
		"aim":
			_update_aim(id)

func _touch_up(id: int, _pos: Vector2) -> void:
	if not fingers.has(id):
		return
	var f: Dictionary = fingers[id]
	fingers.erase(id)
	match f["role"]:
		"move":
			_set_move(Vector2.ZERO)
		"recall":
			_set_action("recall", 0.0)
		"aim":
			# releasing the aim stick looses the arrow (a tap without dragging shoots along the last aim)
			_tap("shoot")

func _update_move(id: int) -> void:
	var f: Dictionary = fingers[id]
	var d: Vector2 = f["pos"] - f["origin"]
	var v := d / KNOB_MAX
	if v.length() < 0.18:
		v = Vector2.ZERO
	_set_move(v.limit_length(1.0))

func _update_aim(id: int) -> void:
	var f: Dictionary = fingers[id]
	var d: Vector2 = f["pos"] - f["origin"]
	if d.length() > FIRE_MIN * 0.5:
		Game.touch_aim = d.normalized()

# ------------------------------------------------------------------ actions
func _set_action(action: String, strength: float) -> void:
	var was: float = held.get(action, 0.0)
	if is_equal_approx(was, strength):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = strength > 0.0
	e.strength = strength
	Input.parse_input_event(e)
	if strength > 0.0:
		held[action] = strength
	else:
		held.erase(action)

func _set_move(v: Vector2) -> void:
	_set_action("move_left", maxf(0.0, -v.x))
	_set_action("move_right", maxf(0.0, v.x))
	_set_action("move_up", maxf(0.0, -v.y))
	_set_action("move_down", maxf(0.0, v.y))

## a press that lasts long enough for a physics tick to see it
func _tap(action: String) -> void:
	_set_action(action, 1.0)
	await get_tree().create_timer(0.09, true, true).timeout
	_set_action(action, 0.0)

func _release_all() -> void:
	fingers.clear()
	for a in held.keys():
		_set_action(a, 0.0)

# ------------------------------------------------------------------ drawing
func _draw_pad() -> void:
	if not is_gameplay():
		return
	_draw_stick(MOVE_C, _finger_of("move"), "")
	var ai := _finger_of("aim")
	var rc := _finger_of("recall")
	var out := _arrow_out()
	_draw_stick(AIM_C, ai if not ai.is_empty() else rc, "RECALL" if out else "aim")
	if not ai.is_empty():
		_draw_aim_line()
	for k in BTN_POS:
		_draw_btn(BTN_POS[k], BTN_R, "ROLL", held.get(k, 0.0) > 0.0)
	pad.draw_rect(PAUSE_RECT, Color(SHADE, 0.45))
	pad.draw_rect(PAUSE_RECT, Color(INK, 0.35), false, 1.0)
	pad.draw_rect(Rect2(PAUSE_RECT.position + Vector2(14, 6), Vector2(4, 14)), Color(INK, 0.6))
	pad.draw_rect(Rect2(PAUSE_RECT.position + Vector2(22, 6), Vector2(4, 14)), Color(INK, 0.6))

## the dotted shot line from the hero, stopping at the first wall
func _draw_aim_line() -> void:
	if main == null or main.zone == null or main.zone.player == null or Game.touch_aim == Vector2.ZERO:
		return
	var pl: Player = main.zone.player
	if not main.zone.arrow.is_held() or pl.dead:
		return
	var origin := pl.global_position + Arrow.HOLD_OFFSET
	var dir := (pl.aim_point() - origin).normalized()
	var to := origin + dir * AIM_LINE_MAX
	var q := PhysicsRayQueryParameters2D.create(origin, to, L.WORLD)
	var hit := pl.get_world_2d().direct_space_state.intersect_ray(q)
	var end: Vector2 = hit["position"] if not hit.is_empty() else to
	var xf := pl.get_viewport().get_canvas_transform()
	var a := xf * origin
	var b := xf * end
	var n := int(a.distance_to(b) / 7.0)
	for k in range(1, n + 1):
		var t := float(k) / float(n + 1)
		var col := Color(INK, 0.85 * (1.0 - t * 0.6))
		pad.draw_circle(a.lerp(b, t), 1.4, col)
	pad.draw_arc(b, 4.0, 0.0, TAU, 16, Color(INK, 0.9), 1.0)
	pad.draw_circle(b, 1.2, Color(INK, 0.9))

func _finger_of(role: String) -> Dictionary:
	for f in fingers.values():
		if f["role"] == role:
			return f
	return {}

func _draw_stick(base: Vector2, f: Dictionary, label: String) -> void:
	var live := not f.is_empty()
	var knob := base
	var recall: bool = live and f["role"] == "recall"
	if live and not recall:
		var fp: Vector2 = f["pos"]
		knob = base + (fp - base).limit_length(KNOB_MAX)
	var a := 0.7 if live else 0.42
	pad.draw_circle(base, STICK_R, Color(SHADE, 0.7 if live else 0.5))
	pad.draw_arc(base, STICK_R, 0.0, TAU, 48, Color(INK, a + 0.1), 1.0)
	if label == "aim":
		# a hollow arrow in the stick shows what it does and where it points
		var d := Game.touch_aim if Game.touch_aim != Vector2.ZERO else Vector2.UP
		var tip := base + d * (STICK_R - 5.0)
		pad.draw_line(base + d * 8.0, tip, Color(INK, a + 0.15), 1.0)
		pad.draw_line(tip, tip - d.rotated(0.5) * 8.0, Color(INK, a + 0.15), 1.0)
		pad.draw_line(tip, tip - d.rotated(-0.5) * 8.0, Color(INK, a + 0.15), 1.0)
	pad.draw_circle(knob, KNOB_R, Color(INK, (0.5 if live else 0.3) if label != "RECALL" else (0.7 if recall else 0.4)))
	pad.draw_arc(knob, KNOB_R, 0.0, TAU, 28, Color(INK, a + 0.15), 1.0)
	if label == "RECALL":
		Menu.fonts()
		var sz := Menu.font_small.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		pad.draw_string(Menu.font_small, knob + Vector2(-sz.x / 2.0, 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(SHADE, 0.95))

func _draw_btn(c: Vector2, r: float, text: String, on: bool) -> void:
	var a := 0.7 if on else 0.4
	pad.draw_circle(c, r, Color(SHADE, 0.75 if on else 0.5))
	pad.draw_arc(c, r, 0.0, TAU, 40, Color(INK, a + 0.15), 1.0)
	Menu.fonts()
	var sz := Menu.font_small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	pad.draw_string(Menu.font_small, c + Vector2(-sz.x / 2.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, a + 0.25))
