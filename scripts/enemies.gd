extends Node2D
## 공룡 관리자. 수백 마리를 노드 하나에서 갱신/그리기하고, 공간 격자로 충돌을 빠르게 찾는다.
## 보스 패턴도 여기서 처리한다.

const Data = preload("res://scripts/data.gd")

const CELL := 80.0


class E:
	var kind := ""
	var sprite := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var knock := Vector2.ZERO
	var hp := 10.0
	var max_hp := 10.0
	var speed := 80.0
	var dmg := 5.0
	var r := 16.0
	var s := 1.0
	var xp := 1
	var armor := 0.0
	var flash := 0.0
	var anim := 0.0
	var face := 1.0
	var dead := false
	var fly := false
	var ranged := false
	var charge := false
	var elite := false
	var boss := false
	var boss_id := ""
	var state := "chase"
	var st := 0.0        # 상태 타이머
	var atk := 2.0       # 다음 공격까지
	var atk_i := 0
	var dir := Vector2.ZERO
	var saw_cd := 0.0
	var crush_cd := 0.0
	var alt := 0.0       # 높이 (점프/비행)


var run
var list: Array = []
var grid := {}
var sort_t := 0
var boss_alive = null


func clear() -> void:
	list.clear()
	grid.clear()
	boss_alive = null


func spawn(kind: String, pos: Vector2, hp_mult: float, dmg_mult: float, elite := false) -> E:
	var d: Dictionary = Data.ENEMIES[kind]
	var e := E.new()
	e.kind = kind
	e.sprite = kind
	e.pos = pos
	e.max_hp = d.hp * hp_mult * (8.0 if elite else 1.0)
	e.hp = e.max_hp
	e.speed = d.speed * randf_range(0.9, 1.1)
	e.dmg = d.dmg * dmg_mult
	e.r = d.r * (1.5 if elite else 1.0)
	e.s = d.s * (1.5 if elite else 1.0)
	e.xp = d.xp * (10 if elite else 1)
	e.armor = d.get("armor", 0.0)
	e.fly = d.get("fly", false)
	e.ranged = d.get("ranged", false)
	e.charge = d.get("charge", false)
	e.elite = elite
	e.atk = randf_range(1.5, 3.0)
	list.append(e)
	return e


func spawn_boss(id: String, pos: Vector2, hp_mult: float, dmg_mult: float) -> E:
	var d: Dictionary = Data.BOSSES[id]
	var e := E.new()
	e.kind = id
	e.boss = true
	e.boss_id = id
	e.sprite = d.sprite
	e.pos = pos
	e.max_hp = d.hp * hp_mult
	e.hp = e.max_hp
	e.speed = d.speed
	e.dmg = d.dmg * dmg_mult
	e.r = d.r
	e.s = d.s
	e.xp = 60
	e.atk = 2.5
	list.append(e)
	boss_alive = e
	return e


# ------------------------------------------------------------------ 질의

func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _rebuild_grid() -> void:
	grid.clear()
	for e in list:
		var k := _key(e.pos)
		if grid.has(k):
			grid[k].append(e)
		else:
			grid[k] = [e]


## 명중 판정 기준점: 발밑이 아니라 몸통 중심 (총알은 몸 높이로 날아간다)
static func body(e) -> Vector2:
	return e.pos - Vector2(0, e.r * 0.9 + e.alt)


