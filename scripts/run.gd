extends Node2D
## 스테이지 한 판. 월드(바닥/아이템/공룡/플레이어/무기/효과)와 카메라, 스폰 곡선, 보스 일정을 관리한다.

const Data = preload("res://scripts/data.gd")
const GroundScript = preload("res://scripts/ground.gd")
const PickupScript = preload("res://scripts/pickups.gd")
const HazardScript = preload("res://scripts/hazards.gd")
const EnemyScript = preload("res://scripts/enemies.gd")
const PlayerScript = preload("res://scripts/player.gd")
const WeaponScript = preload("res://scripts/weapons.gd")
const FxScript = preload("res://scripts/fx.gd")

var main
var sprites
var sfx
var voice
var ground
var pickups
var hazards
var enemies
var player
var weapons
var fx
var camera: Camera2D

var stage := 1
var t := 0.0
var kills := 0
var kill_counts := {}  # 종류별 처치 수 (로그/검수용)
var run_gold := 0
var pending_levelups := 0
var chest_levelups := 0
var spawn_acc := 0.0
var events := {}
var boss_ref = null
var final_spawned := false
var clear_t := -1.0
var dead_t := -1.0
var revive_used := false
var shake := 0.0
var god := false
var finished := false


func _ready() -> void:
	ground = GroundScript.new()
	hazards = HazardScript.new()
	pickups = PickupScript.new()
	enemies = EnemyScript.new()
	player = PlayerScript.new()
	weapons = WeaponScript.new()
	fx = FxScript.new()
	for n in [ground, hazards, pickups, enemies, player, weapons, fx]:
		n.run = self
		add_child(n)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()


func dlog(s: String) -> void:
	main.dlog(s)


func start(s: int, talents: Dictionary, veh_id: String, veh_lv: int) -> void:
	stage = s
	t = 0.0
	kills = 0
	kill_counts = {}
	run_gold = 0
	pending_levelups = 0
	chest_levelups = 0
	spawn_acc = 0.0
	events = {}
	boss_ref = null
	final_spawned = false
	clear_t = -1.0
	dead_t = -1.0
	revive_used = false
	finished = false
	enemies.clear()
	pickups.clear()
	hazards.clear()
	weapons.clear()
	fx.clear()
	player.pos = Vector2.ZERO
	player.dead = false
	player.vehicle = ""
	player.ride_gauge = 0.0
	player.passives = {}
	player.level = 1
	player.xp = 0.0
	player.setup(talents, veh_id, veh_lv)
	ground.theme = Data.stage_info(s).theme
	camera.position = Vector2.ZERO
	voice.reset()
	voice.say("start", true)
	dlog("run start stage=%d vehicle=%s(lv%d)" % [s, veh_id, veh_lv])


# ------------------------------------------------------------------ 보조

func zoom() -> float:
	var v: Vector2 = main.view
	return max(1.0, min(v.x, v.y) / 720.0)


func visible_rect() -> Rect2:
	var size: Vector2 = main.view / zoom()
	return Rect2(camera.position - size * 0.5, size)


func view_radius() -> float:
	return (main.view / zoom()).length() * 0.5


func hp_mult() -> float:
	return Data.stage_hp_mult(stage) * (1.0 + t / Data.STAGE_TIME * 1.5)


func dmg_mult() -> float:
	return Data.stage_dmg_mult(stage) * (1.0 + t / Data.STAGE_TIME * 0.5)


func add_shake(a: float) -> void:
	shake = min(max(shake, a), 18.0)


func add_gold(g: int) -> void:
	var v := int(round(g * player.gold_mult()))
	run_gold += v


# ------------------------------------------------------------------ 갱신

