class_name Menu
extends Control
## Keyboard + mouse driven vertical menu with buttons, sliders and toggles.

signal cancelled

var items: Array = []
var index := 0
var labels: Array[Label] = []
var title_label: Label
var top_y := 120.0
var spacing := 20.0
var active := true
var big := true

const PAL_CREAM := Color("f7efdf")
const PAL_BEIGE := Color("c3bfad")
const PAL_TAN := Color("aa9a92")
const PAL_ORANGE := Color("ef8d35")
const PAL_MUTE := Color("71667f")
const PAL_DARK := Color("242020")

static var font_big: Font
static var font_small: Font

static func fonts() -> void:
	if font_big == null:
		font_big = load("res://assets/ui/font_big.fnt")
		font_small = load("res://assets/ui/font_small.fnt")

## A framed pixel panel in the game's palette (dark fill, beige double border).
static func make_panel(rect: Rect2, alpha := 0.9) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAL_DARK, alpha)
	sb.border_color = PAL_TAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	var inner := Panel.new()
	inner.position = Vector2(3, 3)
	inner.size = rect.size - Vector2(6, 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0, 0, 0, 0)
	sb2.border_color = Color(PAL_MUTE, 0.9)
	sb2.set_border_width_all(1)
	sb2.anti_aliasing = false
	inner.add_theme_stylebox_override("panel", sb2)
	p.add_child(inner)
	return p

static func make_label(text: String, is_big := false, color := Color.WHITE, width := 480.0) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_big if is_big else font_small)
	l.add_theme_font_size_override("font_size", 16 if is_big else 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func setup(title: String, item_list: Array, y := 120.0, sp := 20.0, use_big := true) -> void:
	items = item_list
	top_y = y
	spacing = sp
	big = use_big
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title != "":
		title_label = make_label(title, true, PAL_ORANGE)
		title_label.position = Vector2(0, y - 34)
		add_child(title_label)
	for i in items.size():
		var l := make_label("", big)
		l.position = Vector2(0, y + i * sp)
		add_child(l)
		labels.append(l)
	index = _first_enabled(0, 1)
	refresh()

func _first_enabled(from: int, step: int) -> int:
	var i := from
	for n in items.size():
		if items[i].get("enabled", true):
			return i
		i = (i + step + items.size()) % items.size()
	return 0

func refresh() -> void:
	for i in items.size():
		var it: Dictionary = items[i]
		var txt: String = it["text"]
		match it.get("kind", "button"):
			"slider":
				var v: float = it["get"].call()
				txt = "%s <%d%%>" % [txt, int(round(v * 100.0))]
			"toggle":
				txt = "%s: %s" % [txt, "ON" if it["get"].call() else "OFF"]
			"choice":
				txt = "%s <%s>" % [txt, it["get"].call()]
		var sel := i == index
		var enabled: bool = it.get("enabled", true)
		if sel:
			txt = "> " + txt + " <"
		labels[i].text = txt
		var c := PAL_CREAM if sel else PAL_TAN
		if not enabled:
			c = PAL_MUTE
		labels[i].add_theme_color_override("font_color", c)

func _move(step: int) -> void:
	var i := index
	for n in items.size():
		i = (i + step + items.size()) % items.size()
		if items[i].get("enabled", true):
			break
	if i != index:
		index = i
		Sfx.play("ui_move", -6.0, 1.0, 0.0)
		refresh()

func _adjust(dir: int) -> void:
	var it: Dictionary = items[index]
	var k: String = it.get("kind", "button")
	if k == "slider":
		var v: float = it["get"].call()
		it["set"].call(clampf(snappedf(v + dir * 0.1, 0.1), 0.0, 1.0))
	elif k == "toggle":
		it["set"].call(not it["get"].call())
	elif k == "choice":
		it["set"].call(dir)
	else:
		return
	Sfx.play("ui_move", -4.0, 1.2, 0.0)
	refresh()

func _activate() -> void:
	var it: Dictionary = items[index]
	if not it.get("enabled", true):
		return
	var k: String = it.get("kind", "button")
	if k == "button":
		Sfx.play("ui_select", -2.0, 1.0, 0.0)
		it["cb"].call()
	elif k == "toggle":
		_adjust(1)
	elif k == "choice":
		_adjust(1)

func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree() or items.is_empty():
		return
	var mp := Vector2.ZERO
	if event is InputEventMouse:
		mp = (make_input_local(event) as InputEventMouse).position     # the event's own position: a finger has no cursor to ask
	if event is InputEventMouseMotion:
		for i in labels.size():
			var r := Rect2(labels[i].position + Vector2(140, 0), Vector2(200, spacing - 2))
			if r.has_point(mp) and items[i].get("enabled", true) and i != index:
				index = i
				Sfx.play("ui_move", -6.0, 1.0, 0.0)
				refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Game.touch_mode:
		# a fingertip is fat and lands low: take the row nearest to the touch instead of demanding a hit on the text
		var best := -1
		var best_d := spacing * 0.9
		for i in labels.size():
			var h := labels[i].size.y if labels[i].size.y > 0.0 else spacing
			var d := absf(labels[i].position.y + h * 0.5 - mp.y)
			if d < best_d and items[i].get("enabled", true):
				best_d = d
				best = i
		if best >= 0 and mp.x > 40.0 and mp.x < 440.0:
			index = best
			refresh()
			var k: String = items[best].get("kind", "button")
			if k == "slider":
				_adjust(1 if mp.x >= labels[best].position.x + labels[best].size.x * 0.5 else -1)     # right half = up, left half = down
			else:
				_activate()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in labels.size():
			var r := Rect2(labels[i].position + Vector2(140, 0), Vector2(200, spacing - 2))
			if r.has_point(mp):
				index = i
				refresh()
				_activate()
				get_viewport().set_input_as_handled()
				return
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_adjust(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_adjust(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
