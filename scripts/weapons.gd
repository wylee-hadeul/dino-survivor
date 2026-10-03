extends Node2D
## 자동 무기 8종 + 탈것 무기. 투사체/광선/벼락도 여기서 갱신하고 그린다.

const Data = preload("res://scripts/data.gd")


class P:
	var sprite := "bullet"
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 10.0
	var r := 8.0
	var life := 1.0
	var pierce := 0
	var hits: Array = []
	var aoe := 0.0         # 0이면 단일 대상, 아니면 폭발 반경
	var lob := false       # 포물선 투척 (수류탄)
	var start := Vector2.ZERO
	var target := Vector2.ZERO
	var t := 0.0
	var dur := 0.0
	var mine := false
	var homing := 0.0
	var scale := 1.0
	var knock := 120.0
	var dead := false


var run
var projs: Array = []
var beams: Array = []   # {a, b, w, t, life, col}
var bolts: Array = []   # {pts, t}
var flames: Array = []  # 화염 시각 효과 {pos, vel, t, life, s}
var saw_angle := 0.0
var bomb_t := 0.0


func clear() -> void:
	projs.clear()
	beams.clear()
	bolts.clear()
	flames.clear()


## 무기 레벨(1~5)별 수치
static func stats(id: String, lv: int) -> Dictionary:
	var i: int = clampi(lv, 1, 5) - 1
	match id:
		"pistol":
			return {"dmg": [14.0, 18.2, 18.2, 18.2, 23.7][i], "count": [1, 1, 2, 2, 2][i], "cd": [0.55, 0.55, 0.55, 0.42, 0.42][i], "pierce": [0, 0, 0, 0, 1][i]}
		"shotgun":
			return {"dmg": [7.0, 7.0, 9.1, 9.1, 9.1][i], "count": [5, 7, 7, 7, 9][i], "cd": [1.5, 1.5, 1.5, 1.12, 1.12][i], "life": [0.32, 0.32, 0.32, 0.32, 0.42][i]}
		"grenade":
			return {"dmg": [30.0, 30.0, 30.0, 42.0, 42.0][i], "radius": [70.0, 84.0, 84.0, 84.0, 84.0][i], "count": [1, 1, 2, 2, 3][i], "cd": [2.4, 2.4, 2.4, 2.4, 1.8][i]}
		"saw":
			return {"dmg": [9.0, 9.0, 11.7, 11.7, 11.7][i], "count": [2, 3, 3, 3, 5][i], "radius": [80.0, 80.0, 80.0, 105.0, 105.0][i], "spin": [3.0, 3.0, 3.0, 4.2, 4.2][i]}
		"flame":
			return {"dps": [22.0, 22.0, 30.0, 30.0, 45.0][i], "range": [130.0, 162.0, 162.0, 162.0, 162.0][i], "angle": [0.45, 0.45, 0.45, 0.7, 0.7][i]}
		"lightning":
			return {"dmg": [24.0, 24.0, 32.0, 32.0, 32.0][i], "count": [2, 3, 3, 5, 5][i], "cd": [2.0, 2.0, 2.0, 2.0, 1.4][i], "chain": i == 4}
		"laser":
			return {"dmg": [40.0, 40.0, 56.0, 56.0, 78.0][i], "width": [16.0, 22.0, 22.0, 22.0, 22.0][i], "count": [1, 1, 1, 2, 2][i], "cd": [3.0, 3.0, 3.0, 3.0, 2.1][i]}
		"mine":
			return {"dmg": [40.0, 40.0, 40.0, 60.0, 60.0][i], "radius": [70.0, 88.0, 88.0, 88.0, 88.0][i], "cd": [1.4, 1.4, 1.0, 1.0, 1.0][i], "per": [1, 1, 1, 1, 2][i]}
	return {}


func _aim(range_: float) -> Vector2:
	var pl = run.player
	var e = run.enemies.nearest(pl.pos, range_)
	if e:
		return (e.pos - pl.pos).normalized()
	return pl.facing_dir()


func _shoot(sprite: String, pos: Vector2, vel: Vector2, dmg: float, r: float, life: float, pierce := 0) -> P:
	var p := P.new()
	p.sprite = sprite
	p.pos = pos
	p.vel = vel
	p.dmg = dmg
	p.r = r
	p.life = life
	p.pierce = pierce
	projs.append(p)
	return p


