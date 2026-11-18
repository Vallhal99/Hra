extends Node
## Autoload "Audio": hudba podle mapy (plynulý přechod) a zvukové efekty. Vše je generované (audio/*.wav).

const MUSIC := {
	"louka": "m_pozadi", "rozcesti": "m_pozadi", "hvozd": "m_pozadi", "jezero": "m_pozadi",
	"vesnice": "m_pozadi", "obchod": "m_pozadi", "hostinec": "m_pozadi", "hrbitov": "m_hrbitov", "hrobka": "m_hrobka", "jeskyne": "m_jeskyne",
	"battle": "m_boj", "main_menu": "m_pozadi"}
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur := ""
var _want := ""
var _scene := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var music_db := -9.0
var sfx_db := -5.0
var enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	add_child(_a)
	add_child(_b)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_db
		add_child(p)
		_sfx_pool.append(p)
	get_tree().node_added.connect(_on_node)


func _on_node(n: Node) -> void:
	if n is Button:
		(n as Button).pressed.connect(func(): sfx("s_click"))
		(n as Button).focus_entered.connect(func(): sfx("s_move"))


func _load(nm: String) -> AudioStream:
	if _cache.has(nm):
		return _cache[nm]
	var path := "res://audio/%s.mp3" % nm
	if not ResourceLoader.exists(path):
		path = "res://audio/%s.wav" % nm
	var st = load(path)
	_cache[nm] = st
	return st


func sfx(nm: String, vol := 0.0) -> void:
	if not enabled:
		return
	var st := _load(nm)
	if st == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = st
			p.volume_db = sfx_db + vol
			p.play()
			return


func music(nm: String) -> void:
	_want = nm
	if nm == _cur:
		return
	_cur = nm
	var st: AudioStream = _load(nm).duplicate() if _load(nm) else null
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	var old := _a
	_a = _b
	_b = old
	_a.stream = st
	_a.volume_db = -60.0
	if st and enabled:
		_a.play()
	var tw := create_tween()
	tw.tween_property(_a, "volume_db", music_db, 1.5)
	tw.parallel().tween_property(_b, "volume_db", -60.0, 1.5)
	tw.tween_callback(_b.stop)


func _process(_dt: float) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	var nm := sc.scene_file_path.get_file().get_basename()
	if nm == _scene:
		return
	_scene = nm
	var tr: String = str(MUSIC.get(nm, ""))
	if nm == "battle":
		var bm := get_node_or_null("/root/BattleManager")
		tr = "m_boss" if bm != null and bm.enemies.size() > 0 and bm.enemies[0].boss else "m_boj"
		sfx("s_boss" if tr == "m_boss" else "s_slash")
	if tr != "":
		music(tr)
