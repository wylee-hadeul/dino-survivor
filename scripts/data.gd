extends RefCounted
## 게임 데이터 정의: 무기, 패시브, 공룡, 보스, 스테이지, 영구 강화, 탈것, 대사.

const STAGE_TIME := 300.0     # 스테이지 길이(초). 끝나면 최종 보스 등장
const MINI_BOSS_TIME := 150.0
const MAX_WEAPONS := 6

# ------------------------------------------------------------------ 무기
## desc[i] = 현재 레벨 i에서 다음 레벨로 올릴 때의 설명 (0 = 신규 획득)
const WEAPONS := {
	"pistol": {"name": "권총", "col": Color("ffd54f"),
		"desc": ["가장 가까운 공룡을 쏜다", "피해 +30%", "탄환 +1", "연사 속도 +25%", "관통 +1, 피해 +30%"]},
	"shotgun": {"name": "산탄총", "col": Color("ff8a65"),
		"desc": ["근거리에 산탄을 퍼붓는다", "산탄 +2", "피해 +30%", "연사 속도 +25%", "산탄 +2, 사거리 증가"]},
	"grenade": {"name": "수류탄", "col": Color("a5d6a7"),
		"desc": ["공룡 무리에 수류탄을 던진다", "폭발 범위 +20%", "수류탄 +1", "피해 +40%", "수류탄 +1, 재사용 -25%"]},
	"saw": {"name": "회전 톱날", "col": Color("90caf9"),
		"desc": ["주위를 도는 톱날 2개", "톱날 +1", "피해 +30%", "회전 반경, 속도 증가", "톱날 +2"]},
	"flame": {"name": "화염방사기", "col": Color("ff7043"),
		"desc": ["앞쪽에 불길을 뿜는다", "사거리 +25%", "피해 +35%", "불길 각도 증가", "피해 +50%"]},
	"lightning": {"name": "번개", "col": Color("fff176"),
		"desc": ["무작위 공룡에 벼락을 내린다", "벼락 +1", "피해 +35%", "벼락 +2", "재사용 -30%, 연쇄 번개"]},
	"laser": {"name": "레이저", "col": Color("ea80fc"),
		"desc": ["관통 광선을 발사한다", "광선 굵기 +40%", "피해 +40%", "광선 +1", "재사용 -30%, 피해 +40%"]},
	"mine": {"name": "지뢰", "col": Color("bcaaa4"),
		"desc": ["지나간 자리에 지뢰를 깐다", "폭발 범위 +25%", "설치 속도 +30%", "피해 +50%", "지뢰 2개씩 설치"]},
}

# ------------------------------------------------------------------ 패시브
const PASSIVES := {
	"might": {"name": "근력 강화", "desc": "공격력 +12%", "col": Color("ef5350"), "max": 5},
	"vital": {"name": "체력 단련", "desc": "최대 체력 +25, 체력 회복", "col": Color("66bb6a"), "max": 5},
	"boots": {"name": "가벼운 신발", "desc": "이동 속도 +10%", "col": Color("4fc3f7"), "max": 5},
	"haste": {"name": "속사", "desc": "모든 무기 재사용 -8%", "col": Color("ffca28"), "max": 5},
	"magnet": {"name": "자석", "desc": "아이템 흡수 범위 +35%", "col": Color("b39ddb"), "max": 5},
	"armor": {"name": "방탄복", "desc": "받는 피해 -8%", "col": Color("90a4ae"), "max": 5},
	"wisdom": {"name": "생존 지식", "desc": "획득 경험치 +12%", "col": Color("80deea"), "max": 5},
}

