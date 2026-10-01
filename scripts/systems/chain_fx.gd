class_name ChainFx
extends Node2D
## Draws a chain of alternating links between two world points.

var a := Vector2.ZERO
var b := Vector2.ZERO
var tex_a: Texture2D
var tex_b: Texture2D
var slack := 0.0
var _t := 0.0

func _ready() -> void:
	tex_a = Gfx.tex("environment/chain_a.png")
	tex_b = Gfx.tex("environment/chain_b.png")
	z_index = -2

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var d := b - a
	var n := int(d.length() / 5.0)
	for i in n + 1:
		var f := float(i) / maxf(1.0, n)
		var p := a.lerp(b, f)
		p.y += sin(f * PI) * slack
		p += Vector2(0, sin(_t * 2.0 + f * 6.0) * 0.6)
		var tx := tex_a if i % 2 == 0 else tex_b
		draw_texture(tx, p - Vector2(4, 4))
