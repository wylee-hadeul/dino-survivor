extends Node2D
## 주인공. 이동, 체력/경험치, 무기·패시브 보유 목록, 탈것 탑승.

const Data = preload("res://scripts/data.gd")

const BASE_SPEED := 200.0

var run
var pos := Vector2.ZERO
var move_dir := Vector2.ZERO
var face := 1.0
var hp := 100.0
var max_hp := 100.0
var level := 1
var xp := 0.0
var invuln := 0.0
var hurt_t := 0.0
var anim := 0.0
var dead := false
var talents := {}
var weapons: Array = []     # {id, lv, cd}
var passives := {}          # id -> lv
var ride_gauge := 0.0       # 0..1
var vehicle := ""
var vehicle_id := "jeep"    # 차고에서 장착한 탈것
var vehicle_lv := 0
var vehicle_t := 0.0
var vehicle_max_t := 0.0
var vehicle_hp := 0.0
var vehicle_weapon := {"cd": 0.0}
var turret_angle := 0.0


func setup(t: Dictionary, veh_id: String, veh_lv: int) -> void:
	talents = t
	vehicle_id = veh_id
	vehicle_lv = veh_lv
	max_hp = _calc_max_hp()
	hp = max_hp
	weapons = [{"id": "pistol", "lv": 1, "cd": 0.5}]


func tl(id: String) -> int:
	return talents.get(id, 0)


func pv(id: String) -> int:
	return passives.get(id, 0)


func _calc_max_hp() -> float:
	return 100.0 + 12.0 * tl("hp") + 25.0 * pv("vital")


func speed() -> float:
	var s := BASE_SPEED * (1.0 + 0.03 * tl("spd")) * (1.0 + 0.10 * pv("boots"))
	if vehicle != "":
		s *= Data.vehicle(vehicle).speed
	return s


func might() -> float:
	return (1.0 + 0.06 * tl("atk")) * (1.0 + 0.12 * pv("might"))


func cd_mult() -> float:
	return 1.0 - 0.08 * pv("haste")


func magnet_range() -> float:
	return 140.0 * (1.0 + 0.1 * tl("mag")) * (1.0 + 0.35 * pv("magnet"))


func armor_mult() -> float:
	return (1.0 - 0.03 * tl("def")) * (1.0 - 0.08 * pv("armor"))


func xp_mult() -> float:
	return (1.0 + 0.06 * tl("xp")) * (1.0 + 0.12 * pv("wisdom"))


func gold_mult() -> float:
	return 1.0 + 0.1 * tl("gold")


func vehicle_power() -> float:
	return 1.0 + 0.2 * vehicle_lv


func radius() -> float:
	return 40.0 if vehicle != "" else 18.0


func xp_need() -> float:
	return floor(4.0 + level * 3.2 + pow(level, 1.4))


func facing_dir() -> Vector2:
	return move_dir.normalized() if move_dir.length() > 0.1 else Vector2(face, 0)


# ------------------------------------------------------------------ 성장

func add_xp(v: float) -> void:
	xp += v * xp_mult()
	while xp >= xp_need():
		xp -= xp_need()
		level += 1
		run.pending_levelups += 1


func weapon_lv(id: String) -> int:
	for w in weapons:
		if w.id == id:
			return w.lv
	return 0


func apply_choice(c: Dictionary) -> void:
	match c.type:
		"weapon":
			for w in weapons:
				if w.id == c.id:
					w.lv += 1
					return
			weapons.append({"id": c.id, "lv": 1, "cd": 0.2})
		"passive":
			passives[c.id] = pv(c.id) + 1
			if c.id == "vital":
				var old := max_hp
				max_hp = _calc_max_hp()
				hp = min(hp + (max_hp - old) + 20.0, max_hp)
		"heal":
			heal(40.0)
		"gold":
			run.add_gold(50)


func heal(v: float) -> void:
	hp = min(hp + v, max_hp)


# ------------------------------------------------------------------ 피해

func contact(e) -> void:
	if vehicle != "" and vehicle != "plane":
		return  # 지상 탈것은 들이받기로 처리 (전투기는 부딪히면 탈것 체력이 깎인다)
	hurt(e.dmg)


func hurt(dmg: float) -> void:
	if dead or invuln > 0.0:
		return
	if run.god:
		dmg = 0.0
	if vehicle != "":
		vehicle_hp -= dmg * 0.6
		invuln = 0.2
		hurt_t = 0.15
		if vehicle_hp <= 0.0:
			dismount()
		return
	hp -= dmg * armor_mult()
	invuln = 0.3
	hurt_t = 0.2
	run.sfx.play("hurt", -6.0)
	run.add_shake(4.0)
	if randf() < 0.15:
		run.voice.say("hurt")
	if hp < max_hp * 0.3 and hp + dmg >= max_hp * 0.3:
		run.voice.say("lowhp", true)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		run.on_player_dead()