# ------------------------------------------------------------------ 공룡
## r: 충돌 반경, sprite: 아틀라스 이름, s: 그리기 배율
const ENEMIES := {
	"compy": {"name": "콤프소그나투스", "hp": 7.0, "speed": 92.0, "dmg": 5.0, "xp": 1, "r": 14.0, "s": 0.7},
	"raptor": {"name": "랩터", "hp": 18.0, "speed": 118.0, "dmg": 8.0, "xp": 2, "r": 18.0, "s": 0.95},
	"dilo": {"name": "딜로포사우루스", "hp": 28.0, "speed": 66.0, "dmg": 8.0, "xp": 3, "r": 20.0, "s": 1.0, "ranged": true},
	"trike": {"name": "트리케라톱스", "hp": 70.0, "speed": 52.0, "dmg": 14.0, "xp": 5, "r": 30.0, "s": 1.25, "charge": true},
	"ptero": {"name": "프테라노돈", "hp": 16.0, "speed": 150.0, "dmg": 7.0, "xp": 2, "r": 20.0, "s": 1.0, "fly": true},
	"ankylo": {"name": "안킬로사우루스", "hp": 140.0, "speed": 40.0, "dmg": 16.0, "xp": 8, "r": 32.0, "s": 1.3, "armor": 0.5},
	"pachy": {"name": "파키케팔로사우루스", "hp": 42.0, "speed": 78.0, "dmg": 12.0, "xp": 4, "r": 22.0, "s": 1.05, "charge": true},
	"stego": {"name": "스테고사우루스", "hp": 220.0, "speed": 34.0, "dmg": 20.0, "xp": 12, "r": 40.0, "s": 1.5},
}

const BOSSES := {
	"raptor_king": {"name": "랩터 킹", "hp": 650.0, "speed": 105.0, "dmg": 15.0, "r": 40.0, "s": 1.9, "sprite": "raptor"},
	"trike_king": {"name": "트리케라 킹", "hp": 950.0, "speed": 62.0, "dmg": 20.0, "r": 52.0, "s": 2.2, "sprite": "trike"},
	"trex": {"name": "티라노사우루스", "hp": 2600.0, "speed": 82.0, "dmg": 25.0, "r": 62.0, "s": 1.0, "sprite": "trex"},
	"spino": {"name": "스피노사우루스", "hp": 3300.0, "speed": 74.0, "dmg": 24.0, "r": 64.0, "s": 1.0, "sprite": "spino"},
	"brachio": {"name": "브라키오사우루스", "hp": 4600.0, "speed": 42.0, "dmg": 30.0, "r": 78.0, "s": 1.0, "sprite": "brachio"},
	"giga": {"name": "기가노토사우루스", "hp": 5200.0, "speed": 92.0, "dmg": 30.0, "r": 66.0, "s": 1.0, "sprite": "giga"},
}

