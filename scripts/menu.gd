extends Node2D
## 아웃게임 화면: 타이틀, 로비(스테이지 선택), 영구 강화, 차고(탈것), 결과.
## 버튼은 터치(마우스는 터치로 에뮬레이트) 또는 키보드(←/→ 이동, Enter/J 선택, Esc 뒤로)로 조작한다.

const Data = preload("res://scripts/data.gd")

const GREEN := Color("43a047")
const GREY := Color("455a64")
const ORANGE := Color("ef6c00")
const BLUE := Color("1e88e5")
const COIN := Color("ffd54f")

var main
var hud
var focus := 0
var open_t := 0.0
var toast := ""
var toast_t := 0.0


func open() -> void:
	focus = 0
	open_t = 0.0


func active() -> bool:
	return main.state in [main.State.TITLE, main.State.CHARSELECT, main.State.LOBBY, main.State.TALENT, main.State.GARAGE, main.State.RESULT]


func show_toast(s: String) -> void:
	toast = s
	toast_t = 1.8


func _process(delta: float) -> void:
	open_t += delta
	toast_t -= delta
	queue_redraw()


# ------------------------------------------------------------------ 레이아웃

func layout() -> Array:
	var v: Vector2 = main.view
	var cx := v.x * 0.5
	var out: Array = []
	match main.state:
		main.State.CHARSELECT:
			var cw: float = min(320.0, (v.x - 60.0) * 0.5)
			var ch := 470.0
			var y := 300.0
			out.append({"id": "char:m", "rect": Rect2(cx - cw - 10, y, cw, ch), "kind": "char", "c": "m", "enabled": true})
			out.append({"id": "char:f", "rect": Rect2(cx + 10, y, cw, ch), "kind": "char", "c": "f", "enabled": true})
			out.append({"id": "char_ok", "rect": Rect2(cx - 230, y + ch + 50, 460, 120), "label": "이 캐릭터로 시작!", "col": GREEN, "size": 44, "enabled": main.character != ""})
		main.State.LOBBY:
			var p := _stage_panel()
			out.append({"id": "prev", "rect": Rect2(p.position.x - 30, p.get_center().y - 50, 70, 100), "kind": "arrow", "dir": -1, "enabled": main.selected_stage > 1})
			out.append({"id": "next", "rect": Rect2(p.end.x - 40, p.get_center().y - 50, 70, 100), "kind": "arrow", "dir": 1, "enabled": main.selected_stage < main.unlocked})
			out.append({"id": "play", "rect": Rect2(cx - 230, p.end.y + 40, 460, 124), "label": "출격!", "col": GREEN, "size": 56, "enabled": true})
			var bw: float = min(210.0, (v.x - 80.0) / 3.0)
			var by := v.y - 170.0
			out.append({"id": "talent", "rect": Rect2(cx - bw * 1.5 - 12, by, bw, 104), "label": "강화", "col": ORANGE, "enabled": true})
			out.append({"id": "garage", "rect": Rect2(cx - bw * 0.5, by, bw, 104), "label": "차고", "col": BLUE, "enabled": true})
			out.append({"id": "voice", "rect": Rect2(cx + bw * 0.5 + 12, by, bw, 104), "label": "음성 켜짐" if main.voice.tts_enabled else "음성 꺼짐", "col": GREY, "size": 30, "enabled": true})
			out.append({"id": "charsel", "rect": Rect2(cx - 290, 380, 150, 64), "label": "캐릭터", "col": Color("8e24aa"), "size": 28, "enabled": true})
		main.State.TALENT:
			out.append({"id": "back", "rect": Rect2(24, 40, 150, 72), "label": "뒤로", "col": GREY, "enabled": true})
			var cols := 3
			var gap := 14.0
			var cw: float = min(214.0, (v.x - 40.0) / cols - gap)
			var ch := 250.0
			var x0: float = cx - (cols * cw + (cols - 1) * gap) * 0.5
			for i in Data.TALENTS.size():
				var tl: Dictionary = Data.TALENTS[i]
				out.append({"id": "buy:" + tl.id, "rect": Rect2(x0 + (i % cols) * (cw + gap), 200.0 + (i / cols) * (ch + gap), cw, ch), "kind": "talent", "t": tl, "enabled": true})
		main.State.GARAGE:
			out.append({"id": "back", "rect": Rect2(24, 40, 150, 72), "label": "뒤로", "col": GREY, "enabled": true})
			var w: float = min(660.0, v.x - 40.0)
			for i in Data.VEHICLES.size():
				var vh: Dictionary = Data.VEHICLES[i]
				var r := Rect2(cx - w * 0.5, 190.0 + i * 236.0, w, 216)
				out.append({"id": "card:" + vh.id, "rect": r, "kind": "vehicle", "v": vh, "enabled": false})
				if not main.owned_vehicles.has(vh.id):
					out.append({"id": "vbuy:" + vh.id, "rect": Rect2(r.end.x - 200, r.position.y + 72, 176, 76), "label": "구매", "col": ORANGE, "size": 32, "enabled": true})
				else:
					var equipped: bool = main.equipped == vh.id
					out.append({"id": "equip:" + vh.id, "rect": Rect2(r.end.x - 200, r.position.y + 30, 176, 72), "label": "장착 중" if equipped else "장착", "col": GREEN if not equipped else GREY, "size": 30, "enabled": not equipped})
					var lv: int = main.vehicle_lv.get(vh.id, 0)
					var maxed := lv >= 5
					var cost := Data.vehicle_cost(lv)
					out.append({"id": "vup:" + vh.id, "rect": Rect2(r.end.x - 200, r.position.y + 116, 176, 72), "label": "최대" if maxed else "강화 %d" % cost, "col": ORANGE, "size": 26, "enabled": not maxed})
		main.State.RESULT:
			var r: Dictionary = main.result
			var y := v.y * 0.5 + 250.0
			if r.cleared:
				out.append({"id": "next_stage", "rect": Rect2(cx - 230, y, 460, 110), "label": "다음 스테이지", "col": GREEN, "enabled": open_t > 1.0})
			else:
				out.append({"id": "retry", "rect": Rect2(cx - 230, y, 460, 110), "label": "다시 도전", "col": GREEN, "enabled": open_t > 1.0})
			out.append({"id": "lobby", "rect": Rect2(cx - 230, y + 130, 460, 100), "label": "로비로", "col": GREY, "enabled": open_t > 1.0})
	return out