func update(delta: float) -> void:
	var pl = run.player
	var might: float = pl.might()
	var cdm: float = pl.cd_mult()
	var muzzle: Vector2 = pl.pos + Vector2(0, -40)
	for w in pl.weapons:
		var s := stats(w.id, w.lv)
		w.cd -= delta
		match w.id:
			"pistol":
				if w.cd <= 0.0 and run.enemies.nearest(pl.pos, 420.0):
					w.cd = s.cd * cdm
					var d := _aim(420.0)
					for k in s.count:
						var off: Vector2 = d.orthogonal() * (k - (s.count - 1) * 0.5) * 12.0
						_shoot("bullet", muzzle + off, d * 720.0, s.dmg * might, 8.0, 0.9, s.pierce)
					run.sfx.play("shoot", -12.0)
			"shotgun":
				if w.cd <= 0.0 and run.enemies.nearest(pl.pos, 300.0):
					w.cd = s.cd * cdm
					var d := _aim(300.0)
					for k in s.count:
						var ang: float = (k - (s.count - 1) * 0.5) * 0.12 + randf_range(-0.04, 0.04)
						_shoot("pellet", muzzle, d.rotated(ang) * randf_range(620.0, 760.0), s.dmg * might, 8.0, s.life, 0)
					run.sfx.play("shotgun", -8.0)
			"grenade":
				if w.cd <= 0.0:
					var any = run.enemies.random_near(pl.pos, 460.0)
					if any:
						w.cd = s.cd * cdm
						for k in s.count:
							var e = run.enemies.random_near(pl.pos, 460.0)
							if e == null:
								break
							var p := _shoot("grenade", muzzle, Vector2.ZERO, s.dmg * might, 0.0, 9.0)
							p.lob = true
							p.start = muzzle
							p.target = e.pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
							p.dur = 0.6
							p.aoe = s.radius
			"saw":
				saw_angle += s.spin * delta
				for k in s.count:
					var ang: float = saw_angle + TAU * k / s.count
					var bp: Vector2 = pl.pos + Vector2(cos(ang), sin(ang) * 0.85) * s.radius + Vector2(0, -24)
					for e in run.enemies.query(bp, 20.0):
						if e.saw_cd <= 0.0:
							e.saw_cd = 0.35
							run.enemies.damage(e, s.dmg * might, (e.pos - pl.pos).normalized(), 160.0)
			"flame":
				var d := _aim(s.range)
				w.cd -= 0.0
				if randf() < 0.7:
					flames.append({"pos": muzzle, "vel": d.rotated(randf_range(-s.angle, s.angle) * 0.8) * s.range * 2.4, "t": 0.0, "life": 0.42, "s": randf_range(0.6, 1.0)})
				if w.cd <= 0.0:
					w.cd = 0.1
					for e in run.enemies.query(pl.pos, s.range):
						var to: Vector2 = e.pos - pl.pos
						if to.length() < 10.0 or abs(d.angle_to(to)) < s.angle:
							run.enemies.damage(e, s.dps * 0.1 * might, d, 25.0)
			"lightning":
				if w.cd <= 0.0 and run.enemies.nearest(pl.pos, 600.0):
					w.cd = s.cd * cdm
					var used: Array = []
					for k in s.count:
						var e = run.enemies.random_near(pl.pos, 600.0)
						if e == null or used.has(e):
							continue
						used.append(e)
						_strike(e.pos, s.dmg * might, 50.0)
						if s.chain:
							var e2 = run.enemies.random_near(e.pos, 180.0)
							if e2:
								_strike(e2.pos, s.dmg * might * 0.7, 40.0)
					run.sfx.play("zap", -6.0)
			"laser":
				if w.cd <= 0.0 and run.enemies.nearest(pl.pos, 650.0):
					w.cd = s.cd * cdm
					var d := _aim(650.0)
					for k in s.count:
						var dd := d.rotated(k * PI) if s.count > 1 else d
						_beam(muzzle, dd, 900.0, s.width, s.dmg * might, Color("ea80fc"))
					run.sfx.play("laser", -6.0)
			"mine":
				if w.cd <= 0.0:
					w.cd = s.cd * cdm
					for k in s.per:
						var p := _shoot("mine", pl.pos + Vector2(randf_range(-25, 25), randf_range(-10, 10)), Vector2.ZERO, s.dmg * might, 26.0, 20.0)
						p.mine = true
						p.aoe = s.radius
	if pl.vehicle != "":
		_vehicle_update(delta, might)
	_update_projs(delta)
	for i in range(beams.size() - 1, -1, -1):
		beams[i].t += delta
		if beams[i].t >= beams[i].life:
			beams.remove_at(i)
	for i in range(bolts.size() - 1, -1, -1):
		bolts[i].t += delta
		if bolts[i].t >= 0.25:
			bolts.remove_at(i)
	for i in range(flames.size() - 1, -1, -1):
		var f: Dictionary = flames[i]
		f.t += delta
		f.pos += f.vel * delta
		f.vel *= 1.0 - 2.5 * delta
		if f.t >= f.life:
			flames.remove_at(i)
	queue_redraw()


