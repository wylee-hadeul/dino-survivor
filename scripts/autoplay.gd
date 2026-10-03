extends Node
## 테스트용 오토플레이 봇 + 스크린샷/로그.
## 실행: godot --path . -- --autoplay [옵션]
##   --shots=DIR --shot-every=SEC  주기적 스크린샷 (+ 화면별 첫 장면 자동 캡처)
##   --duration=SEC                실제 시간 기준 종료
##   --speed=N                     게임 속도 배율 (Engine.time_scale)
##   --stage=N --gold=N --god --fresh --suicide=SEC
## 웹: index.html?autoplay&stage=2&god
## 오토플레이는 user://save_autoplay.cfg 를 사용해 실제 저장을 건드리지 않는다.

const Data = preload("res://scripts/data.gd")

var main
var shots_dir := ""
var duration := 120.0
var shot_every := 10.0
var elapsed := 0.0
var next_shot := 2.0
var next_log := 0.0
var shot_n := 0
var frames := 0
var fps_acc := 0.0
var wait_t := 0.0
var god := false
var start_stage := 0
var suicide_at := -1.0
var shot_keys := {}
var wander := 0.0
var skip_to := -1.0  # 스테이지 시작 시 이 시각으로 건너뛴다 (보스 검수용)
var chase_boss := false
var force_vehicle := ""  # 검수용: 이 탈것을 강제로 장착
var ride_full := false


func configure(args: PackedStringArray) -> void:
	process_priority = -10
	for a in args:
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--duration="):
			duration = float(a.substr(11))
		elif a.begins_with("--shot-every="):
			shot_every = float(a.substr(13))
		elif a.begins_with("--speed="):
			Engine.time_scale = float(a.substr(8))
		elif a.begins_with("--stage="):
			start_stage = int(a.substr(8))
			main.unlocked = max(main.unlocked, start_stage)
			main.cleared = max(main.cleared, start_stage - 1)
		elif a.begins_with("--gold="):
			main.gold = int(a.substr(7))
		elif a.begins_with("--suicide="):
			suicide_at = float(a.substr(10))
		elif a.begins_with("--skipto="):
			skip_to = float(a.substr(9))
		elif a.begins_with("--vehicle="):
			force_vehicle = a.substr(10)
			if not main.owned_vehicles.has(force_vehicle):
				main.owned_vehicles.append(force_vehicle)
			main.equipped = force_vehicle
		elif a == "--ridefull":
			ride_full = true
		elif a == "--chaseboss":
			chase_boss = true
		elif a.begins_with("--char="):
			main.choose_character(a.substr(7))
		elif a == "--god":
			god = true
	main.voice.tts_enabled = false  # 테스트 중엔 음성을 끈다
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	main.dlog("autoplay: duration=%.0f speed=%.1f stage=%d god=%s gold=%d" % [duration, Engine.time_scale, start_stage, god, main.gold])


func _process(delta: float) -> void:
	var real: float = delta / max(Engine.time_scale, 0.01)
	elapsed += real
	frames += 1
	fps_acc += real
	wait_t += real
	var S = main.State
	match main.state:
		S.TITLE:
			if wait_t > 1.0:
				_shot("title")
				main.after_title()
				wait_t = 0.0
		S.CHARSELECT:
			if wait_t > 0.6 and main.character == "":
				main.menu.activate("char:" + ("f" if randf() < 0.5 else "m"))
			elif wait_t > 1.4:
				_shot("charselect")
				main.menu.activate("char_ok")
				wait_t = 0.0
		S.LOBBY:
			_shot("lobby")
			if wait_t > 0.8:
				wait_t = 0.0
				if _buyable_vehicle() != "":
					main.menu.activate("garage")
				elif _cheapest_talent() != "":
					main.menu.activate("talent")
				elif _garage_todo():
					main.menu.activate("garage")
				else:
					main.selected_stage = start_stage if start_stage > 0 else main.unlocked
					start_stage = 0
					main.menu.activate("play")
		S.TALENT:
			_shot("talent")
			if wait_t > 0.4:
				wait_t = 0.0
				var id := _cheapest_talent()
				if id != "":
					main.menu.activate("buy:" + id)
				else:
					main.menu.activate("back")
		S.GARAGE:
			_shot("garage")
			if wait_t > 0.5:
				wait_t = 0.0
				var best_v := _best_vehicle()
				var buy := _buyable_vehicle()
				if buy != "":
					main.menu.activate("vbuy:" + buy)
				elif main.equipped != best_v:
					main.menu.activate("equip:" + best_v)
				elif int(main.vehicle_lv.get(best_v, 0)) < 5 and main.gold >= Data.vehicle_cost(int(main.vehicle_lv.get(best_v, 0))) and main.gold > 300:
					main.menu.activate("vup:" + best_v)
				else:
					main.menu.activate("back")
		S.LEVELUP:
			if main.levelup_t > 0.6:
				_shot("levelup")
				main.choose(_pick_choice())
		S.RESULT:
			_shot("result_%s" % ("clear" if main.result.cleared else "fail"))
			if wait_t > 2.0:
				wait_t = 0.0
				main.menu.activate("lobby")
		S.PLAYING:
			wait_t = 0.0
			_play()
	main.joystick.bot_dir = _move_dir() if main.state == S.PLAYING else null

	if elapsed >= next_log:
		next_log += 2.0
		var r = main.run
		var p = r.player
		var boss := ""
		if r.enemies.boss_alive:
			var b = r.enemies.boss_alive
			boss = " boss=%s(%.0f/%.0f,%s)" % [b.boss_id, b.hp, b.max_hp, b.state]
		main.dlog("state=%s stage=%d hp=%.0f/%.0f lv=%d kills=%d gold=%d+%d enemies=%d proj=%d gems=%d fx=%d ride=%.2f veh=%s fps=%.0f%s" % [
			main.State.keys()[main.state], r.stage, p.hp, p.max_hp, p.level, r.kills, main.gold, r.run_gold,
			r.enemies.list.size(), r.weapons.projs.size(), r.pickups.gem_count, r.fx.parts.size(), p.ride_gauge, p.vehicle,
			frames / max(fps_acc, 0.001), boss])
		frames = 0
		fps_acc = 0.0
	if shots_dir != "" and elapsed >= next_shot and main.state != S.BOOT:
		next_shot += shot_every
		_screenshot("")
	if elapsed >= duration:
		main.dlog("kill counts: %s" % main.run.kill_counts)
		main.dlog("projectiles fired=%s landed=%s" % [main.run.weapons.fired, main.run.weapons.landed])
		main.dlog("autoplay done: gold=%d cleared=%d talents=%s vehicles=%s" % [main.gold, main.cleared, main.talents, main.vehicle_lv])
		get_tree().quit()