## pos에서 radius 안에 있는 공룡 (몸 반경 포함, 몸통 중심 기준)
func query(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var reach := radius + 80.0
	var k0 := _key(pos - Vector2(reach, reach))
	var k1 := _key(pos + Vector2(reach, reach))
	for gx in range(k0.x, k1.x + 1):
		for gy in range(k0.y, k1.y + 1):
			var cell = grid.get(Vector2i(gx, gy))
			if cell == null:
				continue
			for e in cell:
				if not e.dead and body(e).distance_squared_to(pos) <= (radius + e.r) * (radius + e.r):
					out.append(e)
	return out


func nearest(pos: Vector2, max_dist := 99999.0) -> E:
	var best: E = null
	var bd := max_dist * max_dist
	for e in list:
		if e.dead:
			continue
		var d: float = e.pos.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = e
	return best


func random_near(pos: Vector2, max_dist: float) -> E:
	var cands: Array = []
	for e in list:
		if not e.dead and e.pos.distance_squared_to(pos) < max_dist * max_dist:
			cands.append(e)
	if cands.is_empty():
		return null
	return cands[randi() % cands.size()]


# ------------------------------------------------------------------ 피해

func damage(e: E, amount: float, knock_dir := Vector2.ZERO, knock := 0.0) -> void:
	if e.dead:
		return
	if e.boss and e.alt > 40.0:
		return  # 점프 낙하 중인 보스만 맞지 않는다 (비행 공룡은 맞는다)
	amount *= 1.0 - e.armor * 0.6
	e.hp -= amount
	e.flash = 0.1
	if not e.boss and knock > 0.0:
		e.knock += knock_dir * knock * (0.4 if e.elite else 1.0)
	run.fx.number(e.pos + Vector2(randf_range(-10, 10), -e.r * 2.0 - e.alt), amount, e.boss)
	if e.hp <= 0.0:
		kill(e)


func kill(e: E) -> void:
	if e.dead:
		return
	e.dead = true
	run.on_enemy_killed(e)


# ------------------------------------------------------------------ 갱신

func update(delta: float) -> void:
	_rebuild_grid()
	var p: Vector2 = run.player.pos
	var view_r: float = run.view_radius()
	for e in list:
		if e.dead:
			continue
		e.anim += delta * (e.speed / 40.0 + 2.0)
		e.flash = max(e.flash - delta, 0.0)
		e.saw_cd -= delta
		e.crush_cd -= delta
		var to_p: Vector2 = p - e.pos
		var dist: float = to_p.length()
		var dir: Vector2 = to_p / max(dist, 0.001)
		if e.boss:
			_boss_update(e, delta, dir, dist)
		else:
			_enemy_update(e, delta, dir, dist)
			# 너무 멀어지면 플레이어 앞쪽으로 다시 배치
			if dist > view_r * 1.9:
				var mv: Vector2 = run.player.move_dir if run.player.move_dir.length() > 0.1 else -dir
				e.pos = p + mv.normalized().rotated(randf_range(-0.8, 0.8)) * view_r * 1.15
		e.pos += (e.vel + e.knock) * delta
		e.knock = e.knock.move_toward(Vector2.ZERO, 900.0 * delta)
		if abs(e.vel.x) > 5.0:
			e.face = sign(e.vel.x)
		# 접촉 피해
		if e.alt < 30.0 and not e.fly or (e.fly and dist < e.r + 18.0):
			if dist < e.r + run.player.radius():
				run.player.contact(e)
	_separate()
	# 죽은 공룡 정리
	var i := 0
	while i < list.size():
		if list[i].dead:
			if list[i] == boss_alive:
				boss_alive = null
			list[i] = list[-1]
			list.pop_back()
		else:
			i += 1
	sort_t += 1
	if sort_t % 4 == 0:
		list.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	queue_redraw()


func _enemy_update(e: E, delta: float, dir: Vector2, dist: float) -> void:
	e.st -= delta
	e.atk -= delta
	if e.ranged:
		var want := 0.0
		if dist > 300.0:
			want = 1.0
		elif dist < 220.0:
			want = -0.7
		e.vel = dir * e.speed * want + dir.orthogonal() * e.speed * 0.3 * sin(e.anim * 0.3)
		if e.atk <= 0.0 and dist < 520.0:
			e.atk = randf_range(2.4, 3.2)
			run.hazards.bullet(e.pos + Vector2(0, -e.r), dir * 230.0, e.dmg, "spit", 10.0)
		return
	if e.charge:
		match e.state:
			"chase":
				e.vel = dir * e.speed
				if e.atk <= 0.0 and dist < 320.0:
					e.state = "prep"
					e.st = 0.6
					e.dir = dir
			"prep":
				e.vel = Vector2.ZERO
				e.knock = Vector2(randf_range(-30, 30), 0)
				if e.st <= 0.0:
					e.state = "rush"
					e.st = 0.7
			"rush":
				e.vel = e.dir * e.speed * 4.5
				if e.st <= 0.0:
					e.state = "chase"
					e.atk = randf_range(2.5, 3.5)
		return
	if e.fly:
		e.vel = dir * e.speed + dir.orthogonal() * sin(e.anim * 0.5) * 80.0
		e.alt = 32.0  # 낮게 날아 총알이 맞는 위치와 보이는 위치가 크게 어긋나지 않게
		return
	e.vel = dir * e.speed


func _separate() -> void:
	for k in grid:
		var cell: Array = grid[k]
		var n: int = min(cell.size(), 10)
		for a in n:
			var ea: E = cell[a]
			if ea.fly or ea.boss:
				continue
			for b in range(a + 1, n):
				var eb: E = cell[b]
				if eb.fly:
					continue
				var dv := ea.pos - eb.pos
				var min_d := (ea.r + eb.r) * 0.8
				var d2 := dv.length_squared()
				if d2 < min_d * min_d and d2 > 0.01:
					var d := sqrt(d2)
					var push := dv / d * (min_d - d) * 0.5
					ea.pos += push
					if not eb.boss:
						eb.pos -= push


# ------------------------------------------------------------------ 보스 패턴

const BOSS_ATTACKS := {
	"raptor_king": ["dash", "summon", "dash"],
	"trike_king": ["charge", "charge", "ring"],
	"trex": ["ring", "charge", "rocks", "charge"],
	"spino": ["fan", "dive", "fan", "rocks"],
	"brachio": ["stomp3", "rocks", "stomp3", "summon"],
	"giga": ["charge", "charge", "ring", "summon", "rocks"],
}


func _boss_update(e: E, delta: float, dir: Vector2, dist: float) -> void:
	var enr := 0.7 if e.hp < e.max_hp * 0.5 else 1.0  # 분노: 패턴이 빨라진다
	e.st -= delta
	match e.state:
		"chase":
			var spd := e.speed * (1.6 if dist > 700.0 else 1.0)
			e.vel = dir * spd
			e.atk -= delta
			if e.atk <= 0.0:
				var pats: Array = BOSS_ATTACKS[e.boss_id]
				var a: String = pats[e.atk_i % pats.size()]
				e.atk_i += 1
				_boss_begin(e, a, dir)
		"dash_prep", "charge_prep":
			e.vel = Vector2.ZERO
			e.knock = Vector2(randf_range(-40, 40), 0)
			if e.st <= 0.0:
				e.state = "dash" if e.state == "dash_prep" else "charge"
				e.st = 0.55 if e.state == "dash" else 1.0
				run.sfx.play("roar", -8.0, 1.3)
		"dash", "charge":
			e.vel = e.dir * (680.0 if e.state == "dash" else 600.0)
			if fmod(e.anim, 0.4) < 0.1:
				run.fx.dust(e.pos, 0.6)
			if e.st <= 0.0:
				_boss_end(e, enr)
		"dive":
			# 공중으로 뛰어올라 플레이어 위치로 낙하
			var k := 1.0 - e.st / 1.3
			e.alt = sin(clamp(k, 0.0, 1.0) * PI) * 260.0
			e.pos = e.pos.lerp(e.dir, min(1.0, delta * 3.0))
			e.vel = Vector2.ZERO
			if e.st <= 0.0:
				e.alt = 0.0
				run.hazards.ring(e.pos, 220.0, 520.0, e.dmg)
				run.add_shake(16.0)
				run.sfx.play("boom", 0.0, 0.6)
				_boss_end(e, enr)
		"stomp3":
			e.vel = Vector2.ZERO
			if e.st <= 0.0:
				e.atk_i += 0
				run.hazards.ring(e.pos, 380.0, 360.0, e.dmg * 0.8)
				run.add_shake(10.0)
				run.sfx.play("boom", -4.0, 0.5)
				e.dir.x -= 1.0
				if e.dir.x <= 0.0:
					_boss_end(e, enr)
				else:
					e.st = 0.55
		_:
			if e.st <= 0.0:
				_boss_end(e, enr)


func _boss_begin(e: E, a: String, dir: Vector2) -> void:
	var p: Vector2 = run.player.pos
	match a:
		"dash", "charge":
			e.state = a + "_prep"
			e.st = 0.65
			e.dir = dir
			run.hazards.line(e.pos, e.pos + dir * (420.0 if a == "dash" else 600.0), 0.65, e.r * 1.4)
		"summon":
			e.state = "summon"
			e.st = 0.8
			e.vel = Vector2.ZERO
			var kind := "raptor" if e.boss_id != "brachio" else "compy"
			var n := 6 if kind == "raptor" else 10
			for i in n:
				var ang := TAU * i / n
				spawn(kind, e.pos + Vector2(cos(ang), sin(ang)) * 90.0, run.hp_mult(), run.dmg_mult())
			run.sfx.play("roar", -2.0, 1.1)
			run.fx.text(e.pos + Vector2(0, -e.r * 3.0), "부하 소환!", Color(1, 0.5, 0.4))
		"ring":
			e.state = "ring"
			e.st = 0.9
			e.vel = Vector2.ZERO
			run.hazards.ring(e.pos, 420.0, 330.0, e.dmg)
			run.sfx.play("roar", 0.0, 0.7)
			run.add_shake(10.0)
		"rocks":
			e.state = "rocks"
			e.st = 1.0
			e.vel = Vector2.ZERO
			for i in 7:
				var off := Vector2.ZERO if i == 0 else Vector2(randf_range(-220, 220), randf_range(-220, 220))
				run.hazards.marker(p + off, 70.0, 1.1 + i * 0.08, e.dmg * 0.9, "rock")
			run.sfx.play("roar", -4.0, 0.9)
		"fan":
			e.state = "fan"
			e.st = 0.8
			e.vel = Vector2.ZERO
			for i in 9:
				var ang := (i - 4) * 0.16
				run.hazards.bullet(e.pos + Vector2(0, -e.r), dir.rotated(ang) * 260.0, e.dmg * 0.6, "spit", 12.0)
			run.sfx.play("roar", -4.0, 1.4)
		"dive":
			e.state = "dive"
			e.st = 1.3
			e.dir = p
			run.hazards.marker(p, 150.0, 1.3, 0.0, "land")
		"stomp3":
			e.state = "stomp3"
			e.st = 0.4
			e.dir = Vector2(3, 0)  # 남은 쿵 횟수
		_:
			e.state = "chase"


func _boss_end(e: E, enr: float) -> void:
	e.state = "chase"
	e.atk = 2.2 * enr
	e.alt = 0.0


# ------------------------------------------------------------------ 그리기

func _draw() -> void:
	var sp = run.sprites
	var cam: Rect2 = run.visible_rect().grow(200)
	for e in list:
		if not cam.has_point(e.pos):
			continue
		var sc: float = e.s * (1.0 + (0.08 if e.state.ends_with("_prep") or e.state == "prep" else 0.0))
		sp.draw(self, "shadow", e.pos, 0, false, e.r / 26.0)
		var frame := int(e.anim) % 2
		var mod := Color.WHITE
		if e.flash > 0.0:
			mod = Color(1.0, 0.55, 0.55)
		elif e.elite:
			mod = Color(1.0, 0.85, 0.6)
		elif e.boss and e.hp < e.max_hp * 0.5:
			mod = Color(1.0, 0.8, 0.8)
		var drawpos: Vector2 = e.pos - Vector2(0, e.alt)
		sp.draw(self, e.sprite, drawpos, frame, e.face < 0.0, sc, mod)
		if e.boss_id == "raptor_king" or e.boss_id == "trike_king" or e.elite:
			var top: float = sp.size_of(e.sprite).y * sc * 0.9
			sp.draw(self, "crown", drawpos + Vector2(e.face * sp.size_of(e.sprite).x * sc * 0.18, -top), 0, false, 0.8 + sc * 0.3)
		if e.elite and e.hp < e.max_hp:
			var w := 60.0
			draw_rect(Rect2(e.pos.x - w * 0.5, e.pos.y + 8, w, 6), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(e.pos.x - w * 0.5 + 1, e.pos.y + 9, (w - 2) * e.hp / e.max_hp, 4), Color("ff5252"))
