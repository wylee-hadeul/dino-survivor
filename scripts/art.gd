extends RefCounted
## 절차적 스프라이트 드로잉. 시작할 때 한 번 아틀라스로 구워서(Sprites) 게임 중엔 텍스처로만 그린다.
## 좌표: 생물/탈것은 발밑 중앙이 원점(위쪽이 -y), 아이템/투사체/아이콘은 중심이 원점. 모두 오른쪽을 본다.

const OL := Color("1d1a14")


static func poly(c: CanvasItem, pts: PackedVector2Array, fill: Color, w := 3.0) -> void:
	c.draw_colored_polygon(pts, fill)
	if w > 0.0:
		var cl := pts.duplicate()
		cl.append(pts[0])
		c.draw_polyline(cl, OL, w, true)


static func ell(center: Vector2, r: Vector2, rot := 0.0, seg := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


static func circ(c: CanvasItem, p: Vector2, r: float, fill: Color, w := 3.0) -> void:
	if w > 0.0:
		c.draw_circle(p, r + w * 0.5, OL)
	c.draw_circle(p, r, fill)


static func limb(c: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	c.draw_line(a, b, OL, width + 5.0)
	c.draw_circle(a, (width + 5.0) * 0.5, OL)
	c.draw_circle(b, (width + 5.0) * 0.5, OL)
	c.draw_line(a, b, col, width)
	c.draw_circle(a, width * 0.5, col)
	c.draw_circle(b, width * 0.5, col)


static func eye(c: CanvasItem, p: Vector2, r: float, angry := true) -> void:
	c.draw_circle(p, r + 1.5, OL)
	c.draw_circle(p, r, Color.WHITE)
	c.draw_circle(p + Vector2(r * 0.3, 0), r * 0.55, Color.BLACK)
	if angry:
		c.draw_line(p + Vector2(-r * 1.3, -r * 1.5), p + Vector2(r * 1.3, -r * 0.8), OL, 3.0)


static func teeth(c: CanvasItem, x0: float, x1: float, y: float, n: int, down := true, size := 5.0) -> void:
	for i in n:
		var x := x0 + (x1 - x0) * i / float(max(n - 1, 1))
		var d := size if down else -size
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - size * 0.5, y), Vector2(x + size * 0.5, y), Vector2(x, y + d)]), Color("fffbe8"))


## 두 다리 걷기 (frame 0/1)
static func legs2(c: CanvasItem, hip_a: Vector2, hip_b: Vector2, _len: float, frame: int, col: Color, dark: Color, w: float) -> void:
	var s := 1.0 if frame == 0 else -1.0
	var fa := Vector2(hip_a.x + 8.0 * s, 0)
	var fb := Vector2(hip_b.x - 8.0 * s, 0)
	limb(c, hip_b, fb + Vector2(0, -3), w, dark)
	limb(c, hip_a, fa + Vector2(0, -3), w, col)
	poly(c, PackedVector2Array([fa + Vector2(-6, -5), fa + Vector2(10, -5), fa + Vector2(12, 1), fa + Vector2(-6, 1)]), col, 2.5)


## 네 다리 걷기
static func legs4(c: CanvasItem, xs: Array, top: float, frame: int, col: Color, dark: Color, w: float) -> void:
	for i in xs.size():
		var x: float = xs[i]
		var phase := (1.0 if (i + frame) % 2 == 0 else -1.0) * 6.0
		var cc := dark if i % 2 == 1 else col
		limb(c, Vector2(x, top), Vector2(x + phase, -4), w, cc)


# ================================================================== 플레이어

static func player_f(c: CanvasItem, frame: int) -> void:
	player(c, frame, true)


