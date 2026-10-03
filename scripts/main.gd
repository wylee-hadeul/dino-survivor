extends Node2D
## 게임 전체 흐름: 타이틀 → 로비(스테이지 선택/강화/차고) → 스테이지(레벨업/일시정지) → 결과. 저장도 담당.

const Data = preload("res://scripts/data.gd")
const SpritesScript = preload("res://scripts/sprites.gd")
const RunScript = preload("res://scripts/run.gd")
const HudScript = preload("res://scripts/hud.gd")
const MenuScript = preload("res://scripts/menu.gd")
const JoystickScript = preload("res://scripts/joystick.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const VoiceScript = preload("res://scripts/voice.gd")
const AutoplayScript = preload("res://scripts/autoplay.gd")

enum State { BOOT, TITLE, LOBBY, TALENT, GARAGE, PLAYING, LEVELUP, PAUSE, RESULT }

var save_path := "user://save.cfg"
var state := State.BOOT
var view := Vector2(720, 1280)
var time := 0.0

var sprites
var run
var hud
var menu
var joystick
var sfx
var voice
var autoplay

# 저장 데이터
var gold := 0
var talents := {}
var unlocked := 1
var cleared := 0
var best := {}
var vehicle_lv := {}
var equipped := "jeep"

var selected_stage := 1
var choices: Array = []
var choice_sel := 0
var levelup_t := 0.0
var levelup_chest := false
var result := {}


func _ready() -> void:
	ThemeDB.fallback_font = load("res://fonts/Jua-Regular.ttf")
	randomize()
	_setup_input()
	var ap_args = _autoplay_args()
	if ap_args != null:
		save_path = "user://save_autoplay.cfg"
		if ap_args.has("--fresh"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	sfx = SfxScript.new()
	add_child(sfx)
	voice = VoiceScript.new()
	add_child(voice)
	_load()
	view = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): view = get_viewport_rect().size)
	sprites = SpritesScript.new()
	add_child(sprites)
	await sprites.bake()
	run = RunScript.new()
	run.main = self
	run.sprites = sprites
	run.sfx = sfx
	run.voice = voice
	add_child(run)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.main = self
	layer.add_child(hud)
	menu = MenuScript.new()
	menu.main = self
	menu.hud = hud
	layer.add_child(menu)
	joystick = JoystickScript.new()
	joystick.main = self
	layer.add_child(joystick)
	run.player.setup(talents, equipped, 0)
	_world_visible(false)
	if ap_args != null:
		autoplay = AutoplayScript.new()
		autoplay.main = self
		add_child(autoplay)
		autoplay.configure(ap_args)
	set_state(State.TITLE)


func _autoplay_args():
	var args := OS.get_cmdline_user_args()
	var on := args.has("--autoplay")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and q.contains("autoplay"):
			on = true
			for part in q.trim_prefix("?").split("&"):
				if part != "autoplay" and part != "":
					args.append("--" + part)
	return args if on else null


func dlog(msg: String) -> void:
	var t: float = run.t if run else 0.0
	print("[%7.2f|%6.1f] %s" % [time, t, msg])


func _setup_input() -> void:
	var map := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"ride": [KEY_SPACE, KEY_E, KEY_K], "pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func try_fullscreen(is_touch: bool) -> void:
	if not is_touch or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("(function(){var d=document.documentElement;if(d.requestFullscreen){d.requestFullscreen().catch(function(){});}})();", true)


func set_state(s: State) -> void:
	state = s
	menu.open()


func _world_visible(on: bool) -> void:
	for n in [run.hazards, run.pickups, run.enemies, run.player, run.weapons, run.fx]:
		n.visible = on


func show_banner(a: String, b: String) -> void:
	hud.show_banner(a, b)


# ------------------------------------------------------------------ 화면 전환