func _strike(pos: Vector2, dmg: float, radius: float) -> void:
	var pts := PackedVector2Array()
	var top := pos + Vector2(randf_range(-40, 40), -500)
	for k in 8:
		var t := k / 7.0
		pts.append(top.lerp(pos, t) + Vector2(randf_range(-18, 18) * (1.0 - abs(t - 0.5) * 2.0 + 0.3), 0))
	bolts.append({"pts": pts, "t": 0.0})
	for e in run.enemies.query(pos, radius):
		run.enemies.damage(e, dmg, Vector2.ZERO, 0.0)
	run.fx.burst(pos, Color("fff59d"), 8)


func _beam(a: Vector2, d: Vector2, length: float, w: float, dmg: float, col: Color) -> void:
	var b := a + d * length
	beams.append({"a": a, "b": b, "w": w, "t": 0.0, "life": 0.28, "col": col})
	var mid := a + d * length * 0.5
	for e in run.enemies.query(mid, length * 0.5 + 40.0):
		var q := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if q.distance_to(e.pos) < w + e.r:
			run.enemies.damage(e, dmg, d, 60.0)


func _explode(pos: Vector2, radius: float, dmg: float, col := Color(1, 0.7, 0.3)) -> void:
	for e in run.enemies.query(pos, radius):
		run.enemies.damage(e, dmg, (e.pos - pos).normalized(), 220.0)
	run.fx.explosion(pos, radius / 80.0, col)
	run.sfx.play("small_boom", -6.0)


func _update_projs(delta: float) -> void:
	for p in projs:
		if p.dead:
			continue
		p.life -= delta
		if p.life <= 0.0:
			p.dead = true
			continue
		if p.lob:
			p.t += delta
			var k: float = min(p.t / p.dur, 1.0)
			p.pos = p.start.lerp(p.target, k) - Vector2(0, sin(k * PI) * 120.0)
			if k >= 1.0:
				p.dead = true
				_explode(p.target, p.aoe, p.dmg)
			continue
		if p.mine:
			if not run.enemies.query(p.pos, p.r).is_empty():
				p.dead = true
				_explode(p.pos, p.aoe, p.dmg, Color(1, 0.5, 0.2))
			continue
		if p.homing > 0.0:
			var e = run.enemies.nearest(p.pos, 400.0)
			if e:
				var want: Vector2 = (e.pos - p.pos).normalized() * p.vel.length()
				p.vel = p.vel.lerp(want, min(1.0, p.homing * delta))
		p.pos += p.vel * delta
		for e in run.enemies.query(p.pos, p.r):
			if p.hits.has(e):
				continue
			if p.aoe > 0.0:
				p.dead = true
				_explode(p.pos, p.aoe, p.dmg)
				break
			p.hits.append(e)
			run.enemies.damage(e, p.dmg, p.vel.normalized(), p.knock)
			if p.pierce <= 0:
				p.dead = true
				break
			p.pierce -= 1
	var i := 0
	while i < projs.size():
		if projs[i].dead:
			projs[i] = projs[-1]
			projs.pop_back()
		else:
			i += 1


# ------------------------------------------------------------------ 탈것 무기