## female: 여자 탐험가 (긴 머리 + 포니테일, 청록 조끼)
static func player(c: CanvasItem, frame: int, female := false) -> void:
	var skin := Color("f5cba7")
	var vest := Color("3f8f7f") if female else Color("6b7d3a")
	var pants := Color("6d5a44") if female else Color("8d7a55")
	var hair := Color("5a3825")
	if female:
		# 뒤로 늘어진 머리 + 포니테일
		poly(c, PackedVector2Array([Vector2(-18, -80), Vector2(-24, -60), Vector2(-20, -46), Vector2(-6, -50), Vector2(-4, -76)]), hair)
		poly(c, PackedVector2Array([Vector2(-16, -84), Vector2(-38, -78), Vector2(-44, -60), Vector2(-34, -52), Vector2(-30, -66), Vector2(-14, -74)]), hair)
		c.draw_circle(Vector2(-16, -80), 4.0, Color("e57373"))
	# 배낭
	poly(c, PackedVector2Array([Vector2(-24, -54), Vector2(-10, -56), Vector2(-10, -28), Vector2(-24, -30)]), Color("7a5a3a"))
	# 다리
	var s := 1.0 if frame == 0 else -1.0
	limb(c, Vector2(-5, -24), Vector2(-5 - 7 * s, -4), 9.0, pants.darkened(0.2))
	limb(c, Vector2(5, -24), Vector2(5 + 7 * s, -4), 9.0, pants)
	for fx in [-5 - 7 * s, 5 + 7 * s]:
		poly(c, PackedVector2Array([Vector2(fx - 6, -6), Vector2(fx + 9, -6), Vector2(fx + 9, 1), Vector2(fx - 6, 1)]), Color("4e3b2a"), 2.0)
	# 몸통
	poly(c, PackedVector2Array([Vector2(-14, -52), Vector2(14, -52), Vector2(16, -22), Vector2(-16, -22)]), vest)
	c.draw_line(Vector2(-8, -52), Vector2(6, -24), vest.darkened(0.3), 4.0)
	c.draw_rect(Rect2(-16, -28, 32, 5), Color("5a4630"))
	# 총 + 팔
	poly(c, PackedVector2Array([Vector2(4, -44), Vector2(36, -44), Vector2(36, -38), Vector2(16, -38), Vector2(14, -32), Vector2(6, -32)]), Color("37474f"), 2.5)
	limb(c, Vector2(-2, -46), Vector2(10, -36), 7.0, skin)
	# 머리
	circ(c, Vector2(2, -70), 20.0, skin)
	c.draw_circle(Vector2(12, -64), 4.0, Color(1, 0.5, 0.5, 0.5))
	c.draw_circle(Vector2(10, -70), 3.0, OL)
	if female:
		# 앞머리, 속눈썹, 입술
		poly(c, PackedVector2Array([Vector2(-16, -78), Vector2(20, -78), Vector2(14, -72), Vector2(4, -74), Vector2(-6, -70), Vector2(-14, -66)]), hair, 2.0)
		c.draw_line(Vector2(8, -73), Vector2(15, -75), OL, 2.0)
		c.draw_circle(Vector2(15, -61), 2.2, Color("e57373"))
	else:
		c.draw_line(Vector2(6, -77), Vector2(14, -76), OL, 2.5)
		c.draw_line(Vector2(12, -61), Vector2(17, -62), OL, 2.0)
	# 탐험모
	poly(c, PackedVector2Array([Vector2(-20, -76), Vector2(-14, -92), Vector2(2, -97), Vector2(18, -92), Vector2(24, -76)]), Color("d8c08a"))
	poly(c, PackedVector2Array([Vector2(-26, -76), Vector2(30, -76), Vector2(30, -72), Vector2(-26, -72)]), Color("c2a66c"), 2.5)
	c.draw_line(Vector2(-18, -80), Vector2(22, -80), Color("8d6e3f"), 3.0)


# ================================================================== 공룡

static func compy(c: CanvasItem, frame: int) -> void:
	var col := Color("9ccc65")
	var dark := Color("689f38")
	poly(c, PackedVector2Array([Vector2(-6, -26), Vector2(-34, -30), Vector2(-30, -24), Vector2(-6, -18)]), col)
	legs2(c, Vector2(2, -18), Vector2(-4, -18), 18.0, frame, col, dark, 4.0)
	poly(c, ell(Vector2(0, -24), Vector2(14, 9), -0.2), col)
	limb(c, Vector2(8, -28), Vector2(14, -38), 6.0, col)
	poly(c, ell(Vector2(20, -40), Vector2(10, 6), 0.1), col)
	eye(c, Vector2(22, -42), 2.5)
	c.draw_line(Vector2(-2, -31), Vector2(-10, -30), dark, 2.0)


static func raptor(c: CanvasItem, frame: int) -> void:
	var col := Color("d4874a")
	var dark := Color("9a5a2c")
	var belly := Color("f0d0a0")
	poly(c, PackedVector2Array([Vector2(-10, -40), Vector2(-50, -48), Vector2(-56, -44), Vector2(-48, -40), Vector2(-10, -30)]), col)
	legs2(c, Vector2(4, -30), Vector2(-6, -30), 28.0, frame, col, dark, 7.0)
	poly(c, ell(Vector2(0, -38), Vector2(22, 13), -0.25), col)
	c.draw_colored_polygon(ell(Vector2(4, -33), Vector2(13, 7), -0.25), belly)
	for i in 3:
		c.draw_line(Vector2(-12 + i * 8, -48), Vector2(-8 + i * 8, -40), dark, 3.0)
	limb(c, Vector2(14, -44), Vector2(22, -56), 9.0, col)
	poly(c, PackedVector2Array([Vector2(16, -62), Vector2(40, -62), Vector2(46, -56), Vector2(40, -52), Vector2(20, -50), Vector2(14, -56)]), col)
	teeth(c, 24.0, 42.0, -52.0, 4)
	eye(c, Vector2(28, -59), 3.0)
	limb(c, Vector2(16, -40), Vector2(24, -34), 4.0, dark)
	poly(c, PackedVector2Array([Vector2(12, -64), Vector2(18, -70), Vector2(22, -63)]), Color("e65100"), 2.0)