# ------------------------------------------------------------------ 도감
const DINO_INFO := {
	"compy": {"era": "쥐라기 후기", "desc": "닭만 한 작은 육식 공룡.\n떼를 지어 몰려다닌다.", "tip": "약하지만 수가 많다. 범위 무기로 쓸어버리자."},
	"raptor": {"era": "백악기 후기", "desc": "뒷발의 갈고리 발톱이 무기인\n영리하고 날쌘 사냥꾼.", "tip": "빠르게 쫓아온다. 멈추지 말고 계속 움직이자."},
	"dilo": {"era": "쥐라기 전기", "desc": "머리에 볏이 두 개 있는 공룡.\n화가 나면 목 주름을 펼친다.", "tip": "멀리서 침을 뱉는다. 초록 침을 피하자."},
	"trike": {"era": "백악기 후기", "desc": "뿔 세 개와 커다란 프릴을 가진\n튼튼한 초식 공룡.", "tip": "몸을 떤 뒤 돌진한다. 옆으로 비켜서자."},
	"ptero": {"era": "백악기 후기", "desc": "하늘을 나는 익룡.\n사실 공룡이 아니라 공룡의 사촌이다.", "tip": "빠르게 날아든다. 자동 조준 무기가 유리하다."},
	"ankylo": {"era": "백악기 후기", "desc": "갑옷 같은 등과 곤봉 꼬리를 가진\n걸어 다니는 탱크.", "tip": "단단해서 받는 피해가 줄어든다. 화력을 집중하자."},
	"pachy": {"era": "백악기 후기", "desc": "두께 25cm의 돔 머리로\n박치기를 하는 공룡.", "tip": "몸을 떤 뒤 박치기 돌진! 옆으로 피하자."},
	"stego": {"era": "쥐라기 후기", "desc": "등에 골판, 꼬리에 가시가 달린\n거대한 초식 공룡.", "tip": "느리지만 체력이 엄청나다. 거리를 두고 공격하자."},
	"raptor_king": {"era": "보스", "desc": "랩터 무리를 이끄는 우두머리.\n머리에 왕관을 썼다.", "tip": "빨간 예고선 방향으로 돌진하고 부하 랩터를 부른다."},
	"trike_king": {"era": "보스", "desc": "섬에서 가장 큰 트리케라톱스.\n무리의 왕이다.", "tip": "연속 돌진 뒤 충격파를 일으킨다. 고리를 넘어 피하자."},
	"trex": {"era": "백악기 후기", "desc": "공룡의 왕 티라노사우루스.\n자동차도 부수는 턱 힘을 가졌다.", "tip": "포효 충격파, 낙석, 돌진을 번갈아 쓴다."},
	"spino": {"era": "백악기 전기", "desc": "등에 돛이 달린 거대한 육식 공룡.\n물가에서 물고기를 사냥했다.", "tip": "부채꼴로 침을 뱉고, 높이 뛰어올라 덮친다."},
	"brachio": {"era": "쥐라기 후기", "desc": "기린처럼 긴 목을 가진\n초거대 초식 공룡.", "tip": "발 구르기 충격파 3연타와 낙석, 콤프 소환에 주의."},
	"giga": {"era": "백악기 전기", "desc": "티라노보다 더 큰 육식 공룡\n기가노토사우루스.", "tip": "연속 돌진, 포효, 부하 소환. 체력이 엄청나다."},
}


## 스테이지에 나오는 공룡 목록 (일반 → 중간 보스 → 최종 보스)
static func stage_dinos(s: int) -> Array:
	var info := stage_info(s)
	var out: Array = info.pool.duplicate()
	out.append(info.mini)
	out.append(info.boss)
	return out


static func dino_name(kind: String) -> String:
	if ENEMIES.has(kind):
		return ENEMIES[kind].name
	return BOSSES[kind].name


static func dino_sprite(kind: String) -> String:
	if BOSSES.has(kind):
		return BOSSES[kind].sprite
	return kind


# ------------------------------------------------------------------ 스테이지
## pool: 시간이 지날수록 앞에서부터 하나씩 추가로 등장
const STAGES := [
	{"name": "고사리 숲", "theme": 0, "pool": ["compy", "raptor", "dilo"], "mini": "raptor_king", "boss": "trex"},
	{"name": "화산 지대", "theme": 1, "pool": ["compy", "raptor", "dilo", "trike", "pachy"], "mini": "trike_king", "boss": "spino"},
	{"name": "안개 늪", "theme": 2, "pool": ["raptor", "ptero", "dilo", "ankylo", "trike"], "mini": "raptor_king", "boss": "brachio"},
	{"name": "빙하 계곡", "theme": 3, "pool": ["raptor", "ptero", "pachy", "stego", "ankylo", "dilo"], "mini": "trike_king", "boss": "giga"},
]

static func stage_info(s: int) -> Dictionary:
	return STAGES[(s - 1) % STAGES.size()]


## 스테이지 난이도 배율 (적 체력/공격)
static func stage_hp_mult(s: int) -> float:
	return 1.0 + 0.6 * (s - 1)


## 보스 체력은 일반 공룡보다 완만하게 오른다
static func boss_hp_mult(s: int) -> float:
	return 1.0 + 0.35 * (s - 1)


static func stage_dmg_mult(s: int) -> float:
	return 1.0 + 0.2 * (s - 1)


static func clear_gold(s: int) -> int:
	return 80 + 40 * s