# ------------------------------------------------------------------ 탈것

func can_ride() -> bool:
	return ride_gauge >= 1.0 and vehicle == "" and not dead


func add_ride(kills: int) -> void:
	if vehicle != "":
		return
	ride_gauge = min(1.0, ride_gauge + kills / float(Data.RIDE_KILLS) * (1.0 + 0.12 * tl("ride")))


func mount() -> void:
	if not can_ride():
		return
	var v := Data.vehicle(vehicle_id)
	vehicle = vehicle_id
	vehicle_max_t = v.time * (1.0 + 0.15 * vehicle_lv)
	vehicle_t = vehicle_max_t
	vehicle_hp = v.hp * (1.0 + 0.25 * vehicle_lv)
	ride_gauge = 0.0
	invuln = 0.5
	run.fx.ring(pos, 160.0, v.col)
	run.sfx.play("levelup", -4.0, 0.7)
	run.voice.say("ride", true)
	run.dlog("mount %s for %.1fs" % [vehicle, vehicle_max_t])


func dismount() -> void:
	if vehicle == "":
		return
	run.weapons.vehicle_end_blast()
	run.dlog("dismount %s" % vehicle)
	vehicle = ""
	invuln = 1.0


# ------------------------------------------------------------------ 갱신/그리기

func update(delta: float, input: Vector2) -> void:
	invuln -= delta
	hurt_t -= delta
	if dead:
		queue_redraw()
		return
	move_dir = input
	if input.length() > 0.05:
		pos += input.limit_length(1.0) * speed() * delta
		anim += delta * 9.0
		if abs(input.x) > 0.1:
			face = sign(input.x)
	if vehicle != "":
		vehicle_t -= delta
		if vehicle_t <= 0.0:
			dismount()
	queue_redraw()


func _draw() -> void:
	var sp = run.sprites
	var mod := Color.WHITE
	if hurt_t > 0.0:
		mod = Color(1, 0.5, 0.5)
	elif invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		mod = Color(1, 1, 1, 0.6)
	if dead:
		sp.draw(self, "shadow", pos, 0, false, 0.8)
		draw_set_transform(pos, -PI * 0.5 * face, Vector2.ONE)
		sp.draw(self, run.main.player_sprite(), Vector2(0, 0), 0, face < 0.0, 1.0, Color(0.8, 0.8, 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if vehicle != "":
		var bob := sin(anim * 1.5) * 2.0
		if vehicle == "plane":
			sp.draw(self, "shadow", pos + Vector2(0, 10), 0, false, 2.2)
			sp.draw(self, "plane", pos - Vector2(0, 70 + sin(anim) * 6.0), 0, face < 0.0, 1.0, mod)
		elif vehicle == "ship":
			sp.draw(self, "shadow", pos, 0, false, 2.6)
			draw_circle(pos + Vector2(-face * 80, -6), 16.0 + sin(anim * 3.0) * 4.0, Color(1, 1, 1, 0.35))
			sp.draw(self, "ship", pos + Vector2(0, bob - 8), 0, face < 0.0, 1.0, mod)
		else:
			sp.draw(self, "shadow", pos, 0, false, 2.4)
			sp.draw(self, vehicle, pos + Vector2(0, bob * 0.5), 0, face < 0.0, 1.0, mod)
			if vehicle == "tank":
				# 조준 방향으로 회전하는 포신
				var base := pos + Vector2(-6.0 * face, -66.0)
				var tip := base + Vector2.RIGHT.rotated(turret_angle) * 74.0
				draw_line(base, tip, Color("1d1a14"), 16.0)
				draw_line(base, tip, Color("4b5e28"), 10.0)
				draw_circle(tip, 9.0, Color("1d1a14"))
				draw_circle(tip, 6.0, Color("4b5e28"))
				draw_circle(base, 12.0, Color("1d1a14"))
				draw_circle(base, 9.0, Color("7d9a45"))
		# 남은 탑승 시간
		var k := vehicle_t / vehicle_max_t
		draw_rect(Rect2(pos.x - 40, pos.y + 14, 80, 7), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(pos.x - 39, pos.y + 15, 78 * k, 5), Color("ffb74d"))
		return
	sp.draw(self, "shadow", pos, 0, false, 0.7)
	var frame := int(anim) % 2 if move_dir.length() > 0.05 else 0
	sp.draw(self, run.main.player_sprite(), pos + Vector2(0, -abs(sin(anim)) * 3.0 if move_dir.length() > 0.05 else 0.0), frame, face < 0.0, 0.85, mod)
	# 체력바
	var w := 56.0
	draw_rect(Rect2(pos.x - w * 0.5, pos.y + 10, w, 8), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos.x - w * 0.5 + 1, pos.y + 11, (w - 2) * hp / max_hp, 6), Color("5ee35e") if hp > max_hp * 0.3 else Color("ff5252"))