static func dilo(c: CanvasItem, frame: int) -> void:
	var col := Color("7cb342")
	var dark := Color("4e7d23")
	poly(c, PackedVector2Array([Vector2(-10, -42), Vector2(-50, -46), Vector2(-46, -40), Vector2(-10, -32)]), col)
	legs2(c, Vector2(4, -32), Vector2(-6, -32), 30.0, frame, col, dark, 7.0)
	poly(c, ell(Vector2(0, -40), Vector2(20, 13), -0.3), col)
	limb(c, Vector2(12, -48), Vector2(20, -62), 9.0, col)
	# 펼쳐진 목 주름
	var frill := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0 + PI * 0.5
		var r := 20.0 if i % 2 == 0 else 15.0
		frill.append(Vector2(16, -64) + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * r)
	poly(c, frill, Color("fdd835"), 2.5)
	poly(c, PackedVector2Array([Vector2(14, -70), Vector2(38, -68), Vector2(42, -62), Vector2(16, -58)]), col)
	poly(c, PackedVector2Array([Vector2(16, -70), Vector2(22, -82), Vector2(28, -70)]), Color("e53935"), 2.0)
	poly(c, PackedVector2Array([Vector2(24, -70), Vector2(30, -80), Vector2(34, -69)]), Color("e53935"), 2.0)
	eye(c, Vector2(28, -66), 2.8)


static func trike(c: CanvasItem, frame: int) -> void:
	var col := Color("8d8f5a")
	var dark := Color("62643a")
	poly(c, PackedVector2Array([Vector2(-30, -42), Vector2(-58, -30), Vector2(-30, -28)]), col)
	legs4(c, [-24.0, -12.0, 18.0, 30.0], -30.0, frame, col, dark, 11.0)
	poly(c, ell(Vector2(-2, -42), Vector2(36, 20)), col)
	c.draw_colored_polygon(ell(Vector2(0, -32), Vector2(26, 8)), col.lightened(0.15))
	# 프릴 + 머리
	poly(c, ell(Vector2(34, -58), Vector2(18, 24), -0.2), Color("b5654d"))
	for i in 5:
		var a := -2.4 + i * 0.5
		c.draw_circle(Vector2(34, -58) + Vector2(cos(a), sin(a)) * 20.0, 3.0, Color("f5e6c8"))
	poly(c, PackedVector2Array([Vector2(30, -54), Vector2(56, -50), Vector2(62, -40), Vector2(52, -34), Vector2(32, -36)]), col)
	poly(c, PackedVector2Array([Vector2(40, -54), Vector2(58, -70), Vector2(46, -52)]), Color("f5e6c8"), 2.0)
	poly(c, PackedVector2Array([Vector2(48, -52), Vector2(66, -64), Vector2(54, -50)]), Color("f5e6c8"), 2.0)
	poly(c, PackedVector2Array([Vector2(58, -46), Vector2(66, -52), Vector2(62, -42)]), Color("f5e6c8"), 2.0)
	eye(c, Vector2(44, -46), 3.0)


static func ptero(c: CanvasItem, frame: int) -> void:
	var col := Color("a1887f")
	var wing := Color("8d6e63")
	var up := frame == 0
	var wy := -40.0 if up else 10.0
	# 날개 (뒤)
	poly(c, PackedVector2Array([Vector2(-4, -36), Vector2(-40, -36 + wy * 0.7), Vector2(-56, -30 + wy), Vector2(-10, -28)]), wing.darkened(0.2))
	# 몸
	poly(c, ell(Vector2(0, -32), Vector2(16, 8), -0.1), col)
	poly(c, PackedVector2Array([Vector2(12, -40), Vector2(36, -40), Vector2(52, -36), Vector2(36, -34), Vector2(14, -32)]), col)
	poly(c, PackedVector2Array([Vector2(10, -40), Vector2(0, -54), Vector2(18, -42)]), Color("e57373"), 2.0)
	eye(c, Vector2(22, -39), 2.5)
	# 날개 (앞)
	poly(c, PackedVector2Array([Vector2(4, -34), Vector2(40, -36 + wy * 0.7), Vector2(58, -28 + wy), Vector2(10, -26)]), wing)


static func ankylo(c: CanvasItem, frame: int) -> void:
	var col := Color("8d7b5d")
	var dark := Color("5d4f38")
	# 곤봉 꼬리
	limb(c, Vector2(-30, -26), Vector2(-56, -22), 8.0, col)
	poly(c, ell(Vector2(-60, -22), Vector2(10, 8)), dark)
	legs4(c, [-22.0, -10.0, 16.0, 28.0], -22.0, frame, col, dark, 10.0)
	poly(c, ell(Vector2(0, -32), Vector2(40, 18)), col)
	for i in 6:
		var x := -30.0 + i * 12.0
		poly(c, PackedVector2Array([Vector2(x - 5, -44 + abs(x) * 0.12), Vector2(x, -56 + abs(x) * 0.12), Vector2(x + 5, -44 + abs(x) * 0.12)]), Color("d7ccc8"), 2.0)
	for i in 4:
		c.draw_circle(Vector2(-24 + i * 16, -32), 4.0, dark)
	poly(c, PackedVector2Array([Vector2(34, -36), Vector2(54, -34), Vector2(56, -24), Vector2(36, -22)]), col)
	eye(c, Vector2(46, -31), 2.5)


