class_name LoadingScreen
extends CanvasLayer
# Экран загрузки поверх всего: картинка меню на весь экран, название, полоса прогресса и крутящееся кольцо.
# Узел живёт в корне дерева, поэтому переживает перезагрузку сцены. Работа сцены идёт в основном потоке, поэтому прогресс обновляется между этапами сборки (main._lt).

const BGS := ["bar", "cabin", "corridor", "engine", "hangar", "porthole", "space", "about", "exit"]
const ORANGE := Color(1.0, 0.62, 0.18)
const CREAM := Color(0.96, 0.92, 0.82)

var rootc: Control
var bg: TextureRect
var shade: ColorRect
var title: Label
var sub: Label
var track: ColorRect
var fill: ColorRect
var shine: ColorRect
var ring: Control
var tip: Label
var shown := 0.0                # показанный прогресс 0..1 (догоняет целевой)
var target := 0.0
var fade := 0.0                 # >0: идёт затухание
var spin := 0.0
var shot_t := 0.0
var last_t := 0.0
var shot_n := 0
var active := false
var f_title: Font
var f_body: Font

const TIPS := ["Взлётные держат высоту, тяговые разгоняют, маневровые разворачивают корабль.", "Не поднимайтесь выше края каньона: через 8 секунд дисквалификация.", "Клавиша Y возвращает корабль на трассу, но стоит 20 секунд штрафа.", "Крен и тангаж помогают входить в повороты без потери скорости.", "Столкновения отрывают детали: двигатели, крылья, прожекторы."]

func _ready() -> void:
	layer = 300; process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://menu_v2/fonts/DelaGothicOne-400.ttf"): f_title = load("res://menu_v2/fonts/DelaGothicOne-400.ttf")
	if ResourceLoader.exists("res://menu_v2/fonts/GolosText-600.ttf"): f_body = load("res://menu_v2/fonts/GolosText-600.ttf")
	var root := Control.new(); rootc = root; root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(root)
	bg = TextureRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; root.add_child(bg)
	shade = ColorRect.new(); shade.set_anchors_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.02, 0.03, 0.06, 0.55); root.add_child(shade)
	var low := ColorRect.new(); low.anchor_left = 0.0; low.anchor_right = 1.0; low.anchor_top = 0.62; low.anchor_bottom = 1.0; low.color = Color(0.0, 0.0, 0.0, 0.55); root.add_child(low)
	ring = Control.new(); ring.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); ring.custom_minimum_size = Vector2(72, 72); ring.size = Vector2(72, 72)
	ring.position = Vector2(-36, -250); ring.draw.connect(_draw_ring); root.add_child(ring)
	title = Label.new(); _style(title, 44, ORANGE, f_title); title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0; title.offset_left = 0.0; title.offset_right = 0.0; title.offset_top = -170.0; title.offset_bottom = -110.0; root.add_child(title)
	sub = Label.new(); _style(sub, 22, CREAM, f_body); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.0; sub.anchor_right = 1.0; sub.anchor_top = 1.0; sub.anchor_bottom = 1.0; sub.offset_top = -108.0; sub.offset_bottom = -76.0; root.add_child(sub)
	track = ColorRect.new(); track.color = Color(1, 1, 1, 0.16); track.anchor_left = 0.2; track.anchor_right = 0.8; track.anchor_top = 1.0; track.anchor_bottom = 1.0; track.offset_top = -64.0; track.offset_bottom = -52.0; root.add_child(track)
	fill = ColorRect.new(); fill.color = ORANGE; fill.anchor_bottom = 1.0; track.add_child(fill)
	shine = ColorRect.new(); shine.color = Color(1, 1, 1, 0.55); shine.anchor_bottom = 1.0; fill.add_child(shine)
	tip = Label.new(); _style(tip, 16, Color(CREAM, 0.7), f_body); tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.anchor_left = 0.0; tip.anchor_right = 1.0; tip.anchor_top = 1.0; tip.anchor_bottom = 1.0; tip.offset_top = -40.0; tip.offset_bottom = -12.0; root.add_child(tip)
	visible = false

func _style(l: Label, sz: int, col: Color, f: Font) -> void:
	l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); l.add_theme_constant_override("outline_size", 6)
	if f != null: l.add_theme_font_override("font", f)

func _draw_ring() -> void:
	var c := ring.size * 0.5
	ring.draw_arc(c, 28.0, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 5.0, true)
	ring.draw_arc(c, 28.0, spin, spin + 1.9, 24, ORANGE, 5.0, true)
	ring.draw_arc(c, 18.0, -spin * 1.6, -spin * 1.6 + 1.2, 16, CREAM, 3.0, true)

func begin(text: String) -> void:
	if not (visible and active):                                                # экран уже показан перед перезагрузкой сцены: картинку не меняем
		var pick: String = BGS[randi() % BGS.size()]
		var path := "res://menu_v2/bg/%s.png" % pick
		if ResourceLoader.exists(path): bg.texture = load(path)
		tip.text = TIPS[randi() % TIPS.size()]
	title.text = text.to_upper(); sub.text = ""
	shown = 0.0; target = 0.0; fade = 0.0; rootc.modulate.a = 1.0; visible = true; active = true; _apply()

func progress(f: float, text: String = "") -> void:
	target = clampf(f, 0.0, 1.0)
	if text != "": sub.text = text

func finish() -> void:
	target = 1.0; fade = 0.35

func _apply() -> void:
	fill.anchor_right = clampf(shown, 0.0, 1.0)
	shine.anchor_left = 0.0; shine.anchor_right = 1.0

func _process(_scaled_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0                                   # реальное время: в меню и на паузе Engine.time_scale = 0, и delta был бы нулевым
	var dt := minf(now - last_t, 0.1); last_t = now
	if not visible: return
	if "loadshot" in OS.get_cmdline_user_args():                                # проверка: снимки экрана загрузки каждые ~0,7 с (/private/tmp/load_N.png)
		shot_t += dt
		if shot_t > 0.7: shot_t = 0.0; shot_n += 1; get_viewport().get_texture().get_image().save_png("/private/tmp/load_%d.png" % shot_n)
	spin += dt * 5.0; ring.queue_redraw()
	shown = move_toward(shown, target, dt * (0.9 if fade <= 0.0 else 3.0)) if shown < target else shown
	fill.anchor_right = clampf(shown, 0.0, 1.0)
	var k := fmod(Time.get_ticks_msec() / 1000.0, 1.2) / 1.2                               # блик пробегает по заполненной части
	shine.anchor_left = clampf(k - 0.12, 0.0, 1.0); shine.anchor_right = clampf(k + 0.12, 0.0, 1.0)
	if fade > 0.0 and shown >= 0.999:
		fade -= dt; rootc.modulate.a = clampf(fade / 0.35, 0.0, 1.0)
		if fade <= 0.0: visible = false; active = false; fade = 0.0