# ------------------------------------------------------------------ 영구 강화 (골드)
const TALENTS := [
	{"id": "atk", "name": "사격 훈련", "desc": "공격력 +6%", "base": 40, "max": 20, "col": Color("ef5350")},
	{"id": "hp", "name": "체력 훈련", "desc": "최대 체력 +12", "base": 40, "max": 20, "col": Color("66bb6a")},
	{"id": "def", "name": "전투복", "desc": "받는 피해 -3%", "base": 60, "max": 10, "col": Color("90a4ae")},
	{"id": "spd", "name": "달리기", "desc": "이동 속도 +3%", "base": 50, "max": 10, "col": Color("4fc3f7")},
	{"id": "xp", "name": "학습 능력", "desc": "획득 경험치 +6%", "base": 60, "max": 10, "col": Color("80deea")},
	{"id": "gold", "name": "보물 사냥꾼", "desc": "획득 골드 +10%", "base": 60, "max": 10, "col": Color("ffd54f")},
	{"id": "mag", "name": "수집가", "desc": "흡수 범위 +10%", "base": 40, "max": 10, "col": Color("b39ddb")},
	{"id": "ride", "name": "운전 실력", "desc": "탑승 게이지 충전 +12%", "base": 80, "max": 5, "col": Color("ffb74d")},
	{"id": "revive", "name": "구급 상자", "desc": "스테이지마다 1회 부활", "base": 500, "max": 1, "col": Color("f48fb1")},
]

static func talent_cost(t: Dictionary, lvl: int) -> int:
	return int(round(t.base * pow(1.33, lvl)))


# ------------------------------------------------------------------ 탈것
## price: 차고에서 구매하는 가격 (0 = 기본 보유)
const VEHICLES := [
	{"id": "jeep", "name": "지프", "price": 0, "desc": "빠르게 달리며 들이받고\n기관총을 난사한다", "time": 12.0, "speed": 1.8, "hp": 150.0, "col": Color("c2a46b")},
	{"id": "tank", "name": "탱크", "price": 600, "desc": "단단한 장갑과\n폭발하는 포탄", "time": 15.0, "speed": 1.15, "hp": 400.0, "col": Color("6f8a3c")},
	{"id": "ship", "name": "전투함", "price": 1300, "desc": "수륙양용 전투함.\n사방으로 미사일 일제 사격", "time": 15.0, "speed": 1.4, "hp": 300.0, "col": Color("607d8b")},
	{"id": "plane", "name": "전투기", "price": 1, "desc": "하늘을 날아 무적!\n융단 폭격과 기관포", "time": 12.0, "speed": 2.2, "hp": 1.0, "col": Color("90a4ae")},
]

static func vehicle(id: String) -> Dictionary:
	for v in VEHICLES:
		if v.id == id:
			return v
	return VEHICLES[0]


static func vehicle_cost(lvl: int) -> int:
	return int(round(120 * pow(1.5, lvl)))


const RIDE_KILLS := 70  # 탑승 게이지를 채우는 처치 수

# ------------------------------------------------------------------ 대사 (주인공은 한국말을 한다)
const LINES := {
	"start": ["여긴 어디지...? 공룡이다!", "살아서 돌아가야 해!", "좋아, 한번 해보자!", "공룡 섬이라니... 정신 차리자!"],
	"levelup": ["더 강해졌어!", "이거 좋은데?", "힘이 솟는다!", "업그레이드 완료!"],
	"hurt": ["으악!", "아파!", "윽!"],
	"lowhp": ["위험해...!", "체력이 얼마 안 남았어!", "버텨야 해!"],
	"mini": ["큰 녀석이 온다!", "저건 뭐야?!"],
	"boss": ["저 녀석이 대장인가!", "엄청 크잖아...!", "덤벼라, 괴물아!"],
	"bossdown": ["해냈다!", "대장을 쓰러뜨렸어!"],
	"ride": ["탑승 완료! 가자!", "길을 비켜라!", "이제 내 차례다!"],
	"swarm": ["떼로 몰려온다!", "엄청 많아!"],
	"idle": ["계속 움직여야 해!", "끝이 없네...", "아직 할 만해!", "받아라!", "공룡 따위!"],
	"chest": ["보급 상자다!", "선물이다!"],
	"revive": ["아직 끝나지 않았어!"],
	"clear": ["살아남았다!"],
}
