extends Node
## Root scene: title screen, zone lifecycle, fades, pause/settings menus, intro, ending and credits.

var world: Node2D
var ui: CanvasLayer
var fade: ColorRect
var zone: Zone
var title_root: Control
var menu: Menu
var settings_menu: Menu
var pause_root: Control
var toast_label: Label
var deaths_label: Label
var banner_title: Label
var banner_sub: Label
var state := "title"
var transitioning := false
var toast_tween: Tween
var banner_tween: Tween
var skip_pressed := false
var touch: TouchControls

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_build_overlay_labels()
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = Vector2(480, 270)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl := CanvasLayer.new()
	fl.layer = 100
	add_child(fl)
	fl.add_child(fade)
	var cur := load("res://assets/ui/crosshair.png")
	Input.set_custom_mouse_cursor(cur, Input.CURSOR_ARROW, Vector2(16, 16))
	Game.toast.connect(_on_toast)
	Game.banner.connect(_on_banner)
	touch = TouchControls.new()
	touch.main = self
	add_child(touch)
	if not Autotest.enabled:
		show_title()

func _build_overlay_labels() -> void:
	toast_label = Menu.make_label("", false, Menu.PAL_CREAM, 440.0)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.position = Vector2(20, 236)
	toast_label.modulate.a = 0.0
	ui.add_child(toast_label)
	banner_title = Menu.make_label("", true, Menu.PAL_CREAM)
	banner_title.position = Vector2(0, 34)
	banner_title.modulate.a = 0.0
	ui.add_child(banner_title)
	banner_sub = Menu.make_label("", false, Menu.PAL_BEIGE)
	banner_sub.position = Vector2(0, 56)
	banner_sub.modulate.a = 0.0
	ui.add_child(banner_sub)
	deaths_label = Menu.make_label("", false, Menu.PAL_BEIGE, 200.0)
	deaths_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deaths_label.position = Vector2(274, 4)
	deaths_label.modulate.a = 0.85
	deaths_label.visible = false
	ui.add_child(deaths_label)
	Game.deaths_changed.connect(_refresh_deaths)

## "DEATHS 7" in the corner; inside a boss arena also "THIS FIGHT 3"
func _refresh_deaths() -> void:
	if deaths_label == null:
		return
	var txt := "DEATHS  %d" % Game.deaths
	if zone != null and zone.kind == "arena" and zone.boss_id != "":
		txt += "\nTHIS FIGHT  %d" % int(Game.boss_deaths.get(zone.boss_id, 0))
	deaths_label.text = txt

func _process(_delta: float) -> void:
	if deaths_label:
		var show := state == "play" and zone != null
		if show != deaths_label.visible:
			deaths_label.visible = show
			_refresh_deaths()

func _notification(what: int) -> void:
	if Autotest.enabled:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Game.playing:
		Game.save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and zone and not transitioning and not get_tree().paused:
		_open_pause()

# ------------------------------------------------------------------ overlays
func _on_toast(text: String, seconds: float) -> void:
	toast_label.text = text
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween().set_ignore_time_scale(true)
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	toast_tween.tween_interval(seconds)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)

func _on_banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	if banner_tween:
		banner_tween.kill()
	banner_title.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	banner_tween = create_tween().set_ignore_time_scale(true).set_parallel(false)
	banner_tween.tween_property(banner_title, "modulate:a", 1.0, 0.35)
	banner_tween.parallel().tween_property(banner_sub, "modulate:a", 1.0, 0.6)
	banner_tween.tween_interval(2.0)
	banner_tween.tween_property(banner_title, "modulate:a", 0.0, 0.8)
	banner_tween.parallel().tween_property(banner_sub, "modulate:a", 0.0, 0.8)

