extends Node
# Музыка: плейлисты меню и гонки, вступление Retribution (точка старта кораблей — 27.465 с от начала трека), результаты.
const DIR := "res://music/"
const MENU := ["tuman.mp3", "radium.mp3"]
const RACE := ["avenger.mp3", "globacide.mp3"]
const INTRO := "retribution.mp3"
const RESULTS := "results.mp3"
signal track_done(file: String)         # трек доигран до конца (для достижения «Меломан»)
var cfg: Dictionary
var files := ["", ""]
var mode := ""                       # menu | intro | race | results
var idx := 0
var pl: Array = []
var tws: Array = [null, null]
var cur := 0
var paused := false
var last_menu := -1                  # какой трек меню играл в прошлый раз

func _ready() -> void:
	for i in 2:
		var a := AudioStreamPlayer.new(); add_child(a); pl.append(a)
		a.finished.connect(_on_finished.bind(i))

func _vol_db() -> float:
	var key := "menu_music" if (mode == "menu" or mode == "results") else "music"       # у меню и таблицы результатов своя громкость: по умолчанию тише, чем в гонке
	return linear_to_db(maxf(float(cfg.get(key, 0.5 if key == "menu_music" else 0.8)), 0.0001))

func refresh() -> void:
	var p: AudioStreamPlayer = pl[cur]
	if p.playing and tws[cur] == null: p.volume_db = _vol_db()

func _play(file: String, fade := 1.0) -> void:
	var old: AudioStreamPlayer = pl[cur]
	if old.playing:
		if tws[cur] != null: (tws[cur] as Tween).kill()
		var tw := create_tween(); tws[cur] = tw
		tw.tween_property(old, "volume_db", -60.0, fade); tw.tween_callback(old.stop)
	cur = 1 - cur
	var n: AudioStreamPlayer = pl[cur]
	if tws[cur] != null: (tws[cur] as Tween).kill(); tws[cur] = null
	var st := load(DIR + file) as AudioStream
	if st == null: return
	files[cur] = file
	n.stream = st; n.volume_db = _vol_db(); n.stream_paused = paused; n.play()

func play_menu() -> void:                                                   # при каждом заходе в меню — случайный трек из MENU (не тот же, что играл в прошлый раз)
	if mode == "menu" and (pl[cur] as AudioStreamPlayer).playing: return
	mode = "menu"
	var n := MENU.size()
	idx = randi() % n
	if n > 1 and idx == last_menu: idx = (idx + 1 + randi() % (n - 1)) % n
	last_menu = idx; _play(MENU[idx])

func play_intro() -> void:
	mode = "intro"; idx = 0; _play(INTRO, 0.4)

func race_started() -> void:
	if mode == "intro": mode = "race"

func play_results() -> void:
	if mode == "results": return
	mode = "results"; _play(RESULTS, 1.5)

func seek_intro(t: float) -> void:
	var p: AudioStreamPlayer = pl[cur]
	if mode == "intro" and p.playing: p.seek(t)

func set_paused(b: bool) -> void:
	paused = b
	for p in pl: (p as AudioStreamPlayer).stream_paused = b

func intro_pos() -> float:           # позиция в треке вступления с учётом задержки вывода; -1, если не играет
	var p: AudioStreamPlayer = pl[cur]
	if mode != "intro" or not p.playing: return -1.0
	return maxf(p.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency(), 0.0)

func _on_finished(i: int) -> void:
	if files[i] != "": track_done.emit(files[i])
	if i != cur: return
	match mode:
		"menu": idx = (idx + 1) % MENU.size(); _play(MENU[idx], 0.01)
		"intro", "race":
			if mode == "intro": idx = 0
			mode = "race"
			_play(RACE[idx % RACE.size()], 0.01); idx += 1
		"results": _play(RESULTS, 0.01)
