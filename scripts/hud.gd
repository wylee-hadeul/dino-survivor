extends Node2D
## 게임 중 화면: 경험치바, 시간, 처치/골드, 무기 슬롯, 보스 체력, 말풍선, 탑승 버튼, 레벨업 카드, 일시정지.

const Data = preload("res://scripts/data.gd")

var main
var font: Font
var box := StyleBoxFlat.new()
var banner := ""
var banner_sub := ""
var banner_t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	box.set_corner_radius_all(20)
	box.set_border_width_all(4)
	box.shadow_size = 10
	box.shadow_color = Color(0, 0, 0, 0.4)


func show_banner(a: String, b: String) -> void:
	banner = a
	banner_sub = b
	banner_t = 2.6


func _process(delta: float) -> void:
	banner_t -= delta
	queue_redraw()


func text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 8) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func panel(r: Rect2, border: Color, bg := Color(0.08, 0.1, 0.09, 0.92)) -> void:
	box.bg_color = bg
	box.border_color = border
	box.draw(get_canvas_item(), r)


# ------------------------------------------------------------------ 버튼 위치 (입력 판정과 공유)

func ride_center() -> Vector2:
	var v: Vector2 = main.view
	return Vector2(v.x - 100.0, v.y - 190.0)


func pause_rect() -> Rect2:
	return Rect2(main.view.x - 84.0, 36.0, 64.0, 60.0)


func button_at(p: Vector2) -> String:
	if p.distance_to(ride_center()) < 80.0:
		return "ride"
	if pause_rect().grow(10).has_point(p):
		return "pause"
	return ""


func card_rects(n: int) -> Array:
	var v: Vector2 = main.view
	var out: Array = []
	if v.y >= v.x:
		var w: float = min(640.0, v.x - 60.0)
		var h := 170.0
		var gap := 22.0
		var total := n * h + (n - 1) * gap
		var y0 := v.y * 0.56 - total * 0.5
		for i in n:
			out.append(Rect2(v.x * 0.5 - w * 0.5, y0 + i * (h + gap), w, h))
	else:
		var w := 300.0
		var h := 400.0
		var gap := 30.0
		var total := n * w + (n - 1) * gap
		for i in n:
			out.append(Rect2(v.x * 0.5 - total * 0.5 + i * (w + gap), v.y * 0.55 - h * 0.5, w, h))
	return out


func pause_buttons() -> Array:
	var v: Vector2 = main.view
	return [
		{"id": "resume", "rect": Rect2(v.x * 0.5 - 200, v.y * 0.5 - 40, 400, 110), "label": "계속하기", "col": Color("43a047")},
		{"id": "quit", "rect": Rect2(v.x * 0.5 - 200, v.y * 0.5 + 100, 400, 110), "label": "포기하기", "col": Color("c62828")},
	]


# ------------------------------------------------------------------ 그리기