static func pachy(c: CanvasItem, frame: int) -> void:
	var col := Color("7e8fb0")
	var dark := Color("566583")
	poly(c, PackedVector2Array([Vector2(-10, -42), Vector2(-46, -40), Vector2(-42, -34), Vector2(-10, -32)]), col)
	legs2(c, Vector2(4, -32), Vector2(-6, -32), 30.0, frame, col, dark, 8.0)
	poly(c, ell(Vector2(0, -42), Vector2(20, 15), -0.2), col)
	limb(c, Vector2(12, -50), Vector2(18, -62), 10.0, col)
	poly(c, ell(Vector2(26, -66), Vector2(16, 12)), col)
	poly(c, ell(Vector2(24, -74), Vector2(15, 10), -0.2), Color("d7c7a0"))
	for i in 4:
		c.draw_circle(Vector2(12 + i * 7, -66 - (i % 2) * 4), 2.0, Color("d7c7a0"))
	eye(c, Vector2(32, -66), 2.8)


static func stego(c: CanvasItem, frame: int) -> void:
	var col := Color("6d9b5a")
	var dark := Color("4a6d3b")
	poly(c, PackedVector2Array([Vector2(-30, -50), Vector2(-70, -40), Vector2(-74, -34), Vector2(-30, -36)]), col)
	for i in 2:
		poly(c, PackedVector2Array([Vector2(-62 + i * 8, -40), Vector2(-70 + i * 8, -56), Vector2(-56 + i * 8, -42)]), Color("f5e6c8"), 2.0)
	legs4(c, [-26.0, -12.0, 20.0, 34.0], -34.0, frame, col, dark, 13.0)
	# 등판
	for i in 6:
		var x := -34.0 + i * 13.0
		var h: float = 26.0 - abs(x) * 0.25
		poly(c, PackedVector2Array([Vector2(x - 8, -60), Vector2(x, -60 - h), Vector2(x + 8, -60)]), Color("e57373") if i % 2 == 0 else Color("ef9a9a"), 2.5)
	poly(c, ell(Vector2(0, -50), Vector2(42, 22)), col)
	c.draw_colored_polygon(ell(Vector2(2, -38), Vector2(30, 8)), col.lightened(0.15))
	limb(c, Vector2(36, -44), Vector2(52, -36), 10.0, col)
	poly(c, ell(Vector2(58, -36), Vector2(12, 8)), col)
	eye(c, Vector2(62, -38), 2.5)


# ================================================================== 보스

static func _big_biped(c: CanvasItem, frame: int, col: Color, dark: Color, belly: Color, stripes: Color, sail := false) -> void:
	# 꼬리
	poly(c, PackedVector2Array([Vector2(-30, -110), Vector2(-90, -120), Vector2(-110, -112), Vector2(-90, -104), Vector2(-30, -84)]), col)
	legs2(c, Vector2(10, -78), Vector2(-14, -78), 70.0, frame, col, dark, 22.0)
	if sail:
		var s := PackedVector2Array([Vector2(-40, -118)])
		for i in 7:
			s.append(Vector2(-36 + i * 12, -150 - sin(i * 0.5) * 30.0))
		s.append(Vector2(40, -116))
		poly(c, s, Color("e57373"))
		for i in 6:
			c.draw_line(Vector2(-30 + i * 12, -118), Vector2(-30 + i * 12, -146 - sin(i * 0.5) * 26.0), Color("b71c1c"), 2.0)
	poly(c, ell(Vector2(0, -102), Vector2(48, 34), -0.3), col)
	c.draw_colored_polygon(ell(Vector2(12, -88), Vector2(30, 18), -0.4), belly)
	if stripes.a > 0.0:
		for i in 4:
			c.draw_line(Vector2(-28 + i * 12, -128), Vector2(-20 + i * 12, -108), stripes, 5.0)
	limb(c, Vector2(36, -110), Vector2(52, -96), 6.0, dark)


static func trex(c: CanvasItem, frame: int) -> void:
	var col := Color("6b8e4e")
	var dark := Color("486335")
	_big_biped(c, frame, col, dark, Color("d6e3a8"), Color("3d5229"))
	limb(c, Vector2(28, -126), Vector2(46, -146), 26.0, col)
	poly(c, PackedVector2Array([Vector2(36, -172), Vector2(92, -172), Vector2(104, -158), Vector2(100, -146), Vector2(46, -142), Vector2(32, -156)]), col)
	poly(c, PackedVector2Array([Vector2(46, -142), Vector2(96, -144), Vector2(92, -128), Vector2(50, -128)]), dark)
	teeth(c, 54.0, 96.0, -146.0, 7, true, 7.0)
	teeth(c, 56.0, 90.0, -130.0, 6, false, 6.0)
	eye(c, Vector2(66, -162), 6.0)
	c.draw_circle(Vector2(96, -164), 3.0, OL)