func goto_lobby() -> void:
	selected_stage = clampi(selected_stage, 1, unlocked)
	run.ground.theme = Data.stage_info(selected_stage).theme
	run.camera.position = Vector2.ZERO
	run.camera.offset = Vector2.ZERO
	run.enemies.clear()
	run.pickups.clear()
	run.hazards.clear()
	run.weapons.clear()
	_world_visible(false)
	joystick.reset()
	set_state(State.LOBBY)
	dlog("lobby gold=%d unlocked=%d cleared=%d" % [gold, unlocked, cleared])


func change_stage(d: int) -> void:
	selected_stage = clampi(selected_stage + d, 1, unlocked)
	run.ground.theme = Data.stage_info(selected_stage).theme


func start_run(s: int) -> void:
	s = clampi(s, 1, unlocked)
	selected_stage = s
	run.god = autoplay != null and autoplay.god
	run.start(s, talents, equipped, int(vehicle_lv.get(equipped, 0)))
	_world_visible(true)
	joystick.reset()
	set_state(State.PLAYING)
	show_banner("스테이지 %d" % s, Data.stage_info(s).name)


func buy_talent(id: String) -> String:
	var tl: Dictionary = {}
	for t in Data.TALENTS:
		if t.id == id:
			tl = t
	var lv: int = talents.get(id, 0)
	if lv >= tl.max:
		return "이미 최대 레벨입니다"
	var c := Data.talent_cost(tl, lv)
	if gold < c:
		sfx.play("hurt", -10.0)
		return "골드가 부족합니다"
	gold -= c
	talents[id] = lv + 1
	save_game()
	sfx.play("levelup", -6.0)
	dlog("talent %s -> Lv%d (cost %d, left %d)" % [id, lv + 1, c, gold])
	return "%s Lv%d 강화 완료!" % [tl.name, lv + 1]


func upgrade_vehicle(id: String) -> String:
	var lv: int = vehicle_lv.get(id, 0)
	if lv >= 5:
		return "이미 최대 레벨입니다"
	var c := Data.vehicle_cost(lv)
	if gold < c:
		sfx.play("hurt", -10.0)
		return "골드가 부족합니다"
	gold -= c
	vehicle_lv[id] = lv + 1
	save_game()
	sfx.play("levelup", -6.0)
	dlog("vehicle %s -> Lv%d (cost %d)" % [id, lv + 1, c])
	return "%s Lv%d 강화 완료!" % [Data.vehicle(id).name, lv + 1]


func on_run_finished(was_cleared: bool) -> void:
	var s: int = run.stage
	var bonus := 0
	if was_cleared:
		bonus = int(round(Data.clear_gold(s) * run.player.gold_mult()))
	var earned: int = run.run_gold + bonus
	gold += earned
	var unlock := ""
	if was_cleared:
		var prev := cleared
		cleared = max(cleared, s)
		unlocked = max(unlocked, s + 1)
		for v in Data.VEHICLES:
			if v.unlock > prev and v.unlock <= cleared:
				unlock = v.name
	best[str(s)] = max(float(best.get(str(s), 0.0)), run.t)
	result = {"cleared": was_cleared, "stage": s, "time": run.t, "kills": run.kills, "level": run.player.level, "gold": earned, "bonus": bonus, "unlock": unlock}
	save_game()
	set_state(State.RESULT)
	dlog("RESULT cleared=%s stage=%d time=%.1f kills=%d lv=%d gold=+%d total=%d unlock=%s" % [was_cleared, s, run.t, run.kills, run.player.level, earned, gold, unlock])


# ------------------------------------------------------------------ 레벨업

func _open_levelup() -> void:
	choices = run.build_choices(3)
	choice_sel = 0
	levelup_t = 0.0
	levelup_chest = run.chest_levelups > 0
	if levelup_chest:
		run.chest_levelups -= 1
	state = State.LEVELUP
	joystick.reset()
	sfx.play("levelup", -4.0)
	dlog("levelup offer: %s" % ", ".join(choices.map(func(c): return "%s(%d)" % [c.id, c.lv])))