func fade_to(alpha: float, dur: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(fade, "color:a", alpha, dur)
	await tw.finished

# ------------------------------------------------------------------ title
func show_title() -> void:
	state = "title"
	Game.playing = false
	get_tree().paused = false
	Game.reset_time()
	_free_zone()
	_clear_ui_screens()
	Sfx.play_music("title")
	title_root = Control.new()
	title_root.size = Vector2(480, 270)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_root)
	var bg := TextureRect.new()
	bg.texture = Gfx.tex("ui/title_bg.png")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(bg)
	var em := CPUParticles2D.new()
	em.position = Vector2(240, 275)
	em.amount = 26
	em.lifetime = 5.0
	em.preprocess = 5.0
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	em.emission_rect_extents = Vector2(240, 2)
	em.direction = Vector2.UP
	em.spread = 20.0
	em.initial_velocity_min = 14.0
	em.initial_velocity_max = 34.0
	em.gravity = Vector2.ZERO
	em.scale_amount_min = 1.0
	em.scale_amount_max = 2.0
	em.color = Color("ef8d35")
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("ef8d35", 0.0), Color("ef8d35", 0.9), Color("db4f3a", 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	em.color_ramp = g
	title_root.add_child(em)
	var logo := TextureRect.new()
	logo.texture = Gfx.tex("ui/logo.png")
	logo.position = Vector2((480 - logo.texture.get_width()) / 2.0, 22)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(logo)
	var sub := Menu.make_label("ONE ARROW. ONE LIFE.", false, Menu.PAL_BEIGE)
	sub.position = Vector2(0, 76)
	title_root.add_child(sub)
	var hint := Menu.make_label("LEFT STICK MOVE   RIGHT STICK AIM - LET GO TO SHOOT   HOLD RECALL   ROLL" if Game.touch_mode else "WASD MOVE   SPACE DODGE   LMB SHOOT   RMB RECALL   R RETRY", false, Menu.PAL_TAN)
	hint.position = Vector2(0, 254)
	title_root.add_child(hint)
	var band := Menu.make_panel(Rect2(142, 106, 196, 104), 0.82)
	title_root.add_child(band)
	_open_title_menu()
	fade.color.a = 1.0
	fade_to(0.0, 0.6)

func _open_title_menu() -> void:
	if menu:
		menu.queue_free()
	menu = Menu.new()
	title_root.add_child(menu)
	var entries := [
		{"text": "START GAME", "cb": _on_start_game},
		{"text": "CONTINUE", "cb": _on_continue, "enabled": Game.has_save()},
		{"text": "SETTINGS", "cb": _on_title_settings},
	]
	if not OS.has_feature("web"):   # a browser tab cannot quit itself
		entries.append({"text": "QUIT", "cb": func(): get_tree().quit()})
	menu.setup("", entries, 116.0, 22.0, true)

func _on_title_settings() -> void:
	menu.active = false
	menu.visible = false
	_open_settings(func():
		menu.visible = true
		menu.active = true
		menu.refresh())

func _clear_ui_screens() -> void:
	for n in [title_root, pause_root, settings_menu]:
		if n and is_instance_valid(n):
			n.queue_free()
	title_root = null
	pause_root = null
	settings_menu = null
	menu = null

# ------------------------------------------------------------------ settings
func _open_settings(on_close: Callable) -> void:
	var parent: Node = title_root if title_root and is_instance_valid(title_root) else pause_root
	settings_menu = Menu.new()
	parent.add_child(settings_menu)
	settings_menu.add_child(Menu.make_panel(Rect2(100, 26, 280, 190), 1.0))
	var close := func():
		Game.save_settings()
		settings_menu.queue_free()
		settings_menu = null
		on_close.call()
	settings_menu.setup("SETTINGS", [
		{"text": "MASTER", "kind": "slider", "get": func(): return Game.settings["master"], "set": func(v): Game.settings["master"] = v; Game.apply_settings()},
		{"text": "MUSIC", "kind": "slider", "get": func(): return Game.settings["music"], "set": func(v): Game.settings["music"] = v; Game.apply_settings()},
		{"text": "SOUND", "kind": "slider", "get": func(): return Game.settings["sfx"], "set": func(v): Game.settings["sfx"] = v; Game.apply_settings()},
		{"text": "SCREEN SHAKE", "kind": "slider", "get": func(): return Game.settings["shake"], "set": func(v): Game.settings["shake"] = v},
		{"text": "FULLSCREEN", "kind": "toggle", "get": func(): return Game.settings["fullscreen"], "set": func(v): Game.settings["fullscreen"] = v; Game.apply_settings()},
		{"text": "BACK", "cb": close},
	], 92.0, 20.0, false)
	settings_menu.cancelled.connect(close)

# ------------------------------------------------------------------ new game / continue
func _on_start_game() -> void:
	if transitioning:
		return
	transitioning = true
	menu.active = false
	Game.new_game()
	await fade_to(1.0, 0.6)
	_clear_ui_screens()
	Sfx.stop_music(0.5)
	await _play_intro()
	Game.intro_seen = true
	transitioning = false
	state = "play"
	Game.playing = true
	Game.save_game()
	await _load_zone("hub", "start", 0.6)
	if Game.touch_mode:
		Game.say("LEFT STICK MOVES   RIGHT STICK AIMS - LET GO TO SHOOT   HOLD RECALL TO CALL THE ARROW BACK   ROLL DODGES", 8.0)
	else:
		Game.say("WASD MOVE   SPACE DODGE   CLICK SHOOT   HOLD RIGHT CLICK TO RECALL THE ARROW", 8.0)

func _on_continue() -> void:
	if transitioning or not Game.load_game():
		return
	transitioning = true
	menu.active = false
	await fade_to(1.0, 0.5)
	_clear_ui_screens()
	transitioning = false
	state = "play"
	Game.playing = true
	await _load_zone("hub", "start", 0.5)

func _play_intro() -> void:
	var pages := [
		"THE HOLLOW COURT FELL IN A SINGLE NIGHT.",
		"ITS KING, THE ASHEN REGENT, BOUND SIX GUARDIANS TO HIS CROWN AND SEALED THE WORLD BEHIND THEM.",
		"YOU CARRY THE LAST ARROW, FORGED FROM A SPLINTER OF THAT CROWN.",
		"IT FLIES TRUE. IT ALWAYS COMES BACK TO YOU.",
		"ONE ARROW. ONE LIFE.",
	]
	await _text_pages(pages, 3.4)

func _text_pages(pages: Array, secs: float) -> void:
	fade.color.a = 0.0   # the screen behind is already black; the overlay would hide the text
	var l := Menu.make_label("", false, Menu.PAL_CREAM, 340.0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(70, 112)
	ui.add_child(l)
	for p in pages:
		l.text = p
		l.modulate.a = 0.0
		skip_pressed = false
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(l, "modulate:a", 1.0, 0.7)
		tw.tween_interval(secs)
		tw.tween_property(l, "modulate:a", 0.0, 0.6)
		while tw.is_running() and not skip_pressed:
			await get_tree().process_frame
		tw.kill()
		if skip_pressed:
			var tw2 := create_tween().set_ignore_time_scale(true)
			tw2.tween_property(l, "modulate:a", 0.0, 0.2)
			await tw2.finished
	l.queue_free()

# ------------------------------------------------------------------ zones
func _free_zone() -> void:
	if zone and is_instance_valid(zone):
		zone.queue_free()
	zone = null

func _load_zone(id: String, entry: String, fade_time := 0.25) -> void:
	transitioning = true
	if zone:
		await fade_to(1.0, fade_time)
	else:
		fade.color.a = 1.0
	_free_zone()
	Game.reset_time()
	await get_tree().process_frame
	zone = Zone.new()
	world.add_child(zone)
	zone.build(id, entry)
	zone.request_zone.connect(_on_zone_request)
	zone.retry_requested.connect(_on_retry)
	zone.ending_requested.connect(_on_ending)
	Game.current_zone = id
	Game.entry = entry
	_refresh_deaths()
	if zone.kind == "hub":
		Game.save_game()
	await get_tree().process_frame
	transitioning = false
	await fade_to(0.0, fade_time)

func _on_zone_request(id: String, entry: String) -> void:
	if transitioning or state != "play":
		return
	_load_zone(id, entry, 0.3)

func _on_retry() -> void:
	if transitioning or state != "play" or zone == null:
		return
	_load_zone(zone.zone_id, "start", 0.2)

# ------------------------------------------------------------------ input / pause
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Game.settings["fullscreen"] = not Game.settings["fullscreen"]
		Game.apply_settings()
		Game.save_settings()
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		skip_pressed = true
	if state != "play" or transitioning:
		return
	if event.is_action_pressed("restart") and zone and zone.kind == "arena" and not get_tree().paused:
		zone.force_retry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if get_tree().paused:
			_resume()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()

func _open_pause() -> void:
	if pause_root:
		return
	get_tree().paused = true
	pause_root = Control.new()
	pause_root.size = Vector2(480, 270)
	pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color("242020", 0.7)
	dim.size = Vector2(480, 270)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.add_child(dim)
	pause_root.add_child(Menu.make_panel(Rect2(120, 44, 240, 182), 0.92))
	menu = Menu.new()
	pause_root.add_child(menu)
	var in_arena: bool = zone != null and zone.kind == "arena"
	menu.setup("PAUSED", [
		{"text": "RESUME", "cb": _resume},
		{"text": "RESTART FIGHT", "cb": _restart_fight, "enabled": in_arena},
		{"text": "RUN AWAY", "cb": _run_away, "enabled": zone != null and zone.kind != "hub"},
		{"text": "SETTINGS", "cb": _on_pause_settings},
		{"text": "RETURN TO MENU", "cb": _return_to_menu},
	], 96.0, 22.0, true)
	menu.cancelled.connect(_resume)

func _on_pause_settings() -> void:
	menu.active = false
	menu.visible = false
	_open_settings(func():
		menu.visible = true
		menu.active = true
		menu.refresh())

func _resume() -> void:
	get_tree().paused = false
	if pause_root:
		pause_root.queue_free()
		pause_root = null
	menu = null

## flee the boss (or the path): back to the first screen, the hub. Costs nothing - it is not a death.
func _run_away() -> void:
	_resume()
	if zone == null or transitioning:
		return
	Game.say("YOU RAN. THE GUARDIAN WAITS.", 2.5)
	Sfx.stop_music(0.3)
	await _load_zone("hub", "start", 0.35)

func _restart_fight() -> void:
	_resume()
	if zone:
		zone.force_retry()

func _return_to_menu() -> void:
	Game.save_game()
	get_tree().paused = false
	transitioning = true
	await fade_to(1.0, 0.4)
	transitioning = false
	show_title()

# ------------------------------------------------------------------ ending & credits
func _on_ending() -> void:
	if state != "play":
		return
	state = "ending"
	transitioning = true
	Game.reset_time()
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(480, 270)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(flash, "color:a", 1.0, 1.4)
	await tw.finished
	_free_zone()
	fade.color.a = 1.0
	flash.queue_free()
	Sfx.play_music("ending")
	await get_tree().create_timer(1.0).timeout
	await _text_pages([
		"THE ASHEN REGENT CRUMBLES, AND THE CROWN WITH HIM.",
		"THE SIX SEALS BREAK. FOR THE FIRST TIME IN A HUNDRED YEARS, THE WIND MOVES THROUGH THE COURT.",
		"THE ARROW COMES HOME ONE LAST TIME.",
		"YOU LEAVE IT STANDING IN THE OLD THRONE ROOM, AND WALK OUT INTO THE MORNING.",
	], 3.6)
	await _credits()
	Game.save_game()
	transitioning = false
	show_title()

func _credits() -> void:
	fade.color.a = 0.0
	var lines := [
		"HOLLOW ARROW", "",
		"YOU FELLED THE SIX GUARDIANS", "AND THE ASHEN REGENT", "",
		"TIME  " + Game.fmt_time(Game.play_time),
		"FALLS  " + str(Game.deaths), "", "",
		"DESIGN AND CODE", "BOSSES, EFFECTS, SOUND AND MUSIC", "MADE FOR THIS GAME", "",
		"TILES, TREES, HERO AND TORCHES", "FOREST OF DREAMS BY YANIN", "",
		"BOSS SPRITES", "MECHA-STONE GOLEM, FROST GUARDIAN, DEMON SLIME", "UNDEAD EXECUTIONER, ARCHER HERO", "EVIL WIZARD 2 (CC0)", "GOLEMS AND ELEMENTALS BY BATAREYA", "", "",
		"BUILT WITH GODOT 4", "", "",
		"THANK YOU FOR PLAYING",
	]
	var l := Menu.make_label("\n".join(lines), false, Menu.PAL_CREAM)
	l.position = Vector2(0, 280)
	ui.add_child(l)
	var total := 26.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "position:y", -float(lines.size()) * 11.0, total)
	skip_pressed = false
	var t0 := Time.get_ticks_msec()
	while tw.is_running():
		await get_tree().process_frame
		if skip_pressed and Time.get_ticks_msec() - t0 > 3000:
			break
	tw.kill()
	var tw2 := create_tween().set_ignore_time_scale(true)
	tw2.tween_property(l, "modulate:a", 0.0, 0.8)
	await tw2.finished
	l.queue_free()
