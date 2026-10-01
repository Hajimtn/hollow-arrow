class_name Gfx
## Small helpers for loading generated pixel art and building sprites.

static var _cache := {}

static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load("res://assets/" + path)
	return _cache[path]

## Sprite whose origin is the centre of the image.
static func sprite(path: String, pos := Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.position = pos
	return s

## Sprite whose origin is the bottom-centre of the image (for y-sorted props).
static func base_sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	return s

## Build SpriteFrames from a sheet. anims = { name: {"frames": [idx...], "fps": 8, "loop": true} }
static func sheet_frames(path: String, fw: int, fh: int, anims: Dictionary) -> SpriteFrames:
	var t := tex(path)
	var cols: int = t.get_width() / fw
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		sf.add_animation(a)
		sf.set_animation_speed(a, anims[a].get("fps", 8))
		sf.set_animation_loop(a, anims[a].get("loop", true))
		for idx in anims[a]["frames"]:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2((idx % cols) * fw, (idx / cols) * fh, fw, fh)
			sf.add_frame(a, at)
	return sf

## Animated sprite from a horizontal strip of equal frames, origin bottom-centre optional.
static func strip(path: String, fw: int, count: int, fps := 6.0, base := true) -> AnimatedSprite2D:
	var t := tex(path)
	var frames: Array = []
	for i in count:
		frames.append(i)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sheet_frames(path, fw, t.get_height(), {"loop": {"frames": frames, "fps": fps, "loop": true}})
	a.play("loop")
	if base:
		a.offset = Vector2(0, -t.get_height() / 2.0)
	return a