func _vehicle_update(delta: float, might: float) -> void:
	var pl = run.player
	var vm: float = pl.vehicle_power() * might
	var wv = pl.vehicle_weapon
	wv.cd -= delta
	match pl.vehicle:
		"jeep":
			if wv.cd <= 0.0 and run.enemies.nearest(pl.pos, 520.0):
				wv.cd = 0.08
				var d := _aim(520.0).rotated(randf_range(-0.08, 0.08))
				_shoot("bullet", pl.pos + Vector2(0, -50), d * 900.0, 10.0 * vm, 8.0, 0.7, 1)
				run.sfx.play("shoot", -16.0, 1.3)
			_crush(60.0, 40.0 * vm, 380.0)
		"tank":
			if wv.cd <= 0.0 and run.enemies.nearest(pl.pos, 600.0):
				wv.cd = 0.6
				var d := _aim(600.0)
				pl.turret_angle = d.angle()
				var p := _shoot("shell", pl.pos + Vector2(0, -40) + d * 60.0, d * 700.0, 60.0 * vm, 14.0, 1.0)
				p.aoe = 95.0
				p.scale = 1.4
				run.sfx.play("shotgun", -4.0, 0.6)
				run.fx.burst(pl.pos + Vector2(0, -40) + d * 70.0, Color(1, 0.8, 0.4), 6)
			_crush(72.0, 30.0 * vm, 300.0)
		"ship":
			if wv.cd <= 0.0:
				wv.cd = 1.1
				for k in 10:
					var d := Vector2.RIGHT.rotated(TAU * k / 10.0 + randf_range(-0.1, 0.1))
					var p := _shoot("missile", pl.pos + Vector2(0, -50), d * 420.0, 30.0 * vm, 14.0, 1.6)
					p.homing = 3.0
					p.aoe = 60.0
				run.sfx.play("laser", -8.0, 0.6)
			_crush(70.0, 30.0 * vm, 300.0)
		"plane":
			bomb_t -= delta
			if bomb_t <= 0.0:
				bomb_t = 0.13
				var p := _shoot("bomb", pl.pos + Vector2(randf_range(-40, 40), randf_range(-20, 20)), Vector2.ZERO, 35.0 * vm, 0.0, 1.0)
				p.lob = true
				p.start = pl.pos + Vector2(0, -90)
				p.target = p.pos
				p.dur = 0.35
				p.aoe = 75.0
			if wv.cd <= 0.0 and run.enemies.nearest(pl.pos, 600.0):
				wv.cd = 0.1
				var d := _aim(600.0)
				for o in [-14.0, 14.0]:
					_shoot("bullet", pl.pos + Vector2(0, -90) + d.orthogonal() * o, d * 950.0, 12.0 * vm, 8.0, 0.7)


## 탈것으로 들이받기
func _crush(radius: float, dmg: float, knock: float) -> void:
	var pl = run.player
	for e in run.enemies.query(pl.pos, radius):
		if e.crush_cd <= 0.0:
			e.crush_cd = 0.45
			run.enemies.damage(e, dmg, (e.pos - pl.pos).normalized(), knock)


func vehicle_end_blast() -> void:
	var pl = run.player
	_explode(pl.pos, 180.0, 80.0 * pl.vehicle_power() * pl.might(), Color(1, 0.6, 0.2))


# ------------------------------------------------------------------ 그리기

func _draw() -> void:
	var sp = run.sprites
	var pl = run.player
	# 톱날
	for w in pl.weapons:
		if w.id == "saw":
			var s := stats("saw", w.lv)
			for k in s.count:
				var ang: float = saw_angle + TAU * k / s.count
				var bp: Vector2 = pl.pos + Vector2(cos(ang), sin(ang) * 0.85) * s.radius + Vector2(0, -24)
				sp.draw_rot(self, "saw", bp, saw_angle * 4.0, 1.0)
	# 화염
	for f in flames:
		var k: float = f.t / f.life
		var col := Color(1, 0.95, 0.5).lerp(Color(1, 0.3, 0.05), k)
		col.a = 0.8 * (1.0 - k)
		draw_circle(f.pos, (8.0 + k * 22.0) * f.s, col)
	for p in projs:
		if p.lob:
			sp.draw(self, "shadow", p.target, 0, false, 0.4)
		if p.sprite == "grenade" or p.sprite == "bomb":
			sp.draw_rot(self, p.sprite, p.pos, p.t * 10.0, 1.2)
		elif p.mine:
			sp.draw(self, "mine", p.pos)
		else:
			sp.draw_rot(self, p.sprite, p.pos, p.vel.angle(), p.scale)
	for b in beams:
		var k: float = b.t / b.life
		var w: float = b.w * (1.0 - k * 0.5)
		draw_line(b.a, b.b, Color(b.col, 0.35 * (1.0 - k)), w * 2.4)
		draw_line(b.a, b.b, Color(b.col, 0.9 * (1.0 - k)), w)
		draw_line(b.a, b.b, Color(1, 1, 1, 1.0 - k), w * 0.35)
	for bo in bolts:
		var a: float = 1.0 - bo.t / 0.25
		draw_polyline(bo.pts, Color(1, 1, 0.6, 0.5 * a), 10.0)
		draw_polyline(bo.pts, Color(1, 1, 1, a), 3.5)