func _play() -> void:
	var r = main.run
	var p = r.player
	if skip_to > 0.0 and r.t < skip_to - 5.0:
		r.t = skip_to
		r.events["mini"] = true
		for w in ["shotgun", "grenade", "saw", "lightning", "laser"]:
			p.weapons.append({"id": w, "lv": 3, "cd": 0.5})
		main.dlog("skip to t=%.0f" % skip_to)
	if suicide_at > 0.0 and elapsed >= suicide_at:
		suicide_at = -1.0
		r.god = false
		p.invuln = 0.0
		p.vehicle = ""
		p.hurt(999999.0)
	if ride_full and p.vehicle == "":
		p.ride_gauge = 1.0
	if p.can_ride():
		p.mount()
	if p.vehicle != "":
		_shot("ride_" + p.vehicle)
	if r.enemies.boss_alive:
		_shot("boss_" + r.enemies.boss_alive.boss_id)
	if not r.hazards.markers.is_empty() or not r.hazards.rings.is_empty():
		_shot("hazard")
	if r.enemies.list.size() > 120:
		_shot("horde")


## 적에게서 멀어지고, 위험을 피하고, 보석/상자 쪽으로 이동
func _move_dir() -> Vector2:
	var r = main.run
	var p: Vector2 = r.player.pos
	var v := Vector2.ZERO
	var close := 0
	for e in r.enemies.query(p, 280.0):
		var d: Vector2 = p - e.pos
		var dist: float = max(d.length(), 1.0)
		var w := 3.0 if e.boss else 1.0
		v += d / dist * w * (280.0 / dist)
		if dist < 140.0:
			close += 1
	if r.enemies.boss_alive:
		var b = r.enemies.boss_alive
		var d: Vector2 = p - b.pos
		if chase_boss and d.length() > 300.0:
			v -= d.normalized() * 5.0  # 검수용: 보스가 화면에 보이도록 붙어 다닌다
		elif d.length() < 420.0:
			v += d.normalized() * 6.0
	v += r.hazards.danger_at(p) * 8.0
	# 아이템
	var best = null
	var bd := 520.0
	for it in r.pickups.items:
		var dd: float = it.pos.distance_to(p)
		var want: float = dd * (0.4 if it.kind == "chest" else 1.0)
		if want < bd:
			bd = want
			best = it
	if best and close < 5:
		v += (best.pos - p).normalized() * (7.0 if best.kind == "chest" else 4.0)
	# 제자리에 갇히지 않도록 원을 그리며 이동
	wander += 0.01
	v += Vector2.RIGHT.rotated(wander) * 1.2
	if v.length() < 0.1:
		return Vector2.ZERO
	return v.normalized()


func _pick_choice() -> int:
	var best_i := 0
	var best_s := -1.0
	for i in main.choices.size():
		var c: Dictionary = main.choices[i]
		var s := randf()
		if c.type == "weapon":
			s += 1.0 if c.lv > 0 else 0.6
		if c.id == "vital" and main.run.player.hp < main.run.player.max_hp * 0.5:
			s += 1.5
		if s > best_s:
			best_s = s
			best_i = i
	return best_i


func _cheapest_talent() -> String:
	var best_id := ""
	var best_c := 1 << 30
	for t in Data.TALENTS:
		var lv: int = main.talents.get(t.id, 0)
		if lv >= t.max:
			continue
		var c := Data.talent_cost(t, lv)
		if c <= main.gold and c < best_c:
			best_c = c
			best_id = t.id
	return best_id


func _best_vehicle() -> String:
	if force_vehicle != "":
		return force_vehicle
	var b := "jeep"
	for v in Data.VEHICLES:
		if main.owned_vehicles.has(v.id):
			b = v.id
	return b


## 다음으로 살 탈것 (살 수 있으면)
func _buyable_vehicle() -> String:
	for v in Data.VEHICLES:
		if not main.owned_vehicles.has(v.id):
			return v.id if main.gold >= v.price else ""
	return ""


func _garage_todo() -> bool:
	if _buyable_vehicle() != "":
		return true
	var bv := _best_vehicle()
	if main.equipped != bv:
		return true
	var lv: int = main.vehicle_lv.get(bv, 0)
	return lv < 5 and main.gold >= Data.vehicle_cost(lv) and main.gold > 300


func _shot(key: String) -> void:
	if shots_dir == "" or shot_keys.has(key):
		return
	shot_keys[key] = true
	_screenshot(key)


func _screenshot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	shot_n += 1
	if tag == "":
		tag = main.State.keys()[main.state].to_lower()
	var path := "%s/shot_%03d_s%d_%s.png" % [shots_dir, shot_n, main.run.stage if main.run else 0, tag]
	img.save_png(path)
	main.dlog("screenshot " + path.get_file())