func _stage_panel() -> Rect2:
	var v: Vector2 = main.view
	return Rect2(v.x * 0.5 - min(320.0, v.x * 0.5 - 30.0), 470, min(640.0, v.x - 60.0), 340)


# ------------------------------------------------------------------ 입력

func _input(event: InputEvent) -> void:
	if not active() or open_t < 0.25:
		return
	if main.state == main.State.TITLE:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
			main.try_fullscreen(event is InputEventScreenTouch)
			main.after_title()
			get_viewport().set_input_as_handled()
		return
	var btns := layout()
	if event is InputEventScreenTouch and event.pressed:
		for i in btns.size():
			var b: Dictionary = btns[i]
			if b.enabled and b.rect.has_point(event.position):
				focus = i
				activate(b.id)
				get_viewport().set_input_as_handled()
				return
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	if main.state == main.State.LOBBY:
		if event.is_action("left"):
			activate("prev")
		elif event.is_action("right"):
			activate("next")
		elif key == KEY_ENTER or key == KEY_SPACE or key == KEY_J:
			activate("play")
		elif key == KEY_1:
			activate("talent")
		elif key == KEY_2:
			activate("garage")
		return
	if key == KEY_ESCAPE or key == KEY_BACKSPACE:
		if main.state in [main.State.TALENT, main.State.GARAGE]:
			activate("back")
		return
	var enabled_idx: Array = []
	for i in btns.size():
		if btns[i].enabled:
			enabled_idx.append(i)
	if enabled_idx.is_empty():
		return
	var pos := enabled_idx.find(focus)
	if event.is_action("left") or event.is_action("up"):
		focus = enabled_idx[posmod(pos - 1, enabled_idx.size())]
	elif event.is_action("right") or event.is_action("down"):
		focus = enabled_idx[posmod(pos + 1, enabled_idx.size())]
	elif key == KEY_ENTER or key == KEY_SPACE or key == KEY_J:
		if focus < btns.size() and btns[focus].enabled:
			activate(btns[focus].id)


