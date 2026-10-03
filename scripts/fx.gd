extends Node2D
## 파티클, 피해 숫자, 떠오르는 글자. 모바일 성능을 위해 개수를 제한한다.

enum { CIRCLE, RING, TEXT, NUM }

const MAX_PARTS := 360
const MAX_NUMS := 50

var run
var parts: Array = []
var num_count := 0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func clear() -> void:
	parts.clear()
	num_count = 0


func _add(p: Dictionary) -> void:
	if parts.size() >= MAX_PARTS:
		var old: Dictionary = parts.pop_front()
		if old.k == NUM:
			num_count -= 1
	p["age"] = 0.0
	parts.append(p)


func burst(pos: Vector2, col: Color, n: int) -> void:
	for i in n:
		_add({"k": CIRCLE, "pos": pos, "vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 220), "life": randf_range(0.2, 0.45),
			"size": randf_range(3, 6), "grow": -4.0, "col": col, "drag": 3.0})


func explosion(pos: Vector2, s: float, col := Color(1, 0.7, 0.3)) -> void:
	_add({"k": CIRCLE, "pos": pos, "vel": Vector2.ZERO, "life": 0.15, "size": 50.0 * s, "grow": 120.0 * s, "col": Color(1, 1, 0.85, 0.9), "drag": 0.0})
	_add({"k": RING, "pos": pos, "vel": Vector2.ZERO, "life": 0.3, "size": 10.0, "grow": 260.0 * s, "col": col, "drag": 0.0})
	for i in int(6 * s) + 3:
		_add({"k": CIRCLE, "pos": pos + Vector2.RIGHT.rotated(randf() * TAU) * randf() * 20.0 * s, "vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 200) * s,
			"life": randf_range(0.3, 0.6), "size": randf_range(10, 20) * s, "grow": -8.0, "col": col, "drag": 3.0})
	for i in int(3 * s) + 1:
		_add({"k": CIRCLE, "pos": pos, "vel": Vector2(randf_range(-40, 40), randf_range(-90, -30)), "life": randf_range(0.6, 1.0),
			"size": randf_range(12, 22) * s, "grow": 18.0, "col": Color(0.35, 0.33, 0.32, 0.6), "drag": 1.5})


func dust(pos: Vector2, s: float) -> void:
	for i in 3:
		_add({"k": CIRCLE, "pos": pos + Vector2(randf_range(-20, 20), 0), "vel": Vector2(randf_range(-60, 60), randf_range(-40, -10)), "life": 0.5,
			"size": randf_range(8, 14) * s, "grow": 20.0, "col": Color(0.8, 0.7, 0.55, 0.6), "drag": 2.0})


func death(pos: Vector2, size: float) -> void:
	for i in 5:
		_add({"k": CIRCLE, "pos": pos + Vector2(randf_range(-10, 10), randf_range(-20, 0)), "vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 110),
			"life": randf_range(0.3, 0.5), "size": randf_range(6, 12) * size, "grow": 10.0, "col": Color(0.95, 0.95, 0.9, 0.7), "drag": 3.0})


func ring(pos: Vector2, radius: float, col: Color) -> void:
	_add({"k": RING, "pos": pos, "vel": Vector2.ZERO, "life": 0.45, "size": 10.0, "grow": radius / 0.45, "col": col, "drag": 0.0})


func text(pos: Vector2, s: String, col: Color, size := 30) -> void:
	_add({"k": TEXT, "pos": pos, "vel": Vector2(0, -60), "life": 1.1, "size": float(size), "grow": 0.0, "txt": s, "col": col, "drag": 1.0})


func number(pos: Vector2, v: float, big := false) -> void:
	if num_count >= MAX_NUMS:
		return
	num_count += 1
	_add({"k": NUM, "pos": pos, "vel": Vector2(randf_range(-20, 20), -90), "life": 0.5, "size": 26.0 if big else 20.0, "grow": 0.0,
		"txt": str(int(round(v))), "col": Color(1, 0.9, 0.4) if big else Color.WHITE, "drag": 2.0})


func update(delta: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.age += delta
		if p.age >= p.life:
			if p.k == NUM:
				num_count -= 1
			parts.remove_at(i)
			continue
		var vel: Vector2 = p.vel
		if p.drag > 0.0:
			vel *= max(0.0, 1.0 - p.drag * delta)
		p.vel = vel
		p.pos += vel * delta
		p.size = max(p.size + p.grow * delta, 0.0)
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var k: float = p.age / p.life
		var col: Color = p.col
		col.a *= 1.0 - k * k
		match p.k:
			CIRCLE:
				draw_circle(p.pos, p.size, col)
			RING:
				draw_arc(p.pos, p.size, 0.0, TAU, 40, col, 6.0 * (1.0 - k) + 2.0)
			TEXT, NUM:
				var sz := int(p.size)
				var w := font.get_string_size(p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
				var pos: Vector2 = p.pos - Vector2(w * 0.5, 0)
				draw_string_outline(font, pos, p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(0, 0, 0, col.a))
				draw_string(font, pos, p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
