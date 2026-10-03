extends Node
## 주인공의 한국어 대사: 말풍선 + 음성 합성(TTS).
## 웹에서는 브라우저 Web Speech API(ko-KR), 데스크톱에서는 Godot TTS를 쓴다.

const Data = preload("res://scripts/data.gd")

var tts_enabled := true
var pitch := 1.4  # 캐릭터별 목소리 높이 (남자 높게 / 여자 낮게)
var bubble := ""
var bubble_t := 0.0
var cool := 0.0       # 말풍선 간격
var tts_cool := 0.0   # 음성 간격
var idle_t := 12.0


func reset() -> void:
	bubble = ""
	bubble_t = 0.0
	cool = 0.0
	tts_cool = 0.0
	idle_t = 12.0


func update(delta: float, playing: bool) -> void:
	bubble_t -= delta
	cool -= delta
	tts_cool -= delta
	if playing:
		idle_t -= delta
		if idle_t <= 0.0:
			idle_t = randf_range(14.0, 22.0)
			say("idle")


## key: Data.LINES의 키 또는 직접 문장. force면 쿨타임을 무시한다.
func say(key: String, force := false) -> void:
	if not force and cool > 0.0:
		return
	var text := key
	if Data.LINES.has(key):
		var arr: Array = Data.LINES[key]
		text = arr[randi() % arr.size()]
	bubble = text
	bubble_t = 2.6
	cool = 4.0
	if tts_enabled and (force or tts_cool <= 0.0):
		tts_cool = 3.0
		speak(text)


func speak(text: String) -> void:
	if OS.has_feature("web"):
		var js := """
			(function(t){try{var s=window.speechSynthesis;if(!s)return;
			var u=new SpeechSynthesisUtterance(t);u.lang='ko-KR';u.rate=1.1;u.pitch=%s;
			var vs=s.getVoices();for(var i=0;i<vs.length;i++){if(vs[i].lang&&vs[i].lang.toLowerCase().indexOf('ko')==0){u.voice=vs[i];break;}}
			s.cancel();s.speak(u);}catch(e){}})(%s);
		""" % [str(pitch), JSON.stringify(text)]
		JavaScriptBridge.eval(js, true)
		return
	var voices := DisplayServer.tts_get_voices_for_language("ko")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voices[0], 80, pitch, 1.1)