func activate(id: String) -> void:
	main.dlog("menu: " + id)
	main.sfx.play("pickup", -6.0, 0.8)
	match id:
		"prev":
			main.change_stage(-1)
		"next":
			main.change_stage(1)
		"play":
			main.start_run(main.selected_stage)
		"talent":
			main.set_state(main.State.TALENT)
		"garage":
			main.set_state(main.State.GARAGE)
		"voice":
			main.voice.tts_enabled = not main.voice.tts_enabled
			main.save_game()
			if main.voice.tts_enabled:
				main.voice.speak("음성을 켰어요!")
		"back", "lobby":
			main.goto_lobby()
		"charsel":
			main.set_state(main.State.CHARSELECT)
		"char_ok":
			main.goto_lobby()
		"next_stage":
			main.start_run(main.result.stage + 1)
		"retry":
			main.start_run(main.result.stage)
		_:
			if id.begins_with("char:"):
				main.choose_character(id.substr(5))
				main.voice.say("start", true)
			elif id.begins_with("buy:"):
				var r: String = main.buy_talent(id.substr(4))
				show_toast(r)
			elif id.begins_with("equip:"):
				main.equipped = id.substr(6)
				main.save_game()
				show_toast("%s 장착!" % Data.vehicle(main.equipped).name)
			elif id.begins_with("vbuy:"):
				show_toast(main.buy_vehicle(id.substr(5)))
			elif id.begins_with("vup:"):
				show_toast(main.upgrade_vehicle(id.substr(4)))


# ------------------------------------------------------------------ 그리기

func _gold(right_x: float, y: float) -> void:
	var s := "%d" % main.gold
	var w: float = hud.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	_t(Vector2(right_x, y), s, 38, COIN, HORIZONTAL_ALIGNMENT_RIGHT, 6)
	main.sprites.draw(self, "coin", Vector2(right_x - w - 22, y - 13), 0, false, 1.5)


func _draw() -> void:
	if not active():
		return
	# hud의 그리기 도우미를 쓰기 위해 hud 캔버스가 아닌 자신에게 그린다
	var v: Vector2 = main.view
	match main.state:
		main.State.TITLE:
			_draw_title(v)
		main.State.CHARSELECT:
			_draw_charselect(v)
		main.State.LOBBY:
			_draw_lobby(v)
		main.State.TALENT:
			_draw_talent(v)
		main.State.GARAGE:
			_draw_garage(v)
		main.State.RESULT:
			_draw_result(v)
	var btns := layout()
	for i in btns.size():
		var b: Dictionary = btns[i]
		match b.get("kind", "button"):
			"arrow":
				var c: Vector2 = b.rect.get_center()
				var a := 0.9 if b.enabled else 0.15
				draw_colored_polygon(PackedVector2Array([c + Vector2(b.dir * 22, 0), c + Vector2(-b.dir * 16, -30), c + Vector2(-b.dir * 16, 30)]), Color(1, 1, 1, a))
			"talent":
				_talent_card(b, i == focus)
			"char":
				_char_card(b)
			"vehicle":
				_vehicle_card(b)
			_:
				_button(b, i == focus and main.state != main.State.LOBBY)
	if toast_t > 0.0:
		_t(Vector2(v.x * 0.5, v.y - 40), toast, 32, Color(1, 1, 0.6, clamp(toast_t * 2.0, 0.0, 1.0)))


func _t(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 8) -> void:
	var font: Font = hud.font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _panel(r: Rect2, border: Color, bg := Color(0.08, 0.1, 0.09, 0.9)) -> void:
	hud.box.bg_color = bg
	hud.box.border_color = border
	hud.box.draw(get_canvas_item(), r)


