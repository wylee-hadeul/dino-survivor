extends Node2D
## 공룡/보스의 공격: 침 투사체, 퍼지는 충격파, 낙석 표식, 돌진 예고선.

var run
var bullets: Array = []   # {pos, vel, dmg, sprite, r, life}
var rings: Array = []     # {c, r, max_r, speed, dmg, hit}
var markers: Array = []   # {pos, radius, t, delay, dmg, kind}
var lines: Array = []     # {a, b, t, life, w}


func clear() -> void:
	bullets.clear()
	rings.clear()
	markers.clear()
	lines.clear()


func bullet(pos: Vector2, vel: Vector2, dmg: float, sprite: String, r: float) -> void:
	bullets.append({"pos": pos, "vel": vel, "dmg": dmg, "sprite": sprite, "r": r, "life": 4.0})


func ring(c: Vector2, max_r: float, speed: float, dmg: float) -> void:
	rings.append({"c": c, "r": 10.0, "max_r": max_r, "speed": speed, "dmg": dmg, "hit": false})


func marker(pos: Vector2, radius: float, delay: float, dmg: float, kind: String) -> void:
	markers.append({"pos": pos, "radius": radius, "t": 0.0, "delay": delay, "dmg": dmg, "kind": kind})


func line(a: Vector2, b: Vector2, life: float, w: float) -> void:
	lines.append({"a": a, "b": b, "t": 0.0, "life": life, "w": w})


## 오토플레이 봇용: pos 근처의 위험 방향(피해야 할 방향 벡터 합)
func danger_at(pos: Vector2) -> Vector2:
	var v := Vector2.ZERO
	for m in markers:
		var d: Vector2 = pos - m.pos
		if d.length() < m.radius + 40.0:
			v += d.normalized() * 2.0
	for b in bullets:
		var d: Vector2 = pos - b.pos
		if d.length() < 120.0:
			v += d.normalized() / max(d.length() / 60.0, 0.5)
	for r in rings:
		var d: Vector2 = pos - r.c
		if abs(d.length() - r.r) < 90.0 and d.length() > r.r:
			v += d.normalized() * 1.5
	return v


func update(delta: float) -> void:
	var pl = run.player
	var pr: float = pl.radius()
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.pos += b.vel * delta
		b.life -= delta
		if b.pos.distance_to(pl.pos + Vector2(0, -20)) < b.r + pr:
			pl.hurt(b.dmg)
			run.fx.burst(b.pos, Color("aeea00"), 6)
			bullets.remove_at(i)
		elif b.life <= 0.0:
			bullets.remove_at(i)
	for i in range(rings.size() - 1, -1, -1):
		var r: Dictionary = rings[i]
		r.r += r.speed * delta
		if not r.hit and abs(pl.pos.distance_to(r.c) - r.r) < 22.0 + pr * 0.5:
			r.hit = true
			pl.hurt(r.dmg)
		if r.r >= r.max_r:
			rings.remove_at(i)
	for i in range(markers.size() - 1, -1, -1):
		var m: Dictionary = markers[i]
		m.t += delta
		if m.t >= m.delay:
			if m.dmg > 0.0 and pl.pos.distance_to(m.pos) < m.radius + pr * 0.5:
				pl.hurt(m.dmg)
			if m.kind == "rock":
				run.fx.explosion(m.pos, 0.6, Color("8d6e63"))
				run.sfx.play("small_boom", -8.0, 0.8)
			markers.remove_at(i)
	for i in range(lines.size() - 1, -1, -1):
		lines[i].t += delta
		if lines[i].t >= lines[i].life:
			lines.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var sp = run.sprites
	for l in lines:
		var a: float = 0.25 + 0.25 * sin(l.t * 30.0)
		draw_line(l.a, l.b, Color(1, 0.1, 0.1, a), l.w)
		draw_line(l.a, l.b, Color(1, 0.3, 0.2, 0.7), 3.0)
	for m in markers:
		var k: float = m.t / m.delay
		draw_circle(m.pos, m.radius, Color(1, 0.1, 0.1, 0.12 + 0.1 * k))
		draw_circle(m.pos, m.radius * k, Color(1, 0.2, 0.1, 0.22))
		draw_arc(m.pos, m.radius, 0.0, TAU, 40, Color(1, 0.2, 0.1, 0.8), 3.0)
		if m.kind == "rock" and k > 0.5:
			var fall: float = (1.0 - k) * 600.0
			sp.draw_rot(self, "rock", m.pos - Vector2(0, fall), k * 6.0, 1.6)
	for r in rings:
		var a: float = 1.0 - r.r / r.max_r
		draw_arc(r.c, r.r, 0.0, TAU, 64, Color(1, 0.75, 0.3, 0.35 * a + 0.2), 26.0)
		draw_arc(r.c, r.r, 0.0, TAU, 64, Color(1, 0.95, 0.7, 0.8 * a + 0.2), 5.0)
	for b in bullets:
		sp.draw_rot(self, b.sprite, b.pos, b.vel.angle(), 1.2)