static func giga(c: CanvasItem, frame: int) -> void:
	var col := Color("8a6f5a")
	var dark := Color("5c4636")
	_big_biped(c, frame, col, dark, Color("e0c9a6"), Color("b71c1c"))
	limb(c, Vector2(28, -126), Vector2(46, -146), 26.0, col)
	poly(c, PackedVector2Array([Vector2(36, -174), Vector2(100, -172), Vector2(110, -156), Vector2(46, -142), Vector2(30, -158)]), col)
	poly(c, PackedVector2Array([Vector2(46, -142), Vector2(104, -150), Vector2(98, -128), Vector2(50, -128)]), dark)
	teeth(c, 54.0, 102.0, -148.0, 8, true, 8.0)
	teeth(c, 56.0, 94.0, -130.0, 6, false, 6.0)
	poly(c, PackedVector2Array([Vector2(56, -174), Vector2(66, -186), Vector2(76, -172)]), dark, 2.0)
	eye(c, Vector2(70, -162), 6.0)
	c.draw_circle(Vector2(70, -162), 9.0, Color(1, 0.2, 0.1, 0.35))


static func spino(c: CanvasItem, frame: int) -> void:
	var col := Color("4f8a8b")
	var dark := Color("33605f")
	_big_biped(c, frame, col, dark, Color("cfe8e0"), Color(0, 0, 0, 0), true)
	limb(c, Vector2(30, -124), Vector2(50, -140), 22.0, col)
	poly(c, PackedVector2Array([Vector2(40, -156), Vector2(118, -150), Vector2(122, -140), Vector2(48, -132), Vector2(36, -144)]), col)
	poly(c, PackedVector2Array([Vector2(50, -134), Vector2(116, -140), Vector2(112, -128), Vector2(54, -124)]), dark)
	teeth(c, 60.0, 114.0, -140.0, 9, true, 6.0)
	eye(c, Vector2(62, -148), 5.0)


static func brachio(c: CanvasItem, frame: int) -> void:
	var col := Color("7f8fa6")
	var dark := Color("56647a")
	poly(c, PackedVector2Array([Vector2(-50, -110), Vector2(-120, -96), Vector2(-124, -88), Vector2(-50, -86)]), col)
	legs4(c, [-46.0, -26.0, 30.0, 50.0], -80.0, frame, col, dark, 24.0)
	poly(c, ell(Vector2(0, -110), Vector2(70, 40)), col)
	c.draw_colored_polygon(ell(Vector2(4, -90), Vector2(52, 14)), col.lightened(0.15))
	# 긴 목
	var neck := PackedVector2Array([Vector2(36, -130), Vector2(56, -190), Vector2(74, -236), Vector2(96, -236), Vector2(80, -186), Vector2(66, -116)])
	poly(c, neck, col)
	poly(c, ell(Vector2(96, -240), Vector2(24, 14), 0.1), col)
	poly(c, PackedVector2Array([Vector2(84, -252), Vector2(96, -262), Vector2(106, -250)]), col)
	eye(c, Vector2(102, -244), 4.0, false)
	c.draw_line(Vector2(104, -232), Vector2(118, -234), OL, 2.5)
	for i in 5:
		c.draw_circle(Vector2(-40 + i * 20, -128), 5.0, dark)


## 보스 머리에 씌우는 왕관
static func crown(c: CanvasItem, _frame: int) -> void:
	poly(c, PackedVector2Array([Vector2(-18, 10), Vector2(-18, -6), Vector2(-10, 2), Vector2(0, -12), Vector2(10, 2), Vector2(18, -6), Vector2(18, 10)]), Color("ffca28"), 2.5)
	c.draw_circle(Vector2(0, 4), 3.0, Color("e53935"))


# ================================================================== 탈것

static func jeep(c: CanvasItem, _frame: int) -> void:
	var col := Color("c2a46b")
	poly(c, PackedVector2Array([Vector2(-62, -18), Vector2(58, -18), Vector2(64, -40), Vector2(30, -46), Vector2(-56, -48)]), col)
	poly(c, PackedVector2Array([Vector2(16, -46), Vector2(24, -70), Vector2(30, -70), Vector2(28, -46)]), Color("9fd8ff"), 2.0)
	poly(c, PackedVector2Array([Vector2(-40, -48), Vector2(-26, -48), Vector2(-26, -60), Vector2(-40, -60)]), Color("5d4037"), 2.0)
	poly(c, PackedVector2Array([Vector2(-34, -62), Vector2(4, -66), Vector2(4, -60), Vector2(-34, -58)]), Color("37474f"), 2.0)
	poly(c, PackedVector2Array([Vector2(58, -38), Vector2(72, -32), Vector2(72, -18), Vector2(58, -18)]), Color("616161"), 2.0)
	for x in [-38.0, 38.0]:
		circ(c, Vector2(x, -14), 14.0, Color("424242"))
		c.draw_circle(Vector2(x, -14), 6.0, Color("9e9e9e"))