func _button(b: Dictionary, focused: bool) -> void:
	var r: Rect2 = b.rect
	var col: Color = b.col if b.enabled else Color(0.3, 0.3, 0.3)
	if focused and b.enabled:
		r = r.grow(3.0 + sin(main.time * 6.0) * 2.0)
	_panel(r, Color.WHITE if focused and b.enabled else col.darkened(0.35), col)
	var size: int = b.get("size", 40)
	_t(r.get_center() + Vector2(0, size * 0.36), b.label, size, Color(1, 1, 1, 1.0 if b.enabled else 0.45), HORIZONTAL_ALIGNMENT_CENTER, 6)


func _draw_title(v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.35))
	var bob := sin(main.time * 2.5) * 8.0
	_t(Vector2(v.x * 0.5, v.y * 0.24 + bob), "공룡섬", 120, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 16)
	_t(Vector2(v.x * 0.5, v.y * 0.24 + 110 + bob), "생존기", 96, Color("ffcf4a"), HORIZONTAL_ALIGNMENT_CENTER, 14)
	main.sprites.draw(self, "shadow", Vector2(v.x * 0.5, v.y * 0.6), 0, false, 2.0)
	main.sprites.draw(self, main.player_sprite(), Vector2(v.x * 0.5, v.y * 0.6 - abs(sin(main.time * 3.0)) * 10.0), int(main.time * 3.0) % 2, false, 2.4)
	main.sprites.draw(self, "raptor", Vector2(v.x * 0.5 - 220, v.y * 0.62), int(main.time * 4.0) % 2, false, 1.6)
	main.sprites.draw(self, "compy", Vector2(v.x * 0.5 + 220, v.y * 0.62), int(main.time * 5.0) % 2, true, 1.8)
	var blink := 0.55 + sin(main.time * 5.0) * 0.45
	_t(Vector2(v.x * 0.5, v.y * 0.76), "화면을 터치해서 시작", 44, Color(1, 1, 1, blink))
	_t(Vector2(v.x * 0.5, v.y * 0.82), "드래그로 이동, 무기는 자동 공격!", 28, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 5)


const CHAR_INFO := {
	"m": {"name": "철수", "desc": "씩씩한 남자 탐험가", "col": Color("6b7d3a")},
	"f": {"name": "영희", "desc": "용감한 여자 탐험가", "col": Color("3f8f7f")},
}


