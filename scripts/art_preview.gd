extends Node2D
## 개발용: 구운 아틀라스의 모든 스프라이트를 한 화면에 그려 스크린샷으로 저장한다.
## 실행: godot --path . res://art_preview.tscn -- --out=/tmp/art.png

const SpritesScript = preload("res://scripts/sprites.gd")
var sprites


func _ready() -> void:
	sprites = SpritesScript.new()
	add_child(sprites)
	await sprites.bake()
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out := "/tmp/art.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _draw() -> void:
	if not sprites or not sprites.baked:
		return
	draw_rect(Rect2(0, 0, 2000, 2000), Color("5a8f3c"))
	var x := 20.0
	var y := 20.0
	var row := 0.0
	for sp in SpritesScript.SPECS:
		var name: String = sp[0]
		var sz: Vector2 = sprites.size_of(name)
		for f in sp[4]:
			for m in (2 if sp[5] else 1):
				if x + sz.x > 700:
					x = 20.0
					y += row + 10
					row = 0
				var a: Vector2 = sprites.anchors[name]
				sprites.draw(self, name, Vector2(x, y) + a, f, m == 1)
				x += sz.x + 8
				row = max(row, sz.y)
	x = 20.0
	y += row + 10
	for id in SpritesScript.ICONS:
		if x > 640:
			x = 20.0
			y += 70
		sprites.draw(self, "i_" + id, Vector2(x + 32, y + 32))
		x += 70
