extends Node2D
## 떨어진 아이템: 경험치 보석(파랑1/초록5/빨강25), 골드, 고기(회복), 보급 상자, 자석.

const MAX_GEMS := 350


class Item:
	var kind := "gem"
	var pos := Vector2.ZERO
	var value := 1
	var frame := 0
	var pulled := false
	var speed := 0.0
	var t := 0.0
	var dead := false


var run
var items: Array = []
var gem_count := 0


func clear() -> void:
	items.clear()
	gem_count = 0


func drop(kind: String, pos: Vector2, value := 1) -> void:
	var it := Item.new()
	it.kind = kind
	it.pos = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	it.value = value
	it.t = randf() * 6.0
	if kind == "gem":
		it.frame = 2 if value >= 25 else (1 if value >= 5 else 0)
		gem_count += 1
		if gem_count > MAX_GEMS:
			_merge_far()
	items.append(it)


## 보석이 너무 많으면 멀리 있는 것들을 빨간 보석 하나로 합친다.
func _merge_far() -> void:
	var total := 0
	var p: Vector2 = run.player.pos
	var far_pos := Vector2.ZERO
	for it in items:
		if it.kind == "gem" and not it.pulled and it.pos.distance_to(p) > 500.0 and total < 400:
			total += it.value
			it.dead = true
			gem_count -= 1
			far_pos = it.pos
	if total > 0:
		var big := Item.new()
		big.kind = "gem"
		big.pos = far_pos
		big.value = total
		big.frame = 2
		items.append(big)
		gem_count += 1


func pull_all() -> void:
	for it in items:
		if it.kind == "gem":
			it.pulled = true


func update(delta: float) -> void:
	var pl = run.player
	var p: Vector2 = pl.pos + Vector2(0, -20)
	var mag: float = pl.magnet_range()
	for it in items:
		if it.dead:
			continue
		it.t += delta
		var d: Vector2 = p - it.pos
		var dist: float = d.length()
		if not it.pulled and dist < mag and it.kind != "chest":
			it.pulled = true
		if it.kind == "chest" and dist < 60.0:
			it.pulled = true
		elif not it.pulled and it.kind == "gem" and dist < mag * 2.5:
			it.pos += d / max(dist, 0.001) * 70.0 * delta  # 주변 보석은 천천히 끌려온다
		if it.pulled:
			it.speed = min(it.speed + 1400.0 * delta, 900.0)
			it.pos += d / max(dist, 0.001) * min(it.speed * delta, dist)
			if dist < 24.0:
				it.dead = true
				_collect(it)
	var i := 0
	while i < items.size():
		if items[i].dead:
			items[i] = items[-1]
			items.pop_back()
		else:
			i += 1
	queue_redraw()


func _collect(it: Item) -> void:
	match it.kind:
		"gem":
			gem_count -= 1
			run.player.add_xp(it.value)
			run.sfx.play("pickup", -16.0, 1.0 + min(it.value, 25) * 0.02)
		"coin":
			run.add_gold(it.value)
			run.sfx.play("coin", -10.0)
		"meat":
			run.player.heal(30.0)
			run.fx.text(run.player.pos + Vector2(0, -90), "+30", Color("66bb6a"))
			run.sfx.play("levelup", -12.0, 1.5)
		"magnet":
			pull_all()
			run.sfx.play("levelup", -10.0, 1.2)
		"chest":
			run.open_chest()


func _draw() -> void:
	var sp = run.sprites
	var cam: Rect2 = run.visible_rect().grow(60)
	for it in items:
		if not cam.has_point(it.pos):
			continue
		var bob := sin(it.t * 4.0) * 3.0
		match it.kind:
			"gem":
				sp.draw(self, "gem", it.pos + Vector2(0, bob), it.frame, false, 1.0 if it.frame < 2 else 1.3)
			"chest":
				sp.draw(self, "shadow", it.pos + Vector2(0, 14), 0, false, 0.8)
				sp.draw(self, "chest", it.pos + Vector2(0, bob), 0, false, 1.3)
				draw_arc(it.pos, 36.0 + sin(it.t * 5.0) * 4.0, 0.0, TAU, 32, Color(1, 0.85, 0.3, 0.6), 3.0)
			_:
				sp.draw(self, it.kind, it.pos + Vector2(0, bob))