func update(delta: float, input: Vector2) -> void:
	t += delta
	player.update(delta, input)
	_spawner(delta)
	enemies.update(delta)
	weapons.update(delta)
	hazards.update(delta)
	pickups.update(delta)
	fx.update(delta)
	voice.update(delta, true)
	# 카메라
	camera.zoom = Vector2.ONE * zoom()
	camera.position = camera.position.lerp(player.pos, min(1.0, delta * 8.0))
	shake = max(shake * exp(-8.0 * delta) - delta, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	ground.queue_redraw()
	if clear_t > 0.0:
		clear_t -= delta
		if clear_t <= 0.0:
			_finish(true)
	if dead_t >= 0.0:
		dead_t += delta
		if player.talents.get("revive", 0) > 0 and not revive_used and dead_t > 1.0:
			_revive()
		elif dead_t > 1.6 and (revive_used or player.talents.get("revive", 0) == 0):
			_finish(false)


## 시간에 따라 점점 많이, 점점 강하게
func _spawner(delta: float) -> void:
	if clear_t > 0.0 or player.dead:
		return
	var info := Data.stage_info(stage)
	var pool: Array = info.pool
	var types: Array = pool.slice(0, clampi(1 + int(t / 50.0), 1, pool.size()))
	var rate := (0.8 + t / 55.0) * (1.0 + 0.25 * (stage - 1))
	var cap: int = int(min(60.0 + t * 0.4 + 15.0 * (stage - 1), 230.0))
	if enemies.boss_alive:
		rate *= 0.45
	spawn_acc += rate * delta
	var alive: int = enemies.list.size()
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if alive >= cap:
			break
		var kind: String = types[randi() % types.size()]
		enemies.spawn(kind, _spawn_pos(), hp_mult(), dmg_mult())
		alive += 1
	# 이벤트
	for et in [60.0, 120.0, 180.0, 240.0]:
		if t >= et and not events.has("elite%d" % et):
			events["elite%d" % et] = true
			var kind: String = types[randi() % types.size()]
			enemies.spawn(kind, _spawn_pos(), hp_mult(), dmg_mult(), true)
			fx.text(player.pos + Vector2(0, -140), "정예 공룡 출현!", Color(1, 0.8, 0.3))
	for st in [75.0, 205.0]:
		if t >= st and not events.has("swarm%d" % st):
			events["swarm%d" % st] = true
			_swarm(types[0])
	if t >= Data.MINI_BOSS_TIME and not events.has("mini"):
		events["mini"] = true
		boss_ref = enemies.spawn_boss(info.mini, _spawn_pos(), Data.boss_hp_mult(stage), dmg_mult())
		main.show_banner("중간 보스 등장!", Data.BOSSES[info.mini].name)
		voice.say("mini", true)
		sfx.play("roar", 2.0, 0.6)
		dlog("mini boss: %s" % info.mini)
	if t >= Data.STAGE_TIME and not final_spawned:
		final_spawned = true
		boss_ref = enemies.spawn_boss(info.boss, _spawn_pos(), Data.boss_hp_mult(stage), dmg_mult())
		main.show_banner("최종 보스 등장!", Data.BOSSES[info.boss].name)
		voice.say("boss", true)
		sfx.play("roar", 4.0, 0.45)
		add_shake(12.0)
		dlog("final boss: %s" % info.boss)


func _spawn_pos() -> Vector2:
	return player.pos + Vector2.RIGHT.rotated(randf() * TAU) * (view_radius() + 60.0)


func _swarm(kind: String) -> void:
	var n := 26 + stage * 4
	var r := view_radius() * 0.95
	for i in n:
		var a := TAU * i / n
		enemies.spawn(kind, player.pos + Vector2(cos(a), sin(a)) * r, hp_mult(), dmg_mult())
	main.show_banner("공룡 떼가 몰려온다!", "")
	voice.say("swarm", true)
	dlog("swarm x%d" % n)


# ------------------------------------------------------------------ 이벤트

func on_enemy_killed(e) -> void:
	kills += 1
	kill_counts[e.kind] = kill_counts.get(e.kind, 0) + 1
	player.add_ride(1)
	if e.boss:
		fx.explosion(e.pos, 2.0, Color(1, 0.6, 0.3))
		add_shake(14.0)
		sfx.play("boom", 2.0, 0.6)
		pickups.drop("chest", e.pos)
		pickups.drop("gem", e.pos, 50)
		add_gold(40 * stage)
		voice.say("bossdown", true)
		dlog("boss down: %s at t=%.1f" % [e.boss_id, t])
		if e.boss_id == Data.stage_info(stage).boss:
			clear_t = 2.5
			# 남은 공룡은 함께 쓰러진다
			for o in enemies.list:
				if not o.dead and not o.boss:
					o.dead = true
					fx.death(o.pos, o.s)
			pickups.pull_all()
		return
	fx.death(e.pos, e.s)
	var xp: int = e.xp
	pickups.drop("gem", e.pos, xp)
	if e.elite:
		pickups.drop("chest", e.pos)
		pickups.drop("magnet", e.pos + Vector2(30, 0))
	var r := randf()
	if r < 0.05:
		pickups.drop("coin", e.pos, randi_range(1, 3))
	elif r < 0.062:
		pickups.drop("meat", e.pos)
	elif r < 0.066:
		pickups.drop("magnet", e.pos)


func open_chest() -> void:
	add_gold(20 + 5 * stage)
	pending_levelups += 1
	chest_levelups += 1
	fx.text(player.pos + Vector2(0, -120), "보급 상자!", Color(1, 0.85, 0.3), 34)
	voice.say("chest", true)
	sfx.play("levelup", -2.0, 0.8)


func on_player_dead() -> void:
	dead_t = 0.0
	player.dismount()
	sfx.play("roar", -4.0, 1.6)
	dlog("player down t=%.1f" % t)


func _revive() -> void:
	revive_used = true
	dead_t = -1.0
	player.dead = false
	player.hp = player.max_hp * 0.5
	player.invuln = 2.5
	weapons._explode(player.pos, 260.0, 200.0, Color(1, 0.6, 0.8))
	hazards.clear()
	voice.say("revive", true)
	dlog("revive")


func _finish(cleared: bool) -> void:
	if finished:
		return
	finished = true
	if cleared:
		voice.say("clear", true)
	main.on_run_finished(cleared)


## 레벨업 카드 후보
func build_choices(n: int) -> Array:
	var pool: Array = []
	for w in player.weapons:
		if w.lv < 5:
			var d: Dictionary = Data.WEAPONS[w.id]
			pool.append({"type": "weapon", "id": w.id, "lv": w.lv, "name": d.name, "desc": d.desc[w.lv], "col": d.col, "icon": "i_" + w.id, "w": 1.3})
	if player.weapons.size() < Data.MAX_WEAPONS:
		for id in Data.WEAPONS:
			if player.weapon_lv(id) == 0:
				var d: Dictionary = Data.WEAPONS[id]
				pool.append({"type": "weapon", "id": id, "lv": 0, "name": d.name, "desc": d.desc[0], "col": d.col, "icon": "i_" + id, "w": 1.0})
	for id in Data.PASSIVES:
		var d: Dictionary = Data.PASSIVES[id]
		var lv: int = player.pv(id)
		if lv < d.max:
			pool.append({"type": "passive", "id": id, "lv": lv, "name": d.name, "desc": d.desc, "col": d.col, "icon": "i_" + id, "w": 0.8})
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += c.w
		var r := randf() * total
		for i in pool.size():
			r -= pool[i].w
			if r <= 0.0:
				out.append(pool.pop_at(i))
				break
	if out.is_empty():
		out.append({"type": "heal", "id": "heal", "lv": 0, "name": "고기", "desc": "체력 40 회복", "col": Color("66bb6a"), "icon": "i_heal"})
		out.append({"type": "gold", "id": "gold", "lv": 0, "name": "골드 주머니", "desc": "골드 +50", "col": Color("ffd54f"), "icon": "i_gold"})
	return out
