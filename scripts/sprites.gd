extends Node
## 시작할 때 Art의 절차적 그림을 SubViewport로 한 장의 아틀라스에 굽는다.
## 게임 중에는 draw_texture_rect_region 한 번으로 그려서 수백 마리 공룡도 가볍게 그린다.

const Art = preload("res://scripts/art.gd")

const ATLAS := 2048
const PAD := 4

## [이름, 폭, 높이, 앵커("foot"=발밑 / "center"), 프레임 수, 좌우반전본 생성]
const SPECS := [
	["player", 84, 104, "foot", 2, true],
	["compy", 76, 56, "foot", 2, true],
	["raptor", 116, 84, "foot", 2, true],
	["dilo", 104, 94, "foot", 2, true],
	["trike", 140, 100, "foot", 2, true],
	["ptero", 124, 84, "foot", 2, true],
	["ankylo", 140, 72, "foot", 2, true],
	["pachy", 104, 96, "foot", 2, true],
	["stego", 170, 130, "foot", 2, true],
	["trex", 232, 200, "foot", 2, true],
	["giga", 240, 200, "foot", 2, true],
	["spino", 260, 200, "foot", 2, true],
	["brachio", 260, 274, "foot", 2, true],
	["jeep", 156, 80, "foot", 1, true],
	["tank", 170, 84, "foot", 1, true],
	["ship", 190, 106, "foot", 1, true],
	["plane", 190, 90, "foot", 1, true],
	["tank_turret", 150, 64, "center", 1, false],
	["crown", 42, 30, "center", 1, false],
	["gem", 26, 30, "center", 3, false],
	["coin", 26, 26, "center", 1, false],
	["meat", 40, 32, "center", 1, false],
	["chest", 50, 40, "center", 1, false],
	["magnet", 36, 30, "center", 1, false],
	["shadow", 66, 24, "center", 1, false],
	["bullet", 20, 12, "center", 1, false],
	["pellet", 14, 14, "center", 1, false],
	["grenade", 22, 24, "center", 1, false],
	["saw", 46, 46, "center", 1, false],
	["mine", 32, 32, "center", 1, false],
	["spit", 24, 24, "center", 1, false],
	["rock", 34, 32, "center", 1, false],
	["missile", 34, 16, "center", 1, false],
	["bomb", 32, 26, "center", 1, false],
	["shell", 22, 20, "center", 1, false],
]
const ICONS := ["pistol", "shotgun", "grenade", "saw", "flame", "lightning", "laser", "mine",
	"might", "vital", "boots", "haste", "magnet", "armor", "wisdom", "heal", "gold"]

var texture: Texture2D
var regions := {}   # 이름 -> Array[Rect2] (frame*2 + mirror)
var anchors := {}   # 이름 -> Vector2
var baked := false


class Painter extends Node2D:
	var jobs: Array = []
	var owner_sprites

	func _draw() -> void:
		for j in jobs:
			draw_set_transform(j[1], 0.0, Vector2(-1.0 if j[2] else 1.0, 1.0))
			owner_sprites.paint(self, j[0], j[3])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func bake() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(ATLAS, ATLAS)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Painter.new()
	painter.owner_sprites = self
	vp.add_child(painter)
	var x := PAD
	var y := PAD
	var row_h := 0
	var all: Array = SPECS.duplicate()
	for id in ICONS:
		all.append(["i_" + id, 64, 64, "center", 1, false])
	for sp in all:
		var name: String = sp[0]
		var w: int = sp[1]
		var h: int = sp[2]
		var anchor := Vector2(w * 0.5, h - 4.0) if sp[3] == "foot" else Vector2(w * 0.5, h * 0.5)
		anchors[name] = anchor
		var list: Array = []
		for f in sp[4]:
			for m in 2:
				if m == 1 and not sp[5]:
					list.append(list[-1])  # 반전본이 없으면 원본을 재사용
					continue
				if x + w + PAD > ATLAS:
					x = PAD
					y += row_h + PAD
					row_h = 0
				var r := Rect2(x, y, w, h)
				list.append(r)
				painter.jobs.append([name, r.position + anchor, m == 1, f])
				x += w + PAD
				row_h = max(row_h, h)
		regions[name] = list
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	texture = ImageTexture.create_from_image(img)
	vp.queue_free()
	baked = true


func paint(c: CanvasItem, name: String, frame: int) -> void:
	if name.begins_with("i_"):
		Art.icon(c, name.substr(2))
		return
	match name:
		"player": Art.player(c, frame)
		"compy": Art.compy(c, frame)
		"raptor": Art.raptor(c, frame)
		"dilo": Art.dilo(c, frame)
		"trike": Art.trike(c, frame)
		"ptero": Art.ptero(c, frame)
		"ankylo": Art.ankylo(c, frame)
		"pachy": Art.pachy(c, frame)
		"stego": Art.stego(c, frame)
		"trex": Art.trex(c, frame)
		"giga": Art.giga(c, frame)
		"spino": Art.spino(c, frame)
		"brachio": Art.brachio(c, frame)
		"jeep": Art.jeep(c, frame)
		"tank": Art.tank(c, frame)
		"ship": Art.ship(c, frame)
		"plane": Art.plane(c, frame)
		"tank_turret": Art.tank_turret(c, frame)
		"crown": Art.crown(c, frame)
		"gem": Art.gem(c, frame)
		"coin": Art.coin(c, frame)
		"meat": Art.meat(c, frame)
		"chest": Art.chest(c, frame)
		"magnet": Art.magnet(c, frame)
		"shadow": Art.shadow(c, frame)
		"bullet": Art.bullet(c, frame)
		"pellet": Art.pellet(c, frame)
		"grenade": Art.grenade(c, frame)
		"saw": Art.saw(c, frame)
		"mine": Art.mine(c, frame)
		"spit": Art.spit(c, frame)
		"rock": Art.rock(c, frame)
		"missile": Art.missile(c, frame)
		"bomb": Art.bomb(c, frame)
		"shell": Art.shell(c, frame)


## 발밑(또는 중심)이 pos에 오도록 그린다.
func draw(ci: CanvasItem, name: String, pos: Vector2, frame := 0, mirror := false, scale := 1.0, mod := Color.WHITE) -> void:
	var r: Rect2 = regions[name][frame * 2 + (1 if mirror else 0)]
	var a: Vector2 = anchors[name] * scale
	ci.draw_texture_rect_region(texture, Rect2(pos - a, r.size * scale), r, mod)


## 회전해서 그린다 (투사체, 포탑).
func draw_rot(ci: CanvasItem, name: String, pos: Vector2, angle: float, scale := 1.0, mod := Color.WHITE, frame := 0) -> void:
	var r: Rect2 = regions[name][frame * 2]
	ci.draw_set_transform(pos, angle, Vector2(scale, scale))
	ci.draw_texture_rect_region(texture, Rect2(-anchors[name], r.size), r, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func size_of(name: String) -> Vector2:
	return regions[name][0].size