static func tank(c: CanvasItem, _frame: int) -> void:
	var col := Color("6f8a3c")
	# 포탑 (포신은 조준 방향으로 따로 그린다)
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(-6 + cos(a) * 38.0, -54 + sin(a) * 24.0))
	poly(c, dome, col.lightened(0.08))
	c.draw_circle(Vector2(-10, -66), 5.0, Color(1, 1, 1, 0.85))
	poly(c, PackedVector2Array([Vector2(-74, -24), Vector2(74, -24), Vector2(66, -54), Vector2(-68, -54)]), col)
	c.draw_line(Vector2(-60, -40), Vector2(60, -40), col.darkened(0.3), 3.0)
	var tr := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0
		tr.append(Vector2(62 + cos(a) * 14.0, -14 + sin(a) * 14.0))
	for i in 9:
		var a := PI * 0.5 + PI * i / 8.0
		tr.append(Vector2(-62 + cos(a) * 14.0, -14 + sin(a) * 14.0))
	poly(c, tr, Color("3a3a3a"))
	for i in 6:
		circ(c, Vector2(-60 + i * 24, -14), 8.0, Color("6b6b6b"), 2.0)


static func tank_turret(c: CanvasItem, _frame: int) -> void:
	poly(c, PackedVector2Array([Vector2(0, -6), Vector2(62, -6), Vector2(62, 6), Vector2(0, 6)]), Color("4b5e28"), 2.5)
	poly(c, PackedVector2Array([Vector2(58, -9), Vector2(70, -9), Vector2(70, 9), Vector2(58, 9)]), Color("4b5e28"), 2.5)
	poly(c, ell(Vector2.ZERO, Vector2(30, 22)), Color("7d9a45"))
	c.draw_circle(Vector2(-6, -4), 6.0, Color(1, 1, 1, 0.85))


static func ship(c: CanvasItem, _frame: int) -> void:
	# 수륙양용 전투함 (공기부양 스커트)
	poly(c, PackedVector2Array([Vector2(-86, -16), Vector2(86, -16), Vector2(78, -2), Vector2(-80, -2)]), Color("37474f"))
	poly(c, PackedVector2Array([Vector2(-84, -18), Vector2(92, -18), Vector2(78, -42), Vector2(-72, -42)]), Color("607d8b"))
	c.draw_line(Vector2(-76, -30), Vector2(84, -30), Color("b0bec5"), 3.0)
	poly(c, PackedVector2Array([Vector2(-34, -42), Vector2(26, -42), Vector2(20, -68), Vector2(-24, -68)]), Color("78909c"))
	poly(c, PackedVector2Array([Vector2(-14, -68), Vector2(10, -68), Vector2(6, -84), Vector2(-10, -84)]), Color("90a4ae"))
	c.draw_line(Vector2(-2, -84), Vector2(-2, -100), OL, 3.0)
	for x in [-60.0, 50.0]:
		poly(c, PackedVector2Array([Vector2(x - 12, -42), Vector2(x + 12, -42), Vector2(x + 10, -52), Vector2(x - 10, -52)]), Color("546e7a"), 2.5)
		c.draw_line(Vector2(x, -48), Vector2(x + 24, -56), OL, 5.0)
	for i in 4:
		c.draw_circle(Vector2(-10 + i * 6, -58), 2.0, Color("ffee58"))


static func plane(c: CanvasItem, _frame: int) -> void:
	var col := Color("90a4ae")
	poly(c, PackedVector2Array([Vector2(-10, -40), Vector2(-40, -6), Vector2(-24, -6), Vector2(20, -40)]), col.darkened(0.25))
	poly(c, PackedVector2Array([Vector2(-80, -46), Vector2(50, -52), Vector2(84, -44), Vector2(50, -36), Vector2(-80, -40)]), col)
	poly(c, PackedVector2Array([Vector2(-76, -46), Vector2(-90, -76), Vector2(-74, -76), Vector2(-56, -48)]), col.darkened(0.1))
	poly(c, PackedVector2Array([Vector2(28, -50), Vector2(48, -60), Vector2(60, -50)]), Color("9fd8ff"), 2.0)
	poly(c, PackedVector2Array([Vector2(-6, -44), Vector2(-40, -80), Vector2(-24, -80), Vector2(22, -46)]), col.darkened(0.1))
	c.draw_circle(Vector2(-88, -43), 7.0, Color(1, 0.6, 0.2, 0.8))
	c.draw_circle(Vector2(-20, -30), 4.0, Color("e53935"))


# ================================================================== 아이템/투사체

