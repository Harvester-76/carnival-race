class_name UiSfx
extends Node
# Звуки интерфейса из menu_v2/sfx. Имена событий: move (перебор пунктов), tick (шаг ползунка), select (выбор), back (назад), toggle (переключатель),
# error (отказ), confirm (старт/подтверждение), delete (выход), pop (диалог/сообщение), note (уведомление), unlock (достижение), record (рекорд).

const NAMES := ["move", "tick", "select", "back", "toggle", "error", "confirm", "delete", "pop", "note", "unlock", "record"]
const DB := {"move": -3.0, "tick": -3.0, "select": 0.0, "back": 0.0, "toggle": 0.0, "error": -2.0, "confirm": 0.0, "delete": 0.0, "pop": 3.0, "note": 3.0, "unlock": 0.0, "record": 0.0}   # файлы выровнены по громкости (ср. около -16 дБ, пики до -1 дБ)
var streams := {}
var players: Array = []
var nxt := 0
var cfg: Dictionary = {}                                                    # громкость звуков интерфейса: cfg["sfx"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS                                 # в меню и на паузе time_scale = 0, звуки должны играть
	for n in NAMES:
		var p := "res://menu_v2/sfx/%s.mp3" % n
		if ResourceLoader.exists(p): streams[n] = load(p)
	for i in 6:
		var pl := AudioStreamPlayer.new(); add_child(pl); players.append(pl)

func play(n: String) -> void:
	if not streams.has(n): return
	var pl: AudioStreamPlayer = players[nxt]; nxt = (nxt + 1) % players.size()
	pl.stream = streams[n]; pl.volume_db = float(DB.get(n, -6.0)) + linear_to_db(maxf(float(cfg.get("sfx", 1.0)), 0.0001)); pl.pitch_scale = randf_range(0.97, 1.03) if n == "move" or n == "tick" else 1.0
	pl.play()