func _draw() -> void:
	if not main.state in [main.State.PLAYING, main.State.LEVELUP, main.State.PAUSE]:
		return
	var v: Vector2 = main.view
	var run = main.run
	var pl = run.player
	var sp = main.sprites
	# 경험치
	draw_rect(Rect2(0, 0, v.x, 24), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(0, 0, v.x * pl.xp / pl.xp_need(), 24), Color("29b6f6"))
	text(Vector2(12, 20), "Lv %d" % pl.level, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
	# 시간
	var tt: float = min(run.t, Data.STAGE_TIME)
	var tstr := "%02d:%02d" % [int(tt) / 60, int(tt) % 60]
	if run.final_spawned:
		tstr = "보스전!"
	text(Vector2(v.x * 0.5, 78), tstr, 46, Color.WHITE)
	text(Vector2(v.x * 0.5, 104), "스테이지 %d  %s" % [run.stage, Data.stage_info(run.stage).name], 20, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 4)
	text(Vector2(20, 72), "처치 %d" % run.kills, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6)
	sp.draw(self, "coin", Vector2(30, 96), 0, false, 1.0)
	text(Vector2(46, 106), "%d" % run.run_gold, 26, Color("ffd54f"), HORIZONTAL_ALIGNMENT_LEFT, 6)
	# 무기/패시브 슬롯
	var x := 20.0
	for w in pl.weapons:
		draw_rect(Rect2(x - 2, 124, 52, 52), Color(0, 0, 0, 0.45))
		sp.draw(self, "i_" + w.id, Vector2(x + 24, 150), 0, false, 0.72)
		text(Vector2(x + 46, 174), str(w.lv) if w.lv < 5 else "M", 18, Color("ffee58") if w.lv >= 5 else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 4)
		x += 58.0
	x = 20.0
	for id in pl.passives:
		draw_rect(Rect2(x - 2, 182, 40, 40), Color(0, 0, 0, 0.35))
		sp.draw(self, "i_" + id, Vector2(x + 18, 202), 0, false, 0.52)
		text(Vector2(x + 36, 220), str(pl.passives[id]), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		x += 46.0
	# 일시정지 버튼
	var pr := pause_rect()
	draw_rect(pr, Color(0, 0, 0, 0.4))
	draw_rect(Rect2(pr.position + Vector2(20, 14), Vector2(8, 32)), Color.WHITE)
	draw_rect(Rect2(pr.position + Vector2(36, 14), Vector2(8, 32)), Color.WHITE)
	# 보스 체력
	var b = run.enemies.boss_alive
	if b:
		var bw: float = min(560.0, v.x - 80.0)
		var br := Rect2(v.x * 0.5 - bw * 0.5, 252, bw, 22)
		text(Vector2(v.x * 0.5, 244), Data.BOSSES[b.boss_id].name, 26, Color("ff8a80"))
		draw_rect(br.grow(3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(br.position, Vector2(br.size.x * b.hp / b.max_hp, br.size.y)), Color("e53935") if b.hp > b.max_hp * 0.5 else Color("ff6d00"))
	# 말풍선
	var voice = main.voice
	if voice.bubble_t > 0.0 and not pl.dead:
		var sp_pos: Vector2 = get_viewport().canvas_transform * (pl.pos + Vector2(0, -110 if pl.vehicle == "" else -170))
		var fs := 24
		var tw := font.get_string_size(voice.bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(sp_pos.x - tw * 0.5 - 16, sp_pos.y - 50, tw + 32, 46)
		r.position.x = clamp(r.position.x, 8.0, v.x - r.size.x - 8.0)
		var a: float = clamp(voice.bubble_t * 2.0, 0.0, 1.0)
		box.bg_color = Color(1, 1, 1, 0.95 * a)
		box.border_color = Color(0.1, 0.1, 0.1, a)
		box.shadow_size = 0
		box.draw(get_canvas_item(), r)
		box.shadow_size = 10
		draw_colored_polygon(PackedVector2Array([Vector2(sp_pos.x - 10, r.end.y - 2), Vector2(sp_pos.x + 10, r.end.y - 2), Vector2(sp_pos.x, r.end.y + 14)]), Color(1, 1, 1, 0.95 * a))
		draw_string(font, Vector2(r.position.x + 16, r.position.y + 32), voice.bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.1, 0.1, a))
	# 탑승 버튼
	_ride_button(pl, sp)
	# 배너
	if banner_t > 0.0:
		var a: float = clamp(banner_t * 2.0, 0.0, 1.0)
		var pop: float = 1.0 + max(0.0, banner_t - 2.4) * 2.0
		text(Vector2(v.x * 0.5, v.y * 0.3), banner, int(58 * pop), Color(1, 0.85, 0.3, a), HORIZONTAL_ALIGNMENT_CENTER, 12)
		if banner_sub != "":
			text(Vector2(v.x * 0.5, v.y * 0.3 + 56), banner_sub, 40, Color(1, 0.5, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, 10)
	if main.state == main.State.LEVELUP:
		_draw_levelup(v, sp)
	elif main.state == main.State.PAUSE:
		draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6))
		text(Vector2(v.x * 0.5, v.y * 0.5 - 120), "일시 정지", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
		for bt in pause_buttons():
			button(bt.rect, bt.label, bt.col)


func button(r: Rect2, label: String, col: Color, enabled := true, size := 38) -> void:
	box.bg_color = col if enabled else Color(0.3, 0.3, 0.3)
	box.border_color = col.darkened(0.35)
	box.draw(get_canvas_item(), r)
	text(r.get_center() + Vector2(0, size * 0.36), label, size, Color(1, 1, 1, 1.0 if enabled else 0.45), HORIZONTAL_ALIGNMENT_CENTER, 6)


func _ride_button(pl, sp) -> void:
	var c := ride_center()
	var v := Data.vehicle(pl.vehicle_id)
	var ready: bool = pl.can_ride()
	var t: float = main.time
	draw_circle(c, 66.0, Color(0, 0, 0, 0.45))
	if ready:
		draw_circle(c, 70.0 + sin(t * 8.0) * 5.0, Color(1, 0.7, 0.2, 0.35))
	var sz: Vector2 = sp.size_of(pl.vehicle_id)
	var sc: float = min(100.0 / sz.x, 70.0 / sz.y)
	sp.draw(self, pl.vehicle_id, c + Vector2(0, sz.y * sc * 0.45), 0, false, sc, Color.WHITE if (ready or pl.vehicle != "") else Color(1, 1, 1, 0.5))
	var frac: float = pl.ride_gauge
	var col := Color("ffb74d")
	if pl.vehicle != "":
		frac = pl.vehicle_t / pl.vehicle_max_t
		col = Color("4fc3f7")
	draw_arc(c, 66.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, col, 8.0)
	if ready:
		text(c + Vector2(0, 100), "탑승!", 30, Color(1, 0.85, 0.3))
	elif pl.vehicle == "":
		text(c + Vector2(0, 100), v.name, 22, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 5)


func _draw_levelup(v: Vector2, sp) -> void:
	var a: float = clamp(main.levelup_t * 4.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.65 * a))
	var title := "레벨 업!" if not main.levelup_chest else "보급 상자!"
	text(Vector2(v.x * 0.5, card_rects(main.choices.size())[0].position.y - 50), title, 64, Color(1, 0.9, 0.35, a), HORIZONTAL_ALIGNMENT_CENTER, 12)
	var rects := card_rects(main.choices.size())
	var portrait: bool = v.y >= v.x
	for i in rects.size():
		var c: Dictionary = main.choices[i]
		var k: float = clamp(main.levelup_t * 4.0 - i * 0.3, 0.0, 1.0)
		if k <= 0.0:
			continue
		var r: Rect2 = rects[i]
		r.position.x += (1.0 - k) * 80.0
		var sel: bool = i == main.choice_sel
		panel(r.grow(4.0 if sel else 0.0), Color.WHITE if sel else c.col, Color(0.1, 0.12, 0.11, 0.96))
		var nxt: int = c.lv + 1
		var lvtxt := "신규!" if c.lv == 0 else "Lv %d > %d" % [c.lv, nxt]
		if c.type == "heal" or c.type == "gold":
			lvtxt = ""
		if portrait:
			var ic := r.position + Vector2(85, r.size.y * 0.5)
			draw_circle(ic, 58.0, Color(c.col, 0.25))
			sp.draw(self, c.icon, ic, 0, false, 1.4)
			text(Vector2(r.position.x + 170, r.position.y + 58), c.name, 36, c.col, HORIZONTAL_ALIGNMENT_LEFT, 5)
			text(Vector2(r.end.x - 24, r.position.y + 56), lvtxt, 26, Color("ffee58"), HORIZONTAL_ALIGNMENT_RIGHT, 4)
			text(Vector2(r.position.x + 170, r.position.y + 112), c.desc, 26, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 0)
			if c.type == "weapon":
				text(Vector2(r.position.x + 170, r.position.y + 148), "무기", 18, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_LEFT, 0)
			elif c.type == "passive":
				text(Vector2(r.position.x + 170, r.position.y + 148), "패시브", 18, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_LEFT, 0)
		else:
			var ic := r.position + Vector2(r.size.x * 0.5, 100)
			draw_circle(ic, 62.0, Color(c.col, 0.25))
			sp.draw(self, c.icon, ic, 0, false, 1.5)
			text(Vector2(r.get_center().x, r.position.y + 210), c.name, 34, c.col)
			text(Vector2(r.get_center().x, r.position.y + 250), lvtxt, 24, Color("ffee58"))
			text(Vector2(r.get_center().x, r.position.y + 300), c.desc, 22, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 0)