static func gem(c: CanvasItem, frame: int) -> void:
	var col: Color = [Color("4fc3f7"), Color("81c784"), Color("ef5350")][frame]
	poly(c, PackedVector2Array([Vector2(0, -12), Vector2(9, -2), Vector2(0, 12), Vector2(-9, -2)]), col, 2.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(5, -3), Vector2(0, 0), Vector2(-3, -3)]), Color(1, 1, 1, 0.6))


static func coin(c: CanvasItem, _frame: int) -> void:
	circ(c, Vector2.ZERO, 10.0, Color("ffca28"), 2.0)
	c.draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color("e0a800"), 2.0)
	c.draw_circle(Vector2(-3, -3), 2.0, Color(1, 1, 1, 0.7))


static func meat(c: CanvasItem, _frame: int) -> void:
	limb(c, Vector2(-14, 8), Vector2(-4, 0), 5.0, Color("fff3e0"))
	poly(c, ell(Vector2(6, -4), Vector2(12, 10), -0.5), Color("c0623a"), 2.5)
	c.draw_circle(Vector2(3, -8), 3.0, Color(1, 1, 1, 0.4))


static func chest(c: CanvasItem, _frame: int) -> void:
	poly(c, PackedVector2Array([Vector2(-22, -4), Vector2(22, -4), Vector2(22, 16), Vector2(-22, 16)]), Color("8d5a2b"))
	poly(c, PackedVector2Array([Vector2(-22, -4), Vector2(-18, -16), Vector2(18, -16), Vector2(22, -4)]), Color("a86b34"))
	c.draw_rect(Rect2(-22, -6, 44, 5), Color("ffca28"))
	c.draw_rect(Rect2(-4, -8, 8, 12), Color("ffca28"))


static func magnet(c: CanvasItem, _frame: int, s := 1.0) -> void:
	c.draw_arc(Vector2(0, 0), 11.0 * s, PI, TAU, 16, OL, 11.0 * s)
	c.draw_arc(Vector2(0, 0), 11.0 * s, PI, TAU, 16, Color("e53935"), 7.0 * s)
	c.draw_rect(Rect2(Vector2(-15, 0) * s, Vector2(8, 8) * s), Color("eeeeee"))
	c.draw_rect(Rect2(Vector2(7, 0) * s, Vector2(8, 8) * s), Color("eeeeee"))


static func shadow(c: CanvasItem, _frame: int) -> void:
	c.draw_colored_polygon(ell(Vector2.ZERO, Vector2(30, 10)), Color(0, 0, 0, 0.28))


static func bullet(c: CanvasItem, _frame: int) -> void:
	c.draw_circle(Vector2(0, 0), 6.0, Color(1, 0.85, 0.3, 0.4))
	poly(c, PackedVector2Array([Vector2(-7, -2.5), Vector2(4, -2.5), Vector2(8, 0), Vector2(4, 2.5), Vector2(-7, 2.5)]), Color("ffe082"), 1.5)


static func pellet(c: CanvasItem, _frame: int) -> void:
	c.draw_circle(Vector2.ZERO, 5.0, Color(1, 0.6, 0.3, 0.5))
	circ(c, Vector2.ZERO, 3.0, Color("ffab91"), 1.5)


static func grenade(c: CanvasItem, _frame: int, s := 1.0) -> void:
	circ(c, Vector2(0, 1) * s, 8.0 * s, Color("558b2f"), 2.0)
	c.draw_rect(Rect2(Vector2(-3, -10) * s, Vector2(6, 4) * s), Color("9e9e9e"))
	c.draw_line(Vector2(-4, -2) * s, Vector2(4, -2) * s, Color("33691e"), 2.0 * s)


static func saw(c: CanvasItem, _frame: int) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var r := 20.0 if i % 2 == 0 else 14.0
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly(c, pts, Color("cfd8dc"), 2.0)
	circ(c, Vector2.ZERO, 6.0, Color("607d8b"), 2.0)


static func mine(c: CanvasItem, _frame: int) -> void:
	circ(c, Vector2.ZERO, 11.0, Color("5d4037"), 2.0)
	c.draw_circle(Vector2.ZERO, 4.0, Color("ff5252"))
	for i in 4:
		var a := TAU * i / 4.0 + 0.78
		c.draw_line(Vector2(cos(a), sin(a)) * 9.0, Vector2(cos(a), sin(a)) * 14.0, OL, 3.0)


static func spit(c: CanvasItem, _frame: int) -> void:
	c.draw_circle(Vector2.ZERO, 10.0, Color(0.6, 1, 0.3, 0.35))
	circ(c, Vector2.ZERO, 6.0, Color("aeea00"), 2.0)


static func rock(c: CanvasItem, _frame: int) -> void:
	poly(c, PackedVector2Array([Vector2(-14, -4), Vector2(-6, -14), Vector2(10, -12), Vector2(15, 2), Vector2(4, 13), Vector2(-12, 9)]), Color("8d6e63"), 2.5)
	c.draw_line(Vector2(-4, -6), Vector2(6, 2), Color("5d4037"), 2.0)