func _draw_charselect(v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.45))
	_t(Vector2(v.x * 0.5, 170), "캐릭터를 선택하세요", 56, Color("ffcf4a"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_t(Vector2(v.x * 0.5, 230), "능력은 같고 모습과 목소리가 달라요", 26, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 5)


func _char_card(b: Dictionary) -> void:
	var c: String = b.c
	var info: Dictionary = CHAR_INFO[c]
	var r: Rect2 = b.rect
	var sel: bool = main.character == c
	if sel:
		r = r.grow(6.0 + sin(main.time * 6.0) * 2.0)
	_panel(r, Color("ffcf4a") if sel else info.col, Color(0.1, 0.12, 0.11, 0.92) if not sel else Color(0.16, 0.2, 0.14, 0.95))
	var cx := r.get_center().x
	var sprite := "player_f" if c == "f" else "player"
	var bob: float = abs(sin(main.time * (4.0 if sel else 2.0))) * (12.0 if sel else 4.0)
	main.sprites.draw(self, "shadow", Vector2(cx, r.position.y + 300), 0, false, 1.6)
	main.sprites.draw(self, sprite, Vector2(cx, r.position.y + 300 - bob), int(main.time * 4.0) % 2 if sel else 0, false, 2.3)
	_t(Vector2(cx, r.position.y + 380), info.name, 48, Color.WHITE)
	_t(Vector2(cx, r.position.y + 428), info.desc, 24, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 0)
	if sel:
		_t(Vector2(cx, r.position.y + 50), "선택됨", 30, Color("ffcf4a"))


func _draw_lobby(v: Vector2) -> void:
	_t(Vector2(v.x * 0.5, 150), "공룡섬 생존기", 66, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_gold(v.x - 30, 70)
	# 주인공
	var px := v.x * 0.5
	main.sprites.draw(self, "shadow", Vector2(px, 430), 0, false, 1.6)
	main.sprites.draw(self, main.player_sprite(), Vector2(px, 430 - abs(sin(main.time * 2.0)) * 6.0), 0, false, 2.0)
	var vid: String = main.equipped
	main.sprites.draw(self, vid, Vector2(px + 190, 430), 0, true, 0.9)
	_t(Vector2(px + 190, 460), Data.vehicle(vid).name, 24, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 5)
	# 스테이지 정보
	var p := _stage_panel()
	var s: int = main.selected_stage
	var info := Data.stage_info(s)
	var cleared: bool = s <= main.cleared
	_panel(p, Color("8bff6b") if cleared else Color("ffcf4a"))
	var cx := p.get_center().x
	_t(Vector2(cx, p.position.y + 72), "스테이지 %d" % s, 60, Color.WHITE)
	_t(Vector2(cx, p.position.y + 112), info.name, 30, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 4)
	var stars: int = clampi(s, 1, 5)
	for i in 5:
		_star(Vector2(cx - 80 + i * 40, p.position.y + 146), 15.0, Color("ffca28") if i < stars else Color(1, 1, 1, 0.2))
	_t(Vector2(cx, p.position.y + 200), "중간 보스: " + Data.BOSSES[info.mini].name, 28, Color("ffab91"), HORIZONTAL_ALIGNMENT_CENTER, 4)
	_t(Vector2(cx, p.position.y + 240), "최종 보스: " + Data.BOSSES[info.boss].name, 30, Color("ff8a80"), HORIZONTAL_ALIGNMENT_CENTER, 4)
	var best: float = float(main.best.get(str(s), 0.0))
	var line := "클리어 보상 %d 골드" % Data.clear_gold(s)
	if cleared:
		line = "클리어 완료!   " + line
	elif best > 0.0:
		line = "최고 생존 %02d:%02d   " % [int(best) / 60, int(best) % 60] + line
	_t(Vector2(cx, p.position.y + 290), line, 24, COIN, HORIZONTAL_ALIGNMENT_CENTER, 4)
	_t(Vector2(cx, p.position.y + 322), "적 체력 x%.1f" % Data.stage_hp_mult(s), 20, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _draw_talent(v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55))
	_t(Vector2(v.x * 0.5, 104), "영구 강화", 58, Color("ffcf4a"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_gold(v.x - 30, 92)
	_t(Vector2(v.x * 0.5, 160), "골드로 주인공을 영구적으로 강하게!", 24, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _talent_card(b: Dictionary, focused: bool) -> void:
	var tl: Dictionary = b.t
	var r: Rect2 = b.rect
	var lv: int = main.talents.get(tl.id, 0)
	var maxed: bool = lv >= tl.max
	var cost := Data.talent_cost(tl, lv)
	var afford: bool = main.gold >= cost
	var col: Color = tl.col
	_panel(r.grow(3.0 if focused else 0.0), Color.WHITE if focused else (col if afford and not maxed else col.darkened(0.5)), Color(0.1, 0.12, 0.11, 0.95))
	var cx := r.get_center().x
	_t(Vector2(cx, r.position.y + 44), tl.name, 28, col, HORIZONTAL_ALIGNMENT_CENTER, 4)
	_t(Vector2(cx, r.position.y + 88), tl.desc, 21, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 0)
	_t(Vector2(cx, r.position.y + 140), "Lv %d / %d" % [lv, tl.max], 22, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var pr := Rect2(r.position.x + 14, r.end.y - 72, r.size.x - 28, 54)
	draw_rect(pr, Color(0, 0, 0, 0.4))
	if maxed:
		_t(pr.get_center() + Vector2(0, 12), "최대", 30, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	else:
		var s := "%d" % cost
		var w: float = hud.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		main.sprites.draw(self, "coin", pr.get_center() + Vector2(-w * 0.5 - 18, 0), 0, false, 1.1)
		_t(pr.get_center() + Vector2(10, 12), s, 30, COIN if afford else Color("ff6e6e"), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _draw_garage(v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55))
	_t(Vector2(v.x * 0.5, 104), "차고", 58, Color("90caf9"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_gold(v.x - 30, 92)
	_t(Vector2(v.x * 0.5, 160), "골드로 탈것을 사고 강화하세요. 게임 중 게이지가 차면 탑승!", 22, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _vehicle_card(b: Dictionary) -> void:
	var vh: Dictionary = b.v
	var r: Rect2 = b.rect
	var unlocked: bool = main.owned_vehicles.has(vh.id)
	var equipped: bool = main.equipped == vh.id
	_panel(r, Color("ffcf4a") if equipped else (vh.col if unlocked else Color(0.3, 0.3, 0.3)), Color(0.1, 0.12, 0.11, 0.95))
	var sz: Vector2 = main.sprites.size_of(vh.id)
	var sc: float = min(170.0 / sz.x, 110.0 / sz.y)
	main.sprites.draw(self, vh.id, r.position + Vector2(110, 150), 0, false, sc, Color.WHITE if unlocked else Color(0.15, 0.15, 0.15, 0.9))
	var lv: int = main.vehicle_lv.get(vh.id, 0)
	_t(Vector2(r.position.x + 220, r.position.y + 56), vh.name, 38, vh.col.lightened(0.3) if unlocked else Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 5)
	if unlocked:
		_t(Vector2(r.position.x + 220 + hud.font.get_string_size(vh.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 16, r.position.y + 56), "Lv %d" % lv, 26, Color("ffee58"), HORIZONTAL_ALIGNMENT_LEFT, 4)
	var lines: PackedStringArray = vh.desc.split("\n")
	for j in lines.size():
		_t(Vector2(r.position.x + 220, r.position.y + 100 + j * 30), lines[j], 22, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT, 0)
	if unlocked:
		_t(Vector2(r.position.x + 220, r.position.y + 180), "탑승 %.0f초  /  위력 x%.1f" % [vh.time * (1.0 + 0.15 * lv), 1.0 + 0.2 * lv], 20, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, 0)
	else:
		var afford: bool = main.gold >= vh.price
		main.sprites.draw(self, "coin", Vector2(r.position.x + 234, r.position.y + 172), 0, false, 1.2)
		_t(Vector2(r.position.x + 254, r.position.y + 182), "%d 골드" % vh.price, 28, COIN if afford else Color("ff6e6e"), HORIZONTAL_ALIGNMENT_LEFT, 4)


func _draw_result(v: Vector2) -> void:
	var r: Dictionary = main.result
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55 * clamp(open_t * 2.0, 0.0, 1.0)))
	var p := Rect2(v.x * 0.5 - min(320.0, v.x * 0.5 - 24.0), v.y * 0.5 - 420, min(640.0, v.x - 48.0), 640)
	_panel(p, Color("ffcf4a") if r.cleared else Color("ff6e6e"))
	var cx := p.get_center().x
	var y := p.position.y + 100
	if r.cleared:
		_t(Vector2(cx, y), "스테이지 %d 클리어!" % r.stage, 60, Color("ffe082"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	else:
		_t(Vector2(cx, y), "생존 실패...", 64, Color("ff6e6e"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	y += 90
	_t(Vector2(cx, y), "생존 시간  %02d:%02d" % [int(r.time) / 60, int(r.time) % 60], 34, Color.WHITE)
	y += 56
	_t(Vector2(cx, y), "처치 %d     레벨 %d" % [r.kills, r.level], 34, Color.WHITE)
	y += 70
	_t(Vector2(cx, y), "획득 골드 +%d" % r.gold, 38, COIN)
	if r.bonus > 0:
		y += 44
		_t(Vector2(cx, y), "(클리어 보너스 %d 포함)" % r.bonus, 24, COIN, HORIZONTAL_ALIGNMENT_CENTER, 0)
	if r.unlock != "":
		y += 60
		_t(Vector2(cx, y), "새 탈것 해금: " + r.unlock + "!", 34, Color("8bff6b"))
	if not r.cleared:
		y += 60
		_t(Vector2(cx, y), "강화와 차고에서 더 강해지세요!", 24, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 0)
	_gold(p.end.x - 24, p.end.y - 24)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
