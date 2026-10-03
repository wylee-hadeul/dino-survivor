extends Node2D
## 끝없는 바닥. 카메라 주변 타일만 그리고, 타일 좌표로 장식을 결정해 항상 같은 모양이 나온다.

const TILE := 256.0

## 테마: 고사리 숲 / 화산 지대 / 안개 늪 / 빙하 계곡
const THEMES := [
	{"base": Color("5a8f3c"), "patch": Color("67a046"), "dark": Color("3f6e2a"), "rock": Color("8a8f86"), "accent": Color("f2e86d")},
	{"base": Color("5b4636"), "patch": Color("4a372a"), "dark": Color("2e221a"), "rock": Color("3d3330"), "accent": Color("ff7a2b")},
	{"base": Color("40593a"), "patch": Color("2f4a48"), "dark": Color("2a3d27"), "rock": Color("5d6b58"), "accent": Color("a8c66c")},
	{"base": Color("dde8ef"), "patch": Color("c6d7e5"), "dark": Color("9fb6c9"), "rock": Color("8fa3b3"), "accent": Color("7fd3ff")},
]

var run
var theme := 0
var rng := RandomNumberGenerator.new()


func _draw() -> void:
	var th: Dictionary = THEMES[theme % THEMES.size()]
	var r: Rect2 = run.visible_rect().grow(40)
	draw_rect(r, th.base)
	var x0 := floori(r.position.x / TILE)
	var y0 := floori(r.position.y / TILE)
	var x1 := floori(r.end.x / TILE)
	var y1 := floori(r.end.y / TILE)
	for tx in range(x0, x1 + 1):
		for ty in range(y0, y1 + 1):
			rng.seed = hash(Vector2i(tx, ty))
			var o := Vector2(tx, ty) * TILE
			# 큰 얼룩
			var pc := o + Vector2(rng.randf() * TILE, rng.randf() * TILE)
			draw_colored_polygon(_ell(pc, Vector2(rng.randf_range(50, 110), rng.randf_range(30, 60))), th.patch)
			for i in rng.randi_range(2, 4):
				var p := o + Vector2(rng.randf() * TILE, rng.randf() * TILE)
				var kind := rng.randi() % 4
				match theme % THEMES.size():
					0:
						_forest(p, kind, th)
					1:
						_volcano(p, kind, th)
					2:
						_swamp(p, kind, th)
					3:
						_glacier(p, kind, th)


func _ell(c: Vector2, rr: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	return pts


func _rock(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(_ell(p + Vector2(0, 4), Vector2(16, 6) * s), Color(0, 0, 0, 0.2))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 2) * s, p + Vector2(-8, -10) * s, p + Vector2(8, -12) * s, p + Vector2(15, 0) * s, p + Vector2(6, 6) * s, p + Vector2(-10, 6) * s]), col)
	draw_line(p + Vector2(-6, -6) * s, p + Vector2(4, -8) * s, col.lightened(0.25), 2.0)


func _forest(p: Vector2, kind: int, th: Dictionary) -> void:
	match kind:
		0:
			for j in 5:
				var a := -PI * 0.5 + (j - 2) * 0.45
				draw_line(p, p + Vector2(cos(a), sin(a)) * 26.0, th.dark, 5.0)
		1:
			_rock(p, 1.0, th.rock)
		2:
			for j in 3:
				draw_circle(p + Vector2(j * 8 - 8, (j % 2) * 5), 3.0, th.accent)
		_:
			for j in 4:
				draw_line(p + Vector2(j * 5, 0), p + Vector2(j * 5 - 3, -10), th.dark, 2.0)


func _volcano(p: Vector2, kind: int, th: Dictionary) -> void:
	match kind:
		0:
			draw_polyline(PackedVector2Array([p, p + Vector2(18, 8), p + Vector2(30, 2), p + Vector2(46, 12)]), th.accent, 3.0)
			draw_polyline(PackedVector2Array([p, p + Vector2(18, 8), p + Vector2(30, 2), p + Vector2(46, 12)]), Color(1, 0.8, 0.3, 0.5), 7.0)
		1:
			_rock(p, 1.3, th.rock)
		2:
			draw_circle(p, 6.0, th.dark)
		_:
			_rock(p, 0.7, th.dark)


func _swamp(p: Vector2, kind: int, th: Dictionary) -> void:
	match kind:
		0:
			draw_colored_polygon(_ell(p, Vector2(40, 18)), Color("2c4a50"))
			draw_arc(p + Vector2(-8, -2), 10.0, PI, TAU, 8, Color(1, 1, 1, 0.25), 2.0)
		1:
			for j in 4:
				draw_line(p + Vector2(j * 6, 0), p + Vector2(j * 6 + 2, -28 - j * 3), th.accent.darkened(0.3), 3.0)
		2:
			_rock(p, 0.9, th.rock)
		_:
			draw_circle(p, 5.0, th.accent)


func _glacier(p: Vector2, kind: int, th: Dictionary) -> void:
	match kind:
		0:
			draw_polyline(PackedVector2Array([p, p + Vector2(14, 10), p + Vector2(10, 24), p + Vector2(26, 34)]), th.dark, 2.0)
		1:
			_rock(p, 1.1, th.rock)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -8), p + Vector2(-4, -12), p + Vector2(6, -12), p + Vector2(10, -6)]), Color.WHITE)
		2:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(0, -18), p + Vector2(8, 0)]), th.accent.lightened(0.3))
		_:
			draw_circle(p, 4.0, Color.WHITE)