static func missile(c: CanvasItem, _frame: int) -> void:
	c.draw_circle(Vector2(-14, 0), 6.0, Color(1, 0.6, 0.1, 0.6))
	poly(c, PackedVector2Array([Vector2(-12, -4), Vector2(8, -4), Vector2(14, 0), Vector2(8, 4), Vector2(-12, 4)]), Color("eceff1"), 1.5)
	c.draw_colored_polygon(PackedVector2Array([Vector2(8, -4), Vector2(14, 0), Vector2(8, 4)]), Color("e53935"))


static func bomb(c: CanvasItem, _frame: int) -> void:
	circ(c, Vector2.ZERO, 8.0, Color("37474f"), 2.0)
	poly(c, PackedVector2Array([Vector2(-6, -6), Vector2(-14, -12), Vector2(-14, 0)]), Color("546e7a"), 1.5)


static func shell(c: CanvasItem, _frame: int) -> void:
	c.draw_circle(Vector2.ZERO, 9.0, Color(1, 0.7, 0.2, 0.4))
	poly(c, PackedVector2Array([Vector2(-8, -4), Vector2(4, -4), Vector2(10, 0), Vector2(4, 4), Vector2(-8, 4)]), Color("424242"), 1.5)


# ================================================================== 아이콘 (64x64, 중심 원점)

static func icon(c: CanvasItem, id: String) -> void:
	var col := Color("263238")
	match id:
		"pistol":
			poly(c, PackedVector2Array([Vector2(-20, -10), Vector2(20, -10), Vector2(20, -2), Vector2(-4, -2), Vector2(-6, 16), Vector2(-16, 16), Vector2(-14, -2), Vector2(-20, -2)]), Color("455a64"))
		"shotgun":
			poly(c, PackedVector2Array([Vector2(-26, -6), Vector2(26, -6), Vector2(26, 0), Vector2(-6, 0), Vector2(-14, 12), Vector2(-24, 10), Vector2(-18, 0), Vector2(-26, 0)]), Color("6d4c41"))
			c.draw_line(Vector2(-4, -10), Vector2(26, -10), OL, 4.0)
		"grenade":
			grenade(c, 0, 2.0)  # 주의: 아틀라스 굽기 중이라 draw_set_transform을 쓰면 위치가 깨진다
		"saw":
			saw(c, 0)
		"flame":
			poly(c, PackedVector2Array([Vector2(0, 20), Vector2(-14, 4), Vector2(-6, -6), Vector2(-4, -20), Vector2(6, -8), Vector2(10, -18), Vector2(16, 2)]), Color("ff7043"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(0, 16), Vector2(-6, 6), Vector2(0, -4), Vector2(6, 6)]), Color("ffee58"))
		"lightning":
			poly(c, PackedVector2Array([Vector2(4, -22), Vector2(-12, 4), Vector2(0, 4), Vector2(-6, 22), Vector2(12, -4), Vector2(0, -4)]), Color("fff176"))
		"laser":
			c.draw_line(Vector2(-22, 14), Vector2(22, -14), Color(0.9, 0.4, 1, 0.5), 14.0)
			c.draw_line(Vector2(-22, 14), Vector2(22, -14), Color("f3e5f5"), 5.0)
		"mine":
			mine(c, 0)
		"might":
			poly(c, PackedVector2Array([Vector2(-14, 18), Vector2(-14, -2), Vector2(-6, -16), Vector2(6, -16), Vector2(14, -6), Vector2(14, 18)]), Color("ef5350"))
		"vital":
			c.draw_circle(Vector2(-8, -4), 10.0, Color("66bb6a"))
			c.draw_circle(Vector2(8, -4), 10.0, Color("66bb6a"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(0, 20)]), Color("66bb6a"))
		"boots":
			poly(c, PackedVector2Array([Vector2(-10, -18), Vector2(4, -18), Vector2(4, 6), Vector2(20, 10), Vector2(20, 18), Vector2(-10, 18)]), Color("4fc3f7"))
		"haste":
			c.draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color("ffca28"), 5.0)
			c.draw_line(Vector2.ZERO, Vector2(0, -12), Color("ffca28"), 4.0)
			c.draw_line(Vector2.ZERO, Vector2(9, 4), Color("ffca28"), 4.0)
		"magnet":
			magnet(c, 0, 1.6)
		"armor":
			poly(c, PackedVector2Array([Vector2(-16, -18), Vector2(16, -18), Vector2(14, 4), Vector2(0, 20), Vector2(-14, 4)]), Color("90a4ae"))
		"wisdom":
			poly(c, PackedVector2Array([Vector2(-20, -14), Vector2(0, -8), Vector2(20, -14), Vector2(20, 14), Vector2(0, 18), Vector2(-20, 14)]), Color("80deea"))
			c.draw_line(Vector2(0, -8), Vector2(0, 18), OL, 3.0)
		"heal":
			meat(c, 0)
		"gold":
			coin(c, 0)
		_:
			c.draw_circle(Vector2.ZERO, 16.0, col)