func choose(i: int) -> void:
	if state != State.LEVELUP or i < 0 or i >= choices.size():
		return
	var c: Dictionary = choices[i]
	run.player.apply_choice(c)
	run.pending_levelups -= 1
	dlog("levelup chosen: %s -> Lv%d" % [c.id, c.lv + 1])
	if randf() < 0.35:
		voice.say("levelup")
	if run.pending_levelups > 0:
		_open_levelup()
	else:
		state = State.PLAYING


# ------------------------------------------------------------------ 입력

func _input(event: InputEvent) -> void:
	match state:
		State.PLAYING:
			if event is InputEventScreenTouch and event.pressed:
				match hud.button_at(event.position):
					"ride":
						run.player.mount()
						get_viewport().set_input_as_handled()
					"pause":
						state = State.PAUSE
						get_viewport().set_input_as_handled()
		State.LEVELUP:
			if levelup_t < 0.45:
				return
			if event is InputEventScreenTouch and event.pressed:
				var rects: Array = hud.card_rects(choices.size())
				for i in rects.size():
					if rects[i].has_point(event.position):
						choose(i)
						get_viewport().set_input_as_handled()
						return
			elif event is InputEventKey and event.pressed and not event.echo:
				var k: int = event.physical_keycode
				if k >= KEY_1 and k <= KEY_3:
					choose(k - KEY_1)
				elif event.is_action("up") or event.is_action("left"):
					choice_sel = posmod(choice_sel - 1, choices.size())
				elif event.is_action("down") or event.is_action("right"):
					choice_sel = posmod(choice_sel + 1, choices.size())
				elif k == KEY_ENTER or k == KEY_SPACE or k == KEY_J:
					choose(choice_sel)
		State.PAUSE:
			if event is InputEventScreenTouch and event.pressed:
				for b in hud.pause_buttons():
					if b.rect.has_point(event.position):
						_pause_action(b.id)
						get_viewport().set_input_as_handled()
						return
			elif event is InputEventKey and event.pressed and not event.echo:
				if event.is_action("pause"):
					_pause_action("resume")


func _pause_action(id: String) -> void:
	if id == "resume":
		state = State.PLAYING
	else:
		run.player.dead = true
		run._finish(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and autoplay == null:
		state = State.PAUSE


# ------------------------------------------------------------------ 루프

func _process(delta: float) -> void:
	delta = min(delta, 0.05)
	time += delta
	if state == State.BOOT:
		return
	match state:
		State.PLAYING:
			run.update(delta, joystick.direction())
			if Input.is_action_just_pressed("ride"):
				run.player.mount()
			if Input.is_action_just_pressed("pause"):
				state = State.PAUSE
			if state == State.PLAYING and run.pending_levelups > 0 and not run.player.dead and run.clear_t < 0.0:
				_open_levelup()
		State.LEVELUP:
			levelup_t += delta
		State.PAUSE:
			pass
		_:
			run.ground.queue_redraw()
			voice.update(delta, false)


# ------------------------------------------------------------------ 저장

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		gold = int(cfg.get_value("save", "gold", 0))
		talents = cfg.get_value("save", "talents", {})
		unlocked = int(cfg.get_value("save", "unlocked", 1))
		cleared = int(cfg.get_value("save", "cleared", 0))
		best = cfg.get_value("save", "best", {})
		vehicle_lv = cfg.get_value("save", "vehicle_lv", {})
		equipped = str(cfg.get_value("save", "equipped", "jeep"))
		voice.tts_enabled = bool(cfg.get_value("save", "voice", true))
	selected_stage = unlocked


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "gold", gold)
	cfg.set_value("save", "talents", talents)
	cfg.set_value("save", "unlocked", unlocked)
	cfg.set_value("save", "cleared", cleared)
	cfg.set_value("save", "best", best)
	cfg.set_value("save", "vehicle_lv", vehicle_lv)
	cfg.set_value("save", "equipped", equipped)
	cfg.set_value("save", "voice", voice.tts_enabled)
	cfg.save(save_path)
