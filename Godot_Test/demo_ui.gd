extends CanvasLayer
# Интерфейс демо «Третий шанс»: главное меню, пауза, обратный отсчёт, HUD гонки, экран результатов.
# Управляется геймпадом (ui_* действия: стик/крестовина, A, B) и клавиатурой. Данные берёт у main.gd (ссылка main).

var main: Node
var state := "hud"                 # menu | pause | hud | results
var sel := 0
var items: Array = []
var root: Control
var menu_panel: Control
var side: ColorRect
var title_lbl: Label
var sub_lbl: Label
var item_lbls: Array = []
var desc_lbl: Label
var hint_lbl: Label
var dim: ColorRect
var hud_root: Control
var lbl_rank: Label
var lbl_time: Label
var lbl_speed: Label
var lbl_alt: Label
var lbl_lvl: Label
var lbl_count: Label
var lbl_skip: Label
var lbl_stab: Label
var ov_ctl: Control
var ov_off := Vector2.ZERO
var ov_sc := 1.0
var prog_bar: ColorRect
var prog_bg: ColorRect
var dmg_ctl: Control
var map_ctl: Control
var res_panel: Control
var res_title: Label
var res_rows: Array = []
var res_btns: Array = []
var res_sub: Label
var marks: Array = []
var res_t_show := -1.0
var go_t := 0.0
var last_count := 99
var map_b := Rect2()
var map_s := 1.0
var marker_root: Control
var marker_lbls: Array = []
var skin: MenuSkin
var about_link := 0
var link_cur := {}                                                           # открытая в диалоге ссылка: {name, url, qr}
func open_link(name: String, url: String, qr: String) -> void:               # ссылка в браузер открывается только кнопкой «Перейти» в диалоге
	link_cur = {"name": name, "url": url, "qr": qr}; goto_page("link")
const LINKS := ["https://vk.ru/re_cycle", "https://m.soundcloud.com/cored_bitch"]
const ABOUT_TEXT := "Демо-прототип космической гонки по мотивам цикла Ольги Громыко «Космоолухи»: гонка на транспортных кораблях по каньону планеты Карнавал. Написан на Godot %s (физика Jolt) для обкатки управления, трассы и ботов. Одна трасса, двенадцать участников, пять уровней сложности и четыре корабля. Собран для показа идеи. Подробности — в разделе «Планы и режимы» ниже."
const ACH := [
	{"id": "finish", "title": "Первый блин", "cond": "Дойти до финиша."},
	{"id": "podium", "title": "На подиуме", "cond": "Финишировать в тройке."},
	{"id": "win", "title": "Любимец публики", "cond": "Прийти к финишу первым."},
	{"id": "clean", "title": "Без единой царапины", "cond": "Финишировать без единого удара."},
	{"id": "low", "title": "Под потолком", "cond": "Финишировать, ни разу не поднявшись выше края каньона."},
	{"id": "side", "title": "Не как все", "cond": "Свернуть на боковой проход трассы."},
	{"id": "tourist", "title": "Турист со стажем", "cond": "Финишировать на уровне «Турист»."},
	{"id": "veteran", "title": "Видел всякое", "cond": "Финишировать на уровне «Ветеран»."},
	{"id": "cyborg", "title": "Киборг в душе", "cond": "Финишировать на уровне «Киборг»."},
	{"id": "freya", "title": "Старушка Фрея", "cond": "Финишировать на «Фрее»."},
	{"id": "record", "title": "Личный рекорд", "cond": "Улучшить своё время на трассе."},
	{"id": "book", "title": "Как в книге", "cond": "Прийти первым на «Третьем шансе»: стартуя последним.", "hidden": true},
	{"id": "short_music", "title": "Недолго музыка играла", "cond": "Пройти трассу до завершения стартового трека Re:Cycle — Retribution."},
	{"id": "crash_total", "title": "Полный крах", "cond": "Максимально разрушить свой корабль: потерять все детали (кнопка «взорвать всё» не считается)."},
	{"id": "lost3", "title": "Заблудился в трёх соснах", "cond": "Двигаться по трассе в обратную сторону более 20 км за один заезд."},
	{"id": "pilot_test", "title": "Лётчик испытатель", "cond": "Дойти до финиша на всех кораблях."},
	{"id": "academy", "title": "Летная Академия", "cond": "Дойти до финиша на всех уровнях сложности."},
	{"id": "klutz", "title": "Криворукий", "cond": "Получить 10 дисквалификаций подряд."},
	{"id": "gamepad", "title": "Истинный геймер", "cond": "Совершить полёт на геймпаде."},
	{"id": "keyboard", "title": "Клавиатурный маньяк", "cond": "Совершить полёт на клавиатуре."},
	{"id": "custom", "title": "Кастомайзер", "cond": "Настроить управление под себя."},
	{"id": "custom_adv", "title": "Продвинутый кастомайзер", "cond": "Настроить продвинутые опции управления под себя."},
	{"id": "loser", "title": "Лузер", "cond": "Прийти к финишу последним."},
	{"id": "beat_dev", "title": "Победил Разработчика", "cond": "Прийти к финишу быстрее рекорда разработчика (с новыми версиями игры рекорды обновляются)."},
	{"id": "aggressor", "title": "Агрессор", "cond": "Совершить столкновение с другим кораблём."},
	{"id": "melomaniac", "title": "Меломан", "cond": "Прослушать до конца все треки игры: и в меню, и в гонке."},
	{"id": "seagull", "title": "Чайка", "cond": "Дойти до финиша на «Долгоносике»."},
	{"id": "not_mine", "title": "Это не мое", "cond": "Выйти из игры при первом запуске, не начав ни одной гонки."},
	{"id": "tester", "title": "Тестировщик", "cond": "Посетить все экраны и подэкраны меню и совершить хотя бы одну гонку."},
	{"id": "shor", "title": "Шор", "cond": "Назначить тангаж и крен на правый стик."},
	{"id": "os_win", "title": "Установщик Винды", "cond": "Запустить игру на Windows."},
	{"id": "os_mac", "title": "Маковод", "cond": "Запустить игру на macOS."},
	{"id": "os_linux", "title": "Собрал ядро", "cond": "Запустить игру на Linux."},
	{"id": "os_android", "title": "Ржавое ведерко", "cond": "Запустить игру на Android."},
	{"id": "os_ios", "title": "Владелец огрызка", "cond": "Запустить игру на iOS."},
	{"id": "jeweler", "title": "Ювелир", "cond": "Дойти до финиша, ни разу не поднявшись выше 2000 метров."},
	{"id": "brave", "title": "Выпил для храбрости", "cond": "Пройти более 60% трассы с креном больше 60 градусов."},
	{"id": "eyes", "title": "Глазами пилота", "cond": "Дойти до финиша, ни разу не покинув вид из кабины."},
	{"id": "speed", "title": "Скоростной демон", "cond": "Разогнаться до 3000 м/с."},
	{"id": "unstick3", "title": "Опять застрял", "cond": "Использовать все три возврата на трассу за один заезд."},
	{"id": "intact", "title": "Целёхонек", "cond": "Дойти до финиша, не потеряв ни одной детали."},
	{"id": "km1000", "title": "Налётчик", "cond": "Налетать суммарно 20000 км."},
	{"id": "vet25", "title": "Ветеран трассы", "cond": "Дойти до финиша 25 раз."},
	{"id": "will", "title": "Воля к победе", "cond": "Прийти к финишу первым, потеряв все моторы."},
	{"id": "timid", "title": "Робкий гонщик", "cond": "Нажать «Выход», а потом передумать."},
	{"id": "connoisseur", "title": "Ценитель", "cond": "Получить «Летная Академия», «Лётчик испытатель», «Меломан» и посмотреть катсцену до конца."},
	{"id": "graveyard", "title": "Кладбище кораблей", "cond": "Полностью уничтожить каждый корабль в игре."},
	{"id": "hacker", "title": "Мамкин хацкер", "cond": "Попытаться руками подправить файл прогресса.", "hidden": true},
	{"id": "collector", "title": "Коллекционер грамот", "cond": "Получить 20 других достижений."}]
const DEV_RECORD := 137.36                                                  # рекорд разработчика, с (2:17.36, «Дальнобойщик»): один на все уровни и корабли; обновляется с версиями игры
const OS_ACH := {"Windows": "os_win", "macOS": "os_mac", "Linux": "os_linux", "FreeBSD": "os_linux", "NetBSD": "os_linux", "OpenBSD": "os_linux", "BSD": "os_linux", "Android": "os_android", "iOS": "os_ios"}
const MUSIC_ALL := ["tuman.mp3", "radium.mp3", "avenger.mp3", "globacide.mp3", "retribution.mp3", "results.mp3"]
const PAGES_ALL := ["settings", "controls", "sound", "camera", "keys", "pad", "advanced", "ach", "about", "project", "exit"]
const PROJECT_SECTIONS := [
	{"t": "О проекте", "body": "Карнавальская Гонка — игра по мотивам цикла Ольги Громыко «Космоолухи»: гонка транспортных кораблей по гигантскому каньону планеты Карнавал, где побеждает не самый быстрый, а самый хитрый, везучий и живучий. Главная цель — передать дух книжных гонок: ветвящуюся трассу, где путь выбирают на ходу, подножки соперникам, обвалы, тупики и отыгрыш ролей.\n\nСейчас перед вами демо-прототип на движке Godot. Он нужен, чтобы обкатать управление кораблём, поведение соперников и показать идею. Полноценная игра будет делаться на Unreal Engine."},
	{"t": "Режимы игры", "body": "Тренировочный режим. Гонка с ботами. Можно выбрать участок реальной трассы из книги длиной 3–5 минут игрового времени и отрабатывать именно его. Правила выбывания (застрял, перевёрнут, вылетел за кромку) задаются отдельно для каждого режима и хранятся как данные, а не зашиты в код.\n\nRP-режим. Игра служит средой для ролевой игры: гонка идёт по всей трассе целиком. Сломанный корабль не дисквалифицируется автоматически, он ждёт эвакуации, а решения (штраф, возврат на трассу, дисквалификация) принимают живые судьи.\n\nСетевая гонка без RP: правила применяет автомат. В далёкой перспективе возможна ролевая игра (RPG)."},
	{"t": "Роли и состояния", "body": "Роли. Гонщик ранжируется и может быть дисквалифицирован. Судья или наблюдатель (в RP-режиме) дисквалифицирует, возвращает на трассу, назначает штраф. Служебная техника (эвакуаторы, флайеры-репортёры, сопровождение) без ранга летает вне трассы.\n\nСостояния гонщика: на дистанции; застрял (нет продвижения, нет моторов или перевёрнут); ждёт эвакуации; возвращён со штрафом; дисквалифицирован (в том числе за подъём выше кромки каньона); финишировал.\n\nВсе решения идут через один механизм «решение по участнику»: в RP-режиме его вызывает судья, в остальных режимах автомат."},
	{"t": "Трасса из книги", "body": "В книге трасса — разлом-каньон длиной около тысячи километров у экватора планеты. Это не одна линия, а дерево развилок: часть пути проходят все участники, часть — по разным каналам, и о соседнем канале знаешь только со слов комментатора. Искусственные тупики на схеме не отмечены, поэтому каждый год пилоты открывают трассу «на ощупь».\n\nУчастки: Малый Сток, Игольное Ушко, Заворот Кишок, Задница Дьявола, Крысоловка (технический тоннель), Песочные Часы с фальш-дном и финиш.\n\nВся книжная трасса займёт около часа игры. В тренировочном режиме можно выбрать участок на 3–5 минут, в RP-режиме проходится вся трасса целиком."},
	{"t": "Трасса в демо", "body": "В демо трасса сгенерирована программой и не повторяет книжную: около 640 км, три срезки (узкие извилистые ущелья с изломанными краями, которые сокращают путь) и несколько тупиков, в конце которых стоят каменные «леса» столбов в духе Чжанцзяцзе. Ошибиться и потеряться в каньоне здесь можно так же, как в книге.\n\nУчастков из книги (Игольное Ушко, Заворот Кишок, Задница Дьявола, Крысоловка, Песочные Часы) в демо нет: их построят сразу в Unreal."},
	{"t": "Ограничения демо", "body": "Графика и рельеф. В Godot рельеф задан формулой высоты: каньон слоистый, с уступами, но без нависающих скал, пещер, арок и тоннелей. Освещение, туман и материалы упрощены, нет качественных теней и детальных скал.\n\nКарта. Есть только упрощённая схема линии трассы, настоящей карты каньона с лабиринтом пока нет. Трасса одна.\n\nОстальное. Нет сетевой игры, судей и служебной техники. Соперники — боты с общим набором повадок. Скорости и размеры каньона подобраны для удобства управления, а не по книжным масштабам."},
	{"t": "Что будет в Unreal", "body": "Итоговая игра делается на Unreal Engine. Трассу строят в нём сразу, а не переносят из Godot: инструменты ландшафта, Nanite и World Partition позволяют построить каньон длиной до тысячи километров с тоннелями, нависающими скалами, арками, Крысоловкой и Песочными Часами.\n\nГрафика: реалистичное освещение, пыль, погода, детальные скалы и корабли. Карта: полная схема трассы с развилками (искусственные тупики на ней по-прежнему не отмечены) и карта участка во время гонки.\n\nИз Godot переносятся числа: параметры управления, логика ботов, правила гонки, размеры и скорости."},
	{"t": "Корабли", "body": "Сейчас четыре корабля («Третий шанс», «Фрея», «Долгоносик», «Аргамак») сделаны из одной базовой модели: нейросеть изменила её пропорции и добавила или убрала каюты, а ливреи различаются только окраской. Поэтому они так похожи друг на друга.\n\nВ финальной версии каждый корабль станет уникальной моделью со своей формой корпуса, моторами и характером, как в книге: у каждого свои сильные стороны и слабости. Кораблей тоже станет больше."},
	{"t": "Иллюстрации", "body": "Из книги взяты только картинки уровней сложности, пока без разрешения художника. Все остальные изображения (фоны меню, иконки грамот и другие) сгенерированы нейросетью.\n\nЭто временное решение для демо-прототипа. В дальнейшем все эти изображения планируется заменить оригинальными, созданными специально для игры."},
	{"t": "Управление", "body": "Корабль держится на трёх видах моторов: тяговые разгоняют, взлётные держат высоту и тормозят, маневровые на крыльях поворачивают и сдвигают. Есть пять уровней сложности управления: чем выше, тем меньше помогает гашение лишней инерции (самый сложный — «Киборг»).\n\nДетали отрываются при ударах, потеря моторов меняет поведение корабля. Эта модель управления переносится в Unreal."}]


const CREAM := Color(0.97, 0.9, 0.75)
const ORANGE := Color(1.0, 0.58, 0.16)
const DARK := Color(0.07, 0.05, 0.03, 0.62)
const LEVEL_DESC := ["Максимальная помощь: корабль едет почти как автомобиль, сам выравнивается по крену.",
	"Сильная помощь: снос гасится, крен выравнивается.", "Помощь слабее, управление ближе к настоящему.",
	"Без гашения сноса: инерция как есть. Для тех, кто освоился.", "Всё вручную: нет удержания высоты и стабилизации, схема 2. Для психов."]

var sfx: UiSfx

func _ready() -> void:
	layer = 10
	_apply_volume()                                                            # общая громкость из настроек действует с запуска, а не только после её изменения
	sfx = UiSfx.new(); sfx.cfg = main.cfg; add_child(sfx)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	_build_hud(); _build_menu(); _build_results()
	call_deferred("_check_platform"); call_deferred("_check_derived"); call_deferred("_apply_tamper")
	skin = MenuSkin.new(); root.add_child(skin); skin.visible = false
	marker_root = Control.new(); marker_root.set_anchors_preset(Control.PRESET_FULL_RECT); marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(marker_root); root.move_child(marker_root, 0)
	_show_state("hud")

func _lbl(text: String, size: int, col: Color, parent: Control, pos := Vector2.ZERO) -> Label:
	var l := Label.new(); l.text = text; l.position = pos
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9)); l.add_theme_constant_override("outline_size", maxi(3, size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(l); return l

# ---------- HUD ----------
func _build_hud() -> void:
	ov_ctl = Control.new(); ov_ctl.set_anchors_preset(Control.PRESET_FULL_RECT); ov_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; ov_ctl.visible = false; root.add_child(ov_ctl); ov_ctl.draw.connect(_draw_ov)
	lbl_stab = _lbl("СТАБИЛИЗАЦИЯ ВЫКЛ  (A / T — включить)", 26, Color(1.0, 0.35, 0.25), root, Vector2(520, 800)); lbl_stab.visible = false
	lbl_skip = _lbl("A / Enter — пропустить заставку", 24, Color(1, 1, 1, 0.8), root, Vector2(1030, 835)); lbl_skip.visible = false
	hud_root = Control.new(); hud_root.set_anchors_preset(Control.PRESET_FULL_RECT); hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hud_root)
	var tl := Control.new(); tl.position = Vector2(28, 18); tl.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(tl)
	_lbl("ПОЗИЦИЯ", 16, Color(1, 1, 1, 0.65), tl, Vector2(2, 0))
	lbl_rank = _lbl("1/11", 70, CREAM, tl, Vector2(0, 14))
	var tc := Control.new(); tc.set_anchors_preset(Control.PRESET_CENTER_TOP); tc.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(tc)
	lbl_time = _lbl("0:00.0", 44, CREAM, tc, Vector2(-80, 14))
	prog_bg = ColorRect.new(); prog_bg.color = Color(0, 0, 0, 0.45); prog_bg.position = Vector2(-220, 72); prog_bg.size = Vector2(440, 8); tc.add_child(prog_bg)
	prog_bar = ColorRect.new(); prog_bar.color = ORANGE; prog_bar.position = Vector2(-220, 72); prog_bar.size = Vector2(0, 8); tc.add_child(prog_bar)
	lbl_lvl = _lbl("", 16, Color(1, 1, 1, 0.55), tc, Vector2(-220, 86))
	var bl := Control.new(); bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); bl.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(bl)
	lbl_speed = _lbl("0", 76, CREAM, bl, Vector2(28, -170))
	lbl_alt = _lbl("", 22, Color(1, 1, 1, 0.85), bl, Vector2(34, -62))
	var bc := Control.new(); bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); bc.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(bc)
	dmg_ctl = Control.new(); dmg_ctl.position = Vector2(-175, -104); dmg_ctl.size = Vector2(350, 92); dmg_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; bc.add_child(dmg_ctl)
	dmg_ctl.draw.connect(_draw_damage)
	var br := Control.new(); br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); br.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(br)
	map_ctl = Control.new(); map_ctl.position = Vector2(-292, -292); map_ctl.size = Vector2(268, 268); map_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE; br.add_child(map_ctl)
	map_ctl.draw.connect(_draw_map)
	var cc := Control.new(); cc.set_anchors_preset(Control.PRESET_CENTER); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_root.add_child(cc)
	lbl_count = _lbl("", 200, ORANGE, cc, Vector2(-120, -170)); lbl_count.add_theme_constant_override("outline_size", 22)

func _draw_damage() -> void:                                                 # здоровье корабля: общий процент + состояние моторов по группам
	var c := dmg_ctl; var f := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.45))
	var hp: float = main.ship_health()
	var hc := Color(0.35, 0.9, 0.45) if hp > 0.66 else (Color(0.95, 0.8, 0.25) if hp > 0.33 else Color(0.95, 0.25, 0.2))
	c.draw_string(f, Vector2(10, 20), "ЗДОРОВЬЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))
	c.draw_string(f, Vector2(c.size.x - 10 - 80, 22), "%d%%" % int(round(hp * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 80, 22, hc)
	c.draw_rect(Rect2(10, 28, c.size.x - 20, 6), Color(1, 1, 1, 0.15)); c.draw_rect(Rect2(10, 28, (c.size.x - 20) * hp, 6), hc)
	var groups := [["main", "Тяговые"], ["lift", "Взлётные"], ["shunt", "Маневровые"]]
	var x := 10.0
	for g in groups:
		var names := []
		for nm in main.engines: if main.engines[nm]["kind"] == g[0]: names.append(nm)
		names.sort()
		var w := 17.0 * names.size()
		c.draw_string(f, Vector2(x, 52), g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
		var i := 0
		for nm in names:
			var ok: bool = main.parts.has(nm)
			c.draw_rect(Rect2(x + i * 17.0, 58, 14, 26), Color(0.35, 0.9, 0.45, 0.9) if ok else Color(0.9, 0.2, 0.15, 0.9))
			i += 1
		x += maxf(w, 78.0) + 10.0

func _map_setup() -> void:
	var lo := Vector2(1e12, 1e12); var hi := Vector2(-1e12, -1e12)
	for p in main.trk_pts: lo = lo.min(p); hi = hi.max(p)
	var sz := hi - lo
	map_s = minf(240.0 / maxf(sz.x, 1.0), 240.0 / maxf(sz.y, 1.0))
	map_b = Rect2(lo, sz)

func _mp(p: Vector2) -> Vector2:
	return Vector2(14.0, 14.0) + (p - map_b.position) * map_s + Vector2((240.0 - map_b.size.x * map_s) * 0.5, (240.0 - map_b.size.y * map_s) * 0.5)

func _draw_map() -> void:
	var c := map_ctl
	if map_b.size == Vector2.ZERO: _map_setup()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.4))
	var pts := PackedVector2Array()
	var step := 3
	for i in range(0, main.trk_pts.size(), step): pts.append(_mp(main.trk_pts[i]))
	if pts.size() > 1: c.draw_polyline(pts, Color(0.95, 0.85, 0.65, 0.85), 3.0, true)
	for br in main.branches:
		var bp := PackedVector2Array(); for p in (br["pts"] as PackedVector2Array): bp.append(_mp(p))
		if bp.size() > 1: c.draw_polyline(bp, Color(1.0, 0.55, 0.2, 0.95), 2.0, true)
	var s0: float = main.s0 if main.s0 >= 0.0 else 0.0
	c.draw_circle(_mp((main._track_at(s0) as Array)[0]), 5.0, Color(0.3, 1.0, 0.4))
	c.draw_circle(_mp((main._track_at(s0 + main.race_len) as Array)[0]), 5.0, Color(1.0, 0.25, 0.2))
	for b in main.bots:
		var q := (b["rb"] as RigidBody3D).global_position
		c.draw_circle(_mp(Vector2(q.x, q.z)), 3.0, Color(0.6, 0.75, 1.0, 0.9) if not b["fin"] else Color(0.6, 0.6, 0.6, 0.6))
	var sp: Vector3 = main.ship.global_position; var fw: Vector3 = -main.ship.global_transform.basis.z
	var pp := _mp(Vector2(sp.x, sp.z)); var d := Vector2(fw.x, fw.z).normalized()
	var n := Vector2(-d.y, d.x)
	c.draw_colored_polygon(PackedVector2Array([pp + d * 9.0, pp - d * 6.0 + n * 5.0, pp - d * 6.0 - n * 5.0]), Color(1, 1, 1))

func _ovp(p: Vector2) -> Vector2:
	return ov_off + (p - map_b.position) * ov_sc

func _draw_ov() -> void:                                                    # заставка: общий план всей трассы, маршрут прорисовывается от старта к финишу
	var u: float = main.intro_t(); var c := ov_ctl
	var a := 1.0 - smoothstep(5.8, 7.0, u)
	if a <= 0.0: return
	if map_b.size == Vector2.ZERO: _map_setup()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.02, 0.012, 0.008, 0.66 * a))
	var area := Rect2(c.size.x * 0.07, c.size.y * 0.17, c.size.x * 0.86, c.size.y * 0.68)
	ov_sc = minf(area.size.x / maxf(map_b.size.x, 1.0), area.size.y / maxf(map_b.size.y, 1.0))
	ov_off = area.position + (area.size - map_b.size * ov_sc) * 0.5
	var rev := smoothstep(0.0, 1.0, clampf(u / 4.6, 0.0, 1.0))
	var n: int = int(main.trk_pts.size() * rev)
	var pts := PackedVector2Array()
	for i in range(0, n, 3): pts.append(_ovp(main.trk_pts[i]))
	if pts.size() > 1: c.draw_polyline(pts, Color(0.97, 0.88, 0.68, a), 5.0, true)
	var ba := clampf((u - 3.2) / 1.4, 0.0, 1.0) * a
	if ba > 0.0:
		for br in main.branches:
			var bp := PackedVector2Array(); for p in (br["pts"] as PackedVector2Array): bp.append(_ovp(p))
			if bp.size() > 1: c.draw_polyline(bp, Color(1.0, 0.54, 0.12, ba), 4.0, true)
	var f := ThemeDB.fallback_font
	var s0: float = main.s0 if main.s0 >= 0.0 else 0.0
	var ps := _ovp((main._track_at(s0) as Array)[0]); var pf2 := _ovp((main._track_at(s0 + main.race_len) as Array)[0])
	c.draw_circle(ps, 9.0, Color(0.3, 1.0, 0.4, a)); c.draw_string(f, ps + Vector2(14, -10), "СТАРТ", HORIZONTAL_ALIGNMENT_LEFT, 300, 28, Color(0.3, 1.0, 0.4, a))
	if rev > 0.92:
		var fa := clampf((rev - 0.92) / 0.08, 0.0, 1.0) * a
		c.draw_circle(pf2, 9.0, Color(1.0, 0.3, 0.2, fa)); c.draw_string(f, pf2 + Vector2(14, -10), "ФИНИШ", HORIZONTAL_ALIGNMENT_LEFT, 300, 28, Color(1.0, 0.3, 0.2, fa))
	c.draw_string(f, Vector2(c.size.x * 0.07, c.size.y * 0.12), "ТРАССА · %d КМ" % int(round(main.race_len / 1000.0)), HORIZONTAL_ALIGNMENT_LEFT, 900, 46, Color(1.0, 0.54, 0.12, a))
	if ba > 0.0: c.draw_string(f, Vector2(c.size.x * 0.07, c.size.y * 0.89), "оранжевым — срезки", HORIZONTAL_ALIGNMENT_LEFT, 700, 26, Color(1.0, 0.54, 0.12, ba))

# ---------- Меню / пауза ----------
# Страницы: main (меню/пауза) → settings → controls (→ keys, advanced → organ:<ключ>) | sound | camera
var page := "main"
var scroll: ScrollContainer
var vbox: VBoxContainer
var page_lbl: Label
var plot: Control
var fl_pad := 0
var fl_kb := 0
var pm_sel := ""                     # экран «Кнопки геймпада»: id выбранного элемента (открыт список действий)
var pm_cur := "a4"                   # курсор с клавиатуры
var pm_opt := 0
var pm_top := 0
var pm_frame := -1
var pm_lat := {}                     # оси, которые уже сработали и ещё не вернулись в ноль
var pm_msg := ""
var pm_msg_t := 0.0
var capturing := ""                    # id действия, для которого ждём нажатие клавиши
var opened_frame := -1
const ORGAN_SHORT := {"thr": "Газ (тяговые моторы)", "pitch": "Тангаж", "yaw": "Рыскание", "roll": "Крен", "shunt": "Маневровые (вектор)", "boost": "Усиление маневровых", "lift": "Взлётные моторы"}

class PlotCtl extends Control:
	var ui
	func _init() -> void:
		custom_minimum_size = Vector2(560, 520); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if not ui.page.begins_with("organ:"): return
		var organ: String = ui.page.substr(6)
		var tn = ui.main.tune
		var f := ThemeDB.fallback_font
		var s: float = tn.v[organ + ".start"]; var mx: float = tn.v[organ + ".max"]
		var t: float = tn.time_of(organ)
		var lo := minf(0.0, minf(s, mx)); var hi := maxf(0.0, maxf(s, mx))
		if hi - lo < 0.0001: hi = lo + 1.0
		var titles := ["Стик / курок геймпада: усилие по отклонению", "Кнопка геймпада / клавиша-стрелка: усилие по времени удержания"]
		for pi in 2:
			var oy := pi * 270.0
			draw_rect(Rect2(0, oy, 560, 250), Color(0.04, 0.025, 0.015, 0.78))
			draw_string(f, Vector2(10, oy + 20), titles[pi], HORIZONTAL_ALIGNMENT_LEFT, 540, 15, Color(1.0, 0.78, 0.4))
			var r := Rect2(54, oy + 34, 490, 170)
			for i in 11:
				var x := r.position.x + r.size.x * i / 10.0
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.10 if i % 5 else 0.25))
				var y := r.position.y + r.size.y * i / 10.0
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.10 if i % 5 else 0.25))
			for i: int in [0, 5, 10]:
				var val: float = lo + (hi - lo) * i / 10.0
				draw_string(f, Vector2(6, r.end.y - r.size.y * i / 10.0 + 4), "%.2f" % val, HORIZONTAL_ALIGNMENT_LEFT, 46, 12, Color(0.8, 0.8, 0.8))
				var xv := (1.0 * i / 10.0) if pi == 0 else (t * i / 10.0)
				draw_string(f, Vector2(r.position.x + r.size.x * i / 10.0 - 12, r.end.y + 16), "%.2f" % xv, HORIZONTAL_ALIGNMENT_LEFT, 40, 12, Color(0.8, 0.8, 0.8))
			draw_string(f, Vector2(r.position.x, r.end.y + 36), "отклонение 0…1" if pi == 0 else "время удержания, с", HORIZONTAL_ALIGNMENT_LEFT, 490, 12, Color(0.65, 0.65, 0.65))
			var dz: float = clampf(float(ui.main.cfg["deadzone"]), 0.0, 0.9) if pi == 0 else 0.0
			if dz > 0.0:
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x * dz, r.size.y), Color(0.9, 0.25, 0.2, 0.22))
				draw_string(f, Vector2(r.position.x + 4, r.position.y + 14), "мёртвая зона", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(1, 0.55, 0.5))
			var pts := PackedVector2Array()
			for i in 81:
				var u := i / 80.0
				var e: float = tn.effort(organ, maxf(u, 0.0001)) if i > 0 else s
				pts.append(Vector2(r.position.x + r.size.x * (dz + (1.0 - dz) * u), r.end.y - r.size.y * (e - lo) / (hi - lo)))
			draw_polyline(pts, Color(1, 0.8, 0.25), 2.5)
			draw_circle(pts[0], 5, Color(0.4, 1, 0.5)); draw_circle(pts[80], 5, Color(1, 0.4, 0.4))

func _build_menu() -> void:
	dim = ColorRect.new(); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.color = Color(0.05, 0.03, 0.02, 0.22); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(dim)
	menu_panel = Control.new(); menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT); menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(menu_panel)
	side = ColorRect.new(); side.position = Vector2(0, 0); side.size = Vector2(760, 2000); side.color = Color(0.04, 0.025, 0.015, 0.72); side.mouse_filter = Control.MOUSE_FILTER_IGNORE; menu_panel.add_child(side)
	title_lbl = _lbl("КАРНАВАЛЬСКАЯ\nГОНКА", 76, CREAM, menu_panel, Vector2(90, 70))
	sub_lbl = _lbl("Космоолухи · демо-прототип", 26, ORANGE, menu_panel, Vector2(96, 290))
	page_lbl = _lbl("", 38, ORANGE, menu_panel, Vector2(90, 40)); page_lbl.custom_minimum_size = Vector2(620, 0); page_lbl.size = Vector2(620, 90); page_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll = ScrollContainer.new(); scroll.position = Vector2(90, 330); scroll.size = Vector2(640, 380); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE; menu_panel.add_child(scroll)
	vbox = VBoxContainer.new(); vbox.custom_minimum_size = Vector2(620, 0); vbox.add_theme_constant_override("separation", 8); vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE; scroll.add_child(vbox)
	desc_lbl = _lbl("", 20, Color(1, 1, 1, 0.75), menu_panel, Vector2(96, 730))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc_lbl.custom_minimum_size = Vector2(620, 0); desc_lbl.size = Vector2(620, 80)
	hint_lbl = _lbl("↑↓ выбор    A / Enter подтвердить    ◀ ▶ изменить    B / Esc назад", 18, Color(1, 1, 1, 0.5), menu_panel, Vector2(96, 842))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint_lbl.custom_minimum_size = Vector2(620, 0); hint_lbl.size = Vector2(620, 40)
	plot = PlotCtl.new(); plot.ui = self; plot.position = Vector2(800, 120); menu_panel.add_child(plot)

func _bool_item(label: String, key: String, hint := "") -> Dictionary:
	return {"t": "%s:  %s" % [label, "ВКЛ" if main.cfg[key] else "выкл"], "l": label, "kind": "toggle", "on": bool(main.cfg[key]), "d": hint, "a": func(): _tog(key), "s": func(_d): _tog(key)}

func _num_item(label: String, get_v: Callable, set_v: Callable, step: float, lo: float, hi: float, hint := "", fmt := "%.2f") -> Dictionary:
	var stepf := func(d: int): set_v.call(clampf(snappedf(float(get_v.call()) + d * step, step * 0.01), lo, hi))
	return {"t": ("%s:  ◀ " + fmt + " ▶") % [label, get_v.call()], "l": label, "kind": "slider", "pct": (float(get_v.call()) - lo) / maxf(hi - lo, 0.0001), "vtxt": fmt % get_v.call(), "tw": 300.0, "d": hint, "a": func(): stepf.call(1), "s": stepf}

func _tv_item(label: String, key: String, step: float, lo: float, hi: float, hint := "", fmt := "%.2f") -> Dictionary:
	return _num_item(label, func(): return main.tune.v[key], func(x): _set_tv(key, x), step, lo, hi, hint, fmt)

func _page_items() -> Array:
	var lv: String = main.LEVEL_NAMES[main._lvl()]
	var lvl_item := {"t": "Сложность:  ◀ %s ▶" % lv, "l": "Сложность", "kind": "choice", "val": lv, "cw": 300.0, "cfs": 26, "d": main.LEVEL_TAGS[main._lvl()] + "\n" + LEVEL_DESC[main._lvl()], "s": func(d): _change_level(d), "a": func(): _change_level(1), "id": "level"}
	var sid: int = clampi(int(main.cfg.get("ship", 0)), 0, main.SHIP_NAMES.size() - 1)
	var ship_item := {"t": "Корабль:  ◀ %s ▶" % main.SHIP_NAMES[sid], "l": "Корабль", "kind": "choice", "val": main.SHIP_NAMES[sid], "cw": 300.0, "cfs": 26, "d": main.SHIP_DESC[sid], "s": func(d): _change_ship(d), "a": func(): _change_ship(1), "id": "ship"}
	var back := {"t": "Назад", "a": func(): back_page()}
	var it: Array = []
	match page:
		"main":
			if state == "menu":
				it = [{"t": "Старт", "a": func(): _start_race()}, lvl_item, ship_item, {"t": "Достижения", "kind": "action", "a": func(): goto_page("ach")}, {"t": "Настройки", "kind": "action", "a": func(): goto_page("settings")}, {"t": "Об игре", "kind": "action", "a": func(): goto_page("about")}, {"t": "Выход", "a": func(): goto_page("exit")}]
			elif state == "pause":
				it = [{"t": "Продолжить", "a": func(): close_pause()}, {"t": "Начать заново", "a": func(): _restart()}, {"t": "Вернуть на трассу  (+20 с)", "a": func(): close_pause(); main._unstick()}, lvl_item, {"t": "Настройки", "kind": "action", "a": func(): goto_page("settings")}, {"t": "В главное меню", "a": func(): _to_menu()}]
		"exit":
			it = [{"t": "Да, выйти", "a": func(): _quit_game()}, {"t": "Остаться", "a": func(): grant("timid"); back_page()}]
		"link":
			it = [{"t": "Закрыть", "a": func(): back_page()}, {"t": "Перейти", "a": func(): OS.shell_open(String(link_cur.get("url", ""))); back_page()}]
		"project":
			for ps in PROJECT_SECTIONS: it.append({"t": ps["t"], "body": ps["body"]})
		"about":
			it = [{"role": "Проект", "name": "Планы и режимы…", "d": "A — подробнее о проекте", "a": func(): goto_page("project")}, {"role": "Гейм-дизайн", "name": "Harvester", "tg": "https://t.me/another_test_subject", "d": "A — Telegram-канал", "a": func(): open_link("Telegram-канал Harvester", "https://t.me/another_test_subject", "tg")}, {"role": "Программист", "name": "Claude"},
				{"role": "Музыка", "name": "Re:Cycle", "links": true, "lk": about_link, "d": "◀ ▶ выбрать ссылку, A открыть", "s": func(d): about_link = posmod(about_link + d, 2), "a": func(): open_link(["Re:Cycle — VK", "Re:Cycle — SoundCloud"][about_link], LINKS[about_link], ["vk_music", "soundcloud"][about_link])}]
		"ach":
			var got: Dictionary = main.cfg.get("ach", {})
			for a in ACH:
				var has: bool = got.has(a["id"])
				it.append({"id": a["id"], "title": a["title"], "cond": a["cond"], "st": "got" if has else ("hidden" if a.get("hidden", false) else "lock"), "when": String(got.get(a["id"], "")), "prog": "" if has else _ach_prog(String(a["id"]))})
		"settings":
			it = [{"t": "Управление", "kind": "action", "a": func(): goto_page("controls")}, {"t": "Звук", "kind": "action", "a": func(): goto_page("sound")}, {"t": "Камера", "kind": "action", "a": func(): goto_page("camera")}, back]
		"controls":
			it = [{"t": "Схема геймпада:  ◀ %d ▶" % (main.scheme + 1), "l": "Схема геймпада", "kind": "choice", "val": "%d" % (main.scheme + 1), "cw": 80.0, "cfs": 28, "d": "Схема 1: левый стик — тангаж (вверх-вниз) и крен (влево-вправо), бамперы LB/RB — рыскание, правый стик — маневровые (всё переназначается). Схема 2: каждый стик управляет своим бортом маневровых.", "s": func(_d): _flip_scheme(), "a": func(): _flip_scheme()},
				_bool_item("Левый стик, влево-вправо: инверсия", "inv_lx"), _bool_item("Левый стик, вверх-вниз: инверсия", "inv_ly"),
				_bool_item("Правый стик, влево-вправо: инверсия", "inv_rx"), _bool_item("Правый стик, вверх-вниз: инверсия", "inv_ry"),
				_bool_item("Клавиатура: инверсия тангажа (стрелки вверх-вниз)", "inv_kb_pitch"),
				_num_item("Мёртвая зона стиков", func(): return float(main.cfg["deadzone"]), func(x): _set_cfg("deadzone", x), 0.01, 0.0, 0.4, "Отклонение стика, меньше которого он считается нулевым."),
				{"t": "Кнопки геймпада…", "kind": "action", "d": "Переназначение стиков, курков и кнопок геймпада: тангаж, крен, рыскание, газ и другие.", "a": func(): goto_page("pad")},
				{"t": "Клавиши клавиатуры…", "kind": "action", "d": "Переназначение клавиш: газ, взлётные, повороты, маневровые, камера и другие.", "a": func(): goto_page("keys")},
				{"t": "Расширенные…", "kind": "action", "d": "Степень нажатия: как растёт усилие от отклонения стика или от времени удержания кнопки.", "a": func(): goto_page("advanced")},
				{"t": "Сбросить кнопки геймпада", "d": "Вернуть кнопки и стики геймпада к значениям по умолчанию. Инверсии, схема и клавиши клавиатуры не меняются.", "a": func(): _reset_pad()},
				{"t": "Сбросить управление", "d": "Вернуть инверсии, схему, мёртвую зону и клавиши к значениям по умолчанию.", "a": func(): _reset_controls()}, back]
		"pad":
			for pb in main.PADBIND:
				var pid: String = pb[0]
				var pcap: bool = capturing == "pad:" + pid
				it.append({"t": "%s:  %s" % [pb[1], "нажмите кнопку или отклоните стик…" if pcap else main.pad_name(main.pad[pid])], "l": pb[1], "kind": "value", "val": "нажмите кнопку…" if pcap else main.pad_name(main.pad[pid]), "cap": pcap, "d": "A / Enter — выбрать, затем нажать кнопку, курок или отклонить стик. Esc или Start — отмена. Если назначение занято, действия поменяются местами.", "a": func(): capturing = "pad:" + pid; _refresh_items()})
			it.append({"t": "Сбросить кнопки геймпада", "a": func(): _reset_pad()})
			it.append(back)
		"keys":
			for kb in main.KEYBIND:
				var id: String = kb[0]
				var cap: bool = capturing == id
				it.append({"t": "%s:  %s" % [kb[1], "нажмите клавишу…" if cap else OS.get_keycode_string(main.keys[id]).to_upper()], "l": kb[1], "kind": "value", "val": "нажмите клавишу…" if cap else OS.get_keycode_string(main.keys[id]).to_upper(), "cap": cap, "d": "Enter / A — выбрать, затем нажать новую клавишу. Esc — отмена. Если клавиша занята, действия поменяются клавишами.", "a": func(): capturing = id; _refresh_items()})
			it.append({"t": "Сбросить клавиши", "a": func(): _reset_keys()})
			it.append(back)
		"advanced":
			for o in main.tune.ORGANS:
				var key: String = o[0]
				it.append({"t": ORGAN_SHORT.get(key, o[1]), "kind": "action", "d": o[2], "a": func(): goto_page("organ:" + key)})
			it.append({"t": "Сбросить все кривые", "d": "Вернуть степень нажатия всех органов к значениям по умолчанию.", "a": func(): _reset_organ(""), "d2": ""})
			it.append(back)
		"sound":
			it = [_num_item("Общая громкость", func(): return float(main.cfg["vol"]), func(x): _set_vol(x), 0.1, 0.0, 1.0, "Общая громкость игры.", "%.1f"),
				_num_item("Музыка в гонке", func(): return float(main.cfg["music"]), func(x): _set_music(x), 0.1, 0.0, 1.0, "Громкость музыки во время гонки и вступления.", "%.1f"),
				_num_item("Музыка в меню", func(): return float(main.cfg["menu_music"]), func(x): _set_menu_music(x), 0.1, 0.0, 1.0, "Громкость музыки в главном меню и на экране результатов.", "%.1f"),
				_num_item("Звуки корабля", func(): return float(main.cfg["ship_sfx"]), func(x): _set_cfg("ship_sfx", x), 0.1, 0.0, 1.0, "Гул моторов, маневровые, сигнал приближения к земле и взрывы при ударах.", "%.1f"),
				_num_item("Звуки интерфейса", func(): return float(main.cfg["sfx"]), func(x): _set_sfx(x), 0.1, 0.0, 1.0, "Щелчки, переключатели и сигналы меню.", "%.1f"), back]
		"camera":
			var cvn: String = main.CAM_NAMES[clampi(int(main.cfg["cam_view"]), 0, main.CAM_NAMES.size() - 1)]
			it = [{"t": "Вид камеры:  ◀ %s ▶" % cvn, "l": "Вид камеры", "kind": "choice", "val": cvn, "cw": 320.0, "cfs": 26, "d": "Какой вид камеры включается в начале гонки. Во время гонки его можно менять клавишей камеры. «От первого лица» — из кабины, камера жёстко закреплена на корабле.", "s": func(d): _change_cam_view(d), "a": func(): _change_cam_view(1)},
				_tv_item("Плавность следования камеры", "cam_smooth", 0.1, 0.0, 5.0, "0 — жёсткая камера, больше — плавнее отстаёт от корабля.", "%.1f"),
				_tv_item("Тряска камеры", "cam_shake", 0.1, 0.0, 2.0, "Тряска только при очень больших ускорениях (свыше ≈50 g) и при ударах. 0 — без тряски.", "%.1f"),
				_bool_item("Вибрация геймпада при ударах", "rumble", "Короткая вибрация геймпада при столкновениях; сила зависит от удара."), back]
		_:
			if page.begins_with("organ:"):
				var o: String = page.substr(6)
				it = [_tv_item("Стартовое усилие", o + ".start", 0.05, 0.0, 5.0, "Усилие в момент нажатия (стик: как только вышел из мёртвой зоны)."),
					_tv_item("Максимальное усилие", o + ".max", 0.05, 0.0, 5.0, "Усилие при полном отклонении стика или после полного времени удержания."),
					_tv_item("Время до максимума, с (кнопки, стрелки)", o + ".time", 0.05, 0.05, 3.0, "Сколько держать кнопку или клавишу, чтобы дойти до максимума. Для стиков не используется."),
					{"t": "Кривая:  ◀ %s ▶" % main.tune.FN_NAMES[int(main.tune.v[o + ".fn"])], "l": "Кривая", "kind": "choice", "val": String(main.tune.FN_NAMES[int(main.tune.v[o + ".fn"])]), "cw": 280.0, "cfs": 26, "d": "Линейная, экспоненциальная (вначале мягко, в конце резко) или логарифмическая (вначале резко).", "a": func(): _fn_step(o, 1), "s": func(d): _fn_step(o, d)},
					_tv_item("Крутизна кривой", o + ".k", 0.5, 0.5, 10.0, "Для экспоненты и логарифма: больше — круче изгиб. У линейной не используется.", "%.1f"),
					{"t": "Сбросить эту кривую", "a": func(): _reset_organ(o)}, back]
	return it

func _quit_game() -> void:
	if int(_stats().get("starts", 0)) == 0 and not has_ach("not_mine"):          # «Это не моё»: за всё время не начато ни одной гонки
		grant("not_mine")
		await get_tree().create_timer(1.6, true, false, true).timeout        # дать увидеть плашку и услышать звук
	get_tree().quit()

func _ach_prog(id: String) -> String:
	var st := _stats()
	match id:
		"klutz": return "%d / 10" % int(st.get("dsq_streak", 0))
		"pilot_test": return "%d / %d" % [_sarr("ships_done").size(), main.SHIP_NAMES.size()]
		"academy": return "%d / 5" % _sarr("levels_done").size()
		"melomaniac": return "%d / %d" % [_sarr("heard").size(), MUSIC_ALL.size()]
		"tester": return "%d / %d" % [_sarr("screens").size(), _screens_total()]
		"km1000": return "%d / 20000 км" % int(float(st.get("km", 0.0)))
		"graveyard": return "%d / %d" % [_sarr("wrecked").size(), main.SHIP_NAMES.size()]
		"connoisseur":
			var gt: Dictionary = main.cfg.get("ach", {}); var c4 := 0
			for k4 in ["academy", "pilot_test", "melomaniac"]: if gt.has(k4): c4 += 1
			if bool(st.get("cutscene", false)): c4 += 1
			return "%d / 4" % c4
		"vet25": return "%d / 25" % int(st.get("finishes", 0))
		"collector": return "%d / 20" % mini(_ach_count_others(), 20)
	return ""

func _tog(key: String) -> void:
	main.cfg[key] = not main.cfg[key]; main._save_cfg()

func _set_tv(key: String, x: float) -> void:
	main.tune.v[key] = x; main.tune.save_file()

func _set_cfg(key: String, x) -> void:
	main.cfg[key] = x; main._save_cfg()

func _set_music(x: float) -> void:
	_set_cfg("music", x); main.music.refresh()

func _set_menu_music(x: float) -> void:
	_set_cfg("menu_music", x); main.music.refresh()

func _set_sfx(x: float) -> void:
	_set_cfg("sfx", x)

func _flip_scheme() -> void:
	main.scheme = 1 - main.scheme; main._save_cfg()

func _set_vol(x: float) -> void:
	main.cfg["vol"] = x; main._save_cfg(); _apply_volume()

func _reset_keys() -> void:
	for kb in main.KEYBIND: main.keys[kb[0]] = kb[2]
	main.apply_keys(); main._save_cfg()

func _reset_organ(o: String) -> void:
	if o == "": main.tune.reset_organs()
	else: main.tune.reset_organ(o)
	main.tune.save_file()

func _show_sel(c) -> void:
	if is_instance_valid(c) and c.is_inside_tree(): scroll.ensure_control_visible(c)

func _fn_step(o: String, d: int) -> void:
	main.tune.v[o + ".fn"] = float(posmod(int(main.tune.v[o + ".fn"]) + d, 3)); main.tune.save_file()

func _apply_volume() -> void:
	var v: float = float(main.cfg["vol"])
	AudioServer.set_bus_mute(0, v <= 0.001); AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))

func _reset_pad() -> void:
	main._load_pad(); main.apply_pad(); main._save_cfg(); _refresh_items()

func _reset_controls() -> void:
	for k in ["inv_lx", "inv_ly", "inv_rx", "inv_ry", "swap_roll", "inv_kb_pitch"]: main.cfg[k] = false
	main._load_pad(); main.apply_pad()
	main.cfg["deadzone"] = 0.12; main.scheme = 0
	for kb in main.KEYBIND: main.keys[kb[0]] = kb[2]
	main.apply_keys(); main._save_cfg()

func goto_page(p: String) -> void:
	page = p; sel = 0; capturing = ""; pm_sel = ""; pm_cur = "a4"; _refresh_items(); _visit(p)

func back_page() -> void:
	capturing = ""; pm_sel = ""; sfx.play("back"); check_custom()
	var parent := {"settings": "main", "controls": "settings", "sound": "settings", "camera": "settings", "keys": "controls", "pad": "controls", "advanced": "controls", "ach": "main", "about": "main", "project": "about", "link": "about", "exit": "main"}
	if page.begins_with("organ:"): page = "advanced"
	elif page == "main": return
	else: page = parent.get(page, "main")
	sel = 0; _refresh_items()
	if main.tune != null: main.tune.save_file()
	main._save_cfg()

func _page_title() -> String:
	match page:
		"settings": return "НАСТРОЙКИ"
		"controls": return "НАСТРОЙКИ › УПРАВЛЕНИЕ"
		"keys": return "УПРАВЛЕНИЕ › КЛАВИШИ"
		"pad": return "УПРАВЛЕНИЕ › ГЕЙМПАД"
		"advanced": return "УПРАВЛЕНИЕ › РАСШИРЕННЫЕ"
		"sound": return "НАСТРОЙКИ › ЗВУК"
		"camera": return "НАСТРОЙКИ › КАМЕРА"
		"ach": return "ДОСТИЖЕНИЯ"
		"about": return "ОБ ИГРЕ"
		"project": return "ОБ ИГРЕ › О ПРОЕКТЕ"
		"link": return "ОТКРЫТЬ ССЫЛКУ?"
		"exit": return "ВЫ УВЕРЕНЫ?"
	if page.begins_with("organ:"): return "РАСШИРЕННЫЕ › " + String(ORGAN_SHORT.get(page.substr(6), page.substr(6))).to_upper()
	return ""

func _refresh_items() -> void:
	if state == "results":
		items = [{"t": "Ещё раз", "id": "again"}, {"t": "В главное меню", "id": "tomenu"}]
		sel = clampi(sel, 0, items.size() - 1)
		skin.items = items; skin.sel = sel; skin.mode = "results"; skin.hint_btns = [{"k": "pad", "g": "↑↓", "l": "Выбор"}, {"k": "A", "g": "", "l": "Выбрать"}]
		for i in res_btns.size():
			var l: Label = res_btns[i]; l.text = ("▶ " if i == sel else "   ") + items[i]["t"]; l.add_theme_color_override("font_color", ORANGE if i == sel else CREAM)
		return
	items = _page_items()
	sel = clampi(sel, 0, maxi(items.size() - 1, 0))
	_sync_skin()
	var sub := page != "main"
	title_lbl.visible = (state == "menu" and not sub) or (state == "pause" and not sub)
	sub_lbl.visible = state == "menu" and not sub
	page_lbl.visible = sub; page_lbl.text = _page_title()
	side.size = Vector2(3000, 2000) if sub else Vector2(760, 2000); side.color = Color(0, 0, 0, 1) if sub else Color(0.04, 0.025, 0.015, 0.72)
	scroll.position = Vector2(90, 150 if sub else 330); scroll.size = Vector2(640, 560 if sub else 380)
	plot.visible = page.begins_with("organ:"); plot.queue_redraw()
	for c in vbox.get_children(): vbox.remove_child(c); c.queue_free()
	var cur: Label = null
	for i in items.size():
		var l := _lbl(("▶ " if i == sel else "    ") + String(items[i].get("t", "")), 34 if not sub else 28, ORANGE if i == sel else CREAM, vbox)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(620, 0)
		if i == sel: cur = l
	if cur != null: _show_sel.call_deferred(cur)
	desc_lbl.text = String(items[sel].get("d", "")) if items.size() > 0 else ""

func _sync_skin() -> void:                                                 # данные для оформления меню v2 (menu_skin.gd)
	if skin == null: return
	var bt := func(k: String, g: String, l: String) -> Dictionary: return {"k": k, "g": g, "l": l}
	skin.items = items; skin.sel = sel
	skin.hint = String(items[sel].get("d", "")) if items.size() > 0 else ""
	var ud: Array = [bt.call("pad", "↑↓", "Выбор")]
	skin.title = _page_title(); skin.rows_w = 1000.0
	if plot != null and plot.get_parent() != skin: plot.get_parent().remove_child(plot); skin.add_child(plot)
	plot.visible = page.begins_with("organ:")
	if plot.visible: plot.position = Vector2(860, 224); skin.rows_w = 720.0
	match page:
		"main":
			if state == "menu":
				skin.mode = "main"; skin.bg_key = MenuSkin.MAIN_BG[clampi(sel, 0, MenuSkin.MAIN_BG.size() - 1)]
				skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("pad", "◀▶", "Изменить"), bt.call("A", "", "Выбрать")]
				if sel == 1:
					var lvn: int = main._lvl()
					skin.card = {"n": lvn + 1, "total": 5, "name": main.LEVEL_NAMES[lvn], "slogan": main.LEVEL_TAGS[lvn], "desc": LEVEL_DESC[lvn], "pic": load("res://menu_v2/levels/level_%d.png" % (lvn + 1))}
				elif sel == 2:
					var sid: int = clampi(int(main.cfg.get("ship", 0)), 0, main.SHIP_NAMES.size() - 1)
					skin.card = {"n": sid + 1, "total": main.SHIP_NAMES.size(), "name": main.SHIP_NAMES[sid], "slogan": main.SHIP_SLOGANS[sid], "desc": main.SHIP_DESC[sid], "pic": load("res://menu_v2/ship_%d.png" % sid)}
			else:
				skin.mode = "pause"; skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("A", "", "Выбрать"), bt.call("B", "", "Продолжить")]
		"about":
			var vi := Engine.get_version_info()
			skin.mode = "about"; skin.card = {"version": "демо-прототип · версия 0.1", "about": ABOUT_TEXT % ("%d.%d" % [vi["major"], vi["minor"]])}
			skin.hint = "Отзывы и баги: kolyanasd@gmail.com  ·  GitHub: скоро"
			skin.hint_btns = [bt.call("pad", "◀▶", "Ссылка"), bt.call("A", "", "Открыть ссылку"), bt.call("B", "", "Назад")]
		"link":
			skin.mode = "linkdlg"; skin.hint = String(link_cur.get("url", ""))
			skin.card = {"name": String(link_cur.get("name", "")), "qr": load("res://menu_v2/qr/%s.png" % String(link_cur.get("qr", "tg")))}
			skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("A", "", "Выбрать"), bt.call("B", "", "Закрыть")]
		"project":
			skin.mode = "project"; skin.hint = "Режимы, трасса, ограничения демо и планы на Unreal."
			skin.hint_btns = [bt.call("pad", "↑↓", "Раздел"), bt.call("B", "", "Назад")]
		"exit":
			skin.mode = "dialog"; skin.hint = "Игра закроется, несохранённого ничего нет."
			skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("A", "", "Выбрать"), bt.call("B", "", "Назад")]
		"pad":
			skin.mode = "padmap"
		"ach":
			skin.mode = "ach"; skin.hint = "Закрытые грамоты показывают условие. Скрытые откроются сами."
			skin.hint_btns = [bt.call("pad", "↑↓◀▶", "Выбор"), bt.call("B", "", "Назад")]
			if not Input.is_action_pressed("ui_accept"): pass
		_:
			skin.mode = "page"
			skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("pad", "◀▶", "Изменить"), bt.call("A", "", "Выбрать"), bt.call("B", "", "Назад")]

# ---------- Достижения ----------
func _ach_on() -> bool: return main.ui_shot == "" and not (main.evo_mode or main.test_mode or main.soak)

func _stats() -> Dictionary:
	var st = main.cfg.get("stats", {})
	if not (st is Dictionary): st = {}
	main.cfg["stats"] = st
	return st

func _sarr(key: String) -> Array:
	var st := _stats()
	if not st.has(key) or not (st[key] is Array): st[key] = []
	return st[key]

func _sadd(key: String, v) -> bool:                                          # добавить в множество статистики; true, если значение новое
	var a := _sarr(key)
	if a.has(v): return false
	a.append(v); return true

func has_ach(id: String) -> bool: return (main.cfg.get("ach", {}) as Dictionary).has(id)

func grant(id: String, ctx := "") -> void:                                   # выдать достижение сразу (не на экране финиша): всплывающая плашка и сохранение
	if not _ach_on() or has_ach(id): return
	var got: Dictionary = main.cfg.get("ach", {}); var dt := Time.get_datetime_dict_from_system()
	got[id] = "%02d.%02d.%d%s" % [dt["day"], dt["month"], dt["year"], (" · " + ctx) if ctx != "" else ""]
	main.cfg["ach"] = got; main._save_cfg()
	for a in ACH: if a["id"] == id: _toast("Достижение: " + String(a["title"])); break
	sfx.play("unlock")
	if id != "collector" and id != "connoisseur": _check_derived()

var toast_lbl: Label
var toast_t := 0.0
func _apply_tamper() -> void:                                                # файл прогресса правили руками: рекорды и достижения уже обнулены, выдаём единственное достижение
	if not main.tamper_flag: return
	main.tamper_flag = false; grant("hacker", "прогресс обнулён")

func _ach_count_others() -> int:                                              # сколько получено достижений, кроме самого «Коллекционера»
	var n := 0
	for k in (main.cfg.get("ach", {}) as Dictionary): if String(k) != "collector": n += 1
	return n

func _derived_ok(id: String, got: Dictionary) -> bool:                       # достижения, которые зависят от других достижений
	match id:
		"connoisseur": return got.has("academy") and got.has("pilot_test") and got.has("melomaniac") and bool(_stats().get("cutscene", false))
		"collector":
			var n := 0
			for k in got: if String(k) != "collector": n += 1
			return n >= 20
	return false

func _check_derived() -> void:
	var got: Dictionary = main.cfg.get("ach", {})
	for did in ["connoisseur", "collector"]: if not got.has(did) and _derived_ok(did, got): grant(did); got = main.cfg.get("ach", {})

func cutscene_seen() -> void:                                                # катсцена досмотрена до конца (без пропуска)
	if not _ach_on() or bool(_stats().get("cutscene", false)): return
	_stats()["cutscene"] = true; main._save_cfg(); _check_derived()

func ship_wrecked(sid: int) -> void:                                         # корабль полностью уничтожен (без кнопки «взорвать всё»)
	if not _ach_on(): return
	if _sadd("wrecked", sid):
		main._save_cfg()
		if _sarr("wrecked").size() >= main.SHIP_NAMES.size(): grant("graveyard")

func _toast(txt: String) -> void:
	if toast_lbl == null:
		toast_lbl = _lbl("", 28, ORANGE, root, Vector2(0, 22)); toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP); toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toast_lbl.anchor_left = 0.0; toast_lbl.anchor_right = 1.0; toast_lbl.offset_left = 0.0; toast_lbl.offset_right = 0.0; toast_lbl.offset_top = 22.0
		toast_lbl.add_theme_constant_override("outline_size", 8); toast_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_lbl.text = txt; toast_lbl.visible = true; toast_lbl.modulate.a = 1.0; toast_t = Time.get_ticks_msec() / 1000.0 + 4.0

func on_track_done(file: String) -> void:                                    # трек доигран до конца
	if not _ach_on(): return
	if _sadd("heard", file):
		main._save_cfg()
		var all := true
		for f in MUSIC_ALL: if not _sarr("heard").has(f): all = false
		if all: grant("melomaniac")

func _check_platform() -> void:
	if main.tamper_flag: return                                              # после наказания за правку файла выдаётся только «Мамкин хацкер»
	var id: String = OS_ACH.get(OS.get_name(), "")
	if id != "": grant(id)

func _visit(p: String) -> void:                                              # экран меню посещён
	if not _ach_on(): return
	if _sadd("screens", p): main._save_cfg()
	_check_tester()

func _screens_total() -> int:
	var n := PAGES_ALL.size()
	for o in main.tune.ORGANS: n += 1
	return n

func _check_tester() -> void:
	var seen := _sarr("screens")
	for p in PAGES_ALL: if not seen.has(p): return
	for o in main.tune.ORGANS: if not seen.has("organ:" + String(o[0])): return
	if int(_stats().get("races", 0)) >= 1: grant("tester")

func check_custom() -> void:                                                 # управление и продвинутые настройки отличаются от стандартных
	if not _ach_on(): return
	var changed := false
	for kb in main.KEYBIND: if int(main.keys[kb[0]]) != int(kb[2]): changed = true
	for pb in main.PADBIND:
		var b: Dictionary = main.pad[pb[0]]; var d: Dictionary = pb[2]
		if b["t"] != d["t"] or int(b["i"]) != int(d["i"]) or int(b["s"]) != int(d["s"]): changed = true
	for k in ["inv_lx", "inv_ly", "inv_rx", "inv_ry", "swap_roll", "inv_kb_pitch"]: if bool(main.cfg.get(k, false)): changed = true
	if absf(float(main.cfg.get("deadzone", 0.12)) - 0.12) > 0.001: changed = true
	if changed: grant("custom")
	var adv := false
	for o in main.tune.ORGANS:
		var k: String = o[0]
		if absf(float(main.tune.v[k + ".start"]) - float(o[3])) > 0.001 or absf(float(main.tune.v[k + ".max"]) - float(o[4])) > 0.001 or absf(float(main.tune.v[k + ".time"]) - float(o[5])) > 0.001 or int(main.tune.v[k + ".fn"]) != int(o[6]) or absf(float(main.tune.v[k + ".k"]) - float(o[7])) > 0.001: adv = true
	if adv: grant("custom_adv")
	var right := true                                                         # тангаж и крен на правом стике (оси 2 и 3)
	for id in ["pitch_up", "pitch_down", "roll_left", "roll_right"]:
		var b2: Dictionary = main.pad[id]
		if b2["t"] != "a" or not (int(b2["i"]) in [2, 3]): right = false
	if right: grant("shor")

var fin_info := {}
func _eval_finish() -> void:                                                # рекорд и новые достижения за этот финиш; в тестовых снимках конфиг не трогаем
	fin_info = {"rec_new": false, "rec_prev": -1.0, "ach": []}
	if main.ui_shot == "results": fin_info = {"rec_new": true, "rec_prev": 74.31, "ach": [{"id": ACH[3]["id"], "name": ACH[3]["title"], "cond": ACH[3]["cond"]}, {"id": ACH[10]["id"], "name": ACH[10]["title"], "cond": ACH[10]["cond"]}]}; return
	if main.ui_shot != "" or not (main.p_fin or main.p_dsq): return
	var stt := _stats()
	stt["races"] = int(stt.get("races", 0)) + 1; stt["km"] = float(stt.get("km", 0.0)) + main.race_dist / 1000.0
	if main.p_dsq:                                                             # дисквалификация: серия подряд
		stt["dsq_streak"] = int(stt.get("dsq_streak", 0)) + 1; main._save_cfg()
		if int(stt["dsq_streak"]) >= 10: grant("klutz")
		_check_tester(); return
	stt["dsq_streak"] = 0
	var lvl: int = main._lvl(); var sid := int(main.cfg.get("ship", 0)); var key := "%d:%d" % [lvl, sid]
	_sadd("ships_done", sid); _sadd("levels_done", lvl); stt["finishes"] = int(stt.get("finishes", 0)) + 1
	var rec: Dictionary = main.cfg.get("rec", {}); var t: float = main.p_fin_t
	if rec.has(key): fin_info["rec_prev"] = float(rec[key])
	if not rec.has(key) or t < float(rec[key]): fin_info["rec_new"] = true; rec[key] = t
	main.cfg["rec"] = rec
	var earned := ["finish"]
	if main.rank <= 3: earned.append("podium")
	if main.rank == 1: earned.append("win")
	if main.p_hits == 0: earned.append("clean")
	if not main.p_rim_ever: earned.append("low")
	if main.p_side: earned.append("side")
	var lid: Dictionary = {0: "tourist", 3: "veteran", 4: "cyborg"}
	if lid.has(lvl): earned.append(lid[lvl])
	if sid == 1: earned.append("freya")
	if main.rank == 1 and sid == 0: earned.append("book")
	if bool(fin_info["rec_new"]) and float(fin_info["rec_prev"]) >= 0.0: earned.append("record")
	var ret_len: float = (load("res://music/retribution.mp3") as AudioStream).get_length()
	if t < ret_len - main.INTRO_T: earned.append("short_music")
	if main.rank == main.bots.size() + 1: earned.append("loser")
	if t < DEV_RECORD: earned.append("beat_dev")
	if sid == 2: earned.append("seagull")
	if _sarr("ships_done").size() >= main.SHIP_NAMES.size(): earned.append("pilot_test")
	if _sarr("levels_done").size() >= 5: earned.append("academy")
	if main.p_max_y <= 2000.0: earned.append("jeweler")
	if main.p_bank_dist > 0.6 * main.race_len: earned.append("brave")
	if main.p_cam_ck and main.CAM_MODES[main.cam_mode] == "cockpit": earned.append("eyes")
	if main.p_parts0 >= 0 and main.parts.size() >= main.p_parts0: earned.append("intact")
	if float(stt["km"]) >= 20000.0: earned.append("km1000")
	if int(stt["finishes"]) >= 25: earned.append("vet25")
	var eng_left := false
	for pn in main.parts: if String(pn).begins_with("SM_Engine_"): eng_left = true
	if main.rank == 1 and not eng_left: earned.append("will")
	var got: Dictionary = main.cfg.get("ach", {}); var dt := Time.get_datetime_dict_from_system()
	var when := "%02d.%02d.%d · %s, %s" % [dt["day"], dt["month"], dt["year"], main.LEVEL_NAMES[lvl], main.SHIP_NAMES[sid]]
	for a in ACH:
		if earned.has(a["id"]) and not got.has(a["id"]): got[a["id"]] = when; fin_info["ach"].append({"id": a["id"], "name": a["title"], "cond": a["cond"]})
	for did in ["connoisseur", "collector"]:                                  # зависимые от других достижений могут открыться сразу вместе с финишем
		if not got.has(did) and _derived_ok(did, got):
			got[did] = when
			for a in ACH: if a["id"] == did: fin_info["ach"].append({"id": did, "name": a["title"], "cond": a["cond"]})
	main.cfg["ach"] = got; main._save_cfg(); _check_tester()

func _show_state(st: String) -> void:
	state = st
	var menu_like := st in ["menu", "pause"]
	menu_panel.visible = false; dim.visible = false; skin.visible = menu_like or st == "results"
	if st == "results":
		skin.mode = "results"; _eval_finish()
		sfx.play("error" if main.p_dsq else ("record" if bool(fin_info.get("rec_new", false)) else ("unlock" if not (fin_info.get("ach", []) as Array).is_empty() else "pop")))
	if st == "pause": title_lbl.text = "ПАУЗА"
	elif st == "menu": title_lbl.text = "КАРНАВАЛЬСКАЯ\nГОНКА"
	hud_root.visible = st in ["hud", "pause"]; marker_root.visible = st != "results"
	if main.music != null and main.music_ok():
		if st == "menu": main.music.set_paused(false); main.music.play_menu()
		elif st == "results": main.music.play_results()
	res_panel.visible = false
	page = "main"; capturing = ""; sel = 0; _refresh_items()

func open_menu() -> void:
	main.cam_mode = 3
	_show_state("menu"); main._sync_time_scale()

func open_pause() -> void:
	if state != "hud": return
	opened_frame = Engine.get_process_frames()
	_show_state("pause"); main._sync_time_scale(); if main.music != null: main.music.set_paused(true)

func close_pause() -> void:
	sfx.play("back")
	main._save_cfg(); main.tune.save_file()
	_show_state("hud"); main._sync_time_scale(); if main.music != null: main.music.set_paused(false)

func blocking() -> bool:
	return state in ["menu", "pause"]

func on_settings_closed() -> void:
	main._sync_time_scale()

func _start_race() -> void:
	var sts := _stats(); sts["starts"] = int(sts.get("starts", 0)) + 1; main._save_cfg()
	if int(main.cfg.get("ship", 0)) != main.ship_id: _reload_for_ship(); return
	state = "hud"; _show_state("hud"); main.cam_mode = clampi(int(main.cfg["cam_view"]), 0, main.CAM_NAMES.size() - 1); main.begin_intro(); main._sync_time_scale()

func _reload_for_ship() -> void:                                            # выбран другой корабль: экран загрузки, затем сцена пересобирается и гонка стартует сразу
	main.reload_title = "Загрузка корабля «%s»" % main.SHIP_NAMES[int(main.cfg["ship"])]
	Engine.time_scale = 1.0; Engine.set_meta("skip_menu", true)
	main._reload_game()

func _restart() -> void:
	main.reload_title = "Перезапуск заезда"; Engine.time_scale = 1.0; Engine.set_meta("skip_menu", true); main._reset()

func _to_menu() -> void:
	main.reload_title = "Возврат в главное меню"; Engine.time_scale = 1.0
	if Engine.has_meta("skip_menu"): Engine.remove_meta("skip_menu")
	main._reset()

func _activate() -> void:
	if state == "results":
		if items[sel]["id"] == "again": _restart()
		else: _to_menu()
		return
	var it0: Dictionary = items[sel]
	var kd := String(it0.get("kind", ""))
	if kd == "toggle": sfx.play("toggle")
	elif kd == "slider": sfx.play("tick")
	elif page == "exit" and sel == 0 and state == "menu": sfx.play("delete")
	elif String(it0.get("t", "")) == "Старт": sfx.play("confirm")
	elif it0.get("a") == null: sfx.play("error")
	else: sfx.play("select")
	var a = items[sel].get("a")
	if a != null: (a as Callable).call(); _refresh_items()

func _step(d: int) -> void:
	var s = items[sel].get("s")
	if s != null:
		var kd := String(items[sel].get("kind", ""))
		sfx.play("toggle" if kd == "toggle" else ("tick" if kd == "slider" else "move"))
		(s as Callable).call(d); _refresh_items()

func _change_ship(d: int) -> void:                                           # в меню только листаем карточки; сцена с выбранным кораблём пересобирается при старте гонки (_start_race)
	main.cfg["ship"] = posmod(int(main.cfg.get("ship", 0)) + d, main.SHIP_NAMES.size()); main._save_cfg()

func _change_cam_view(d: int) -> void:
	main.cfg["cam_view"] = posmod(int(main.cfg["cam_view"]) + d, main.CAM_NAMES.size()); main._save_cfg(); _refresh_items()

func _change_level(d: int) -> void:
	main.cfg["level"] = posmod(int(main.cfg["level"]) + d, 5); main._save_cfg(); _refresh_items()

func _input(ev: InputEvent) -> void:                                   # перехват клавиши при переназначении
	if state == "hud" and main.racing and main.start_t <= 0.0 and not main.p_fin and _ach_on():                 # полёт на геймпаде / клавиатуре: достаточно нескольких событий
		if (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > 0.4):
			fl_pad += 1
			if fl_pad >= 3: grant("gamepad")
		elif ev is InputEventKey and ev.pressed and not ev.echo:
			fl_kb += 1
			if fl_kb >= 3: grant("keyboard")
	if page == "pad" and state in ["menu", "pause"]: _padmap_input(ev); return
	if capturing.begins_with("pad:"):
		_pad_capture(ev); return
	if capturing == "" or not (ev is InputEventKey) or not ev.pressed or ev.echo: return
	get_viewport().set_input_as_handled()
	var kc: int = (ev as InputEventKey).physical_keycode
	if kc == KEY_ESCAPE: capturing = ""; _refresh_items(); return
	if kc in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5]: return          # служебные клавиши
	for k2 in main.keys:
		if k2 != capturing and main.keys[k2] == kc: main.keys[k2] = main.keys[capturing]        # занята — меняемся
	main.keys[capturing] = kc; capturing = ""
	main.apply_keys(); main._save_cfg(); _refresh_items()

func _pad_capture(ev: InputEvent) -> void:
	var nb := {}
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled(); capturing = ""; _refresh_items(); return
	if ev is InputEventJoypadButton and ev.pressed:
		get_viewport().set_input_as_handled()
		if (ev as InputEventJoypadButton).button_index == JOY_BUTTON_START: capturing = ""; _refresh_items(); return
		nb = {"t": "b", "i": (ev as InputEventJoypadButton).button_index, "s": 1}
	elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > 0.7:
		get_viewport().set_input_as_handled()
		var ax := (ev as InputEventJoypadMotion).axis
		nb = {"t": "a", "i": ax, "s": 1 if (ev as InputEventJoypadMotion).axis_value > 0.0 else -1}
		if ax >= 4: nb["s"] = 1
	if nb.is_empty(): return
	var id := capturing.substr(4)
	var kind := ""
	for pb in main.PADBIND: if pb[0] == id: kind = pb[3]
	if kind == "b" and nb["t"] != "b": return                           # для этого действия подходит только кнопка
	var old: Dictionary = main.pad[id]
	for pb in main.PADBIND:
		var o2: String = pb[0]
		if o2 != id and main.pad[o2]["t"] == nb["t"] and main.pad[o2]["i"] == nb["i"] and main.pad[o2]["s"] == nb["s"] and (pb[3] == "m" or old["t"] == "b"):
			main.pad[o2] = old.duplicate()
	main.pad[id] = nb; capturing = ""
	main.apply_pad(); main._save_cfg(); _refresh_items()

# ---------- Экран «Кнопки геймпада»: нажать кнопку на геймпаде (кроме B) — открыть список действий для неё ----------
func _pm_slot(id: String) -> Dictionary:
	for sl in MenuSkin.PAD_SLOTS: if sl["id"] == id: return sl
	return {}

func _pm_eq(b: Dictionary, sl: Dictionary) -> bool:                           # привязка b стоит на элементе sl?
	if String(b["t"]) != String(sl["t"]) or int(b["i"]) != int(sl["i"]): return false
	return String(sl["t"]) == "b" or int(sl["i"]) >= 4 or int(b["s"]) == int(sl["s"])

func _pm_opts(sl: Dictionary) -> Array:
	var out := []
	for pb in main.PADBIND:
		var id: String = pb[0]; var cur := _pm_eq(main.pad[id], sl); var dis := false
		if pb[3] == "b" and String(sl["t"]) != "b": dis = true                  # кнопочное действие нельзя повесить на ось или курок
		if not cur and not dis:
			for pb2 in main.PADBIND:                                          # занявший элемент получит прежнюю привязку этого действия — ему она должна подходить
				if pb2[0] != id and _pm_eq(main.pad[pb2[0]], sl) and pb2[3] == "b" and String(main.pad[id]["t"]) != "b": dis = true
		out.append({"id": id, "name": pb[1], "note": "текущее" if cur else main.pad_name(main.pad[id]), "cur": cur, "dis": dis})
	out.append({"id": "_reset", "name": "Сбросить все кнопки", "note": "по умолчанию", "cur": false, "dis": false})
	return out

func _pm_open(sl: Dictionary) -> void:
	if String(sl.get("lock", "")) != "":
		sfx.play("error"); pm_msg = "Эта кнопка закреплена: %s." % String(sl["lock"]).split(" · ")[0].to_lower(); pm_msg_t = Time.get_ticks_msec() / 1000.0 + 2.5; return
	pm_sel = String(sl["id"]); pm_cur = pm_sel; pm_frame = Engine.get_process_frames(); sfx.play("select")
	var opts := _pm_opts(sl); pm_opt = 0; pm_top = 0
	for i in opts.size(): if opts[i]["cur"]: pm_opt = i
	pm_top = clampi(pm_opt - 4, 0, maxi(opts.size() - 8, 0))

func _pm_assign() -> void:
	var sl := _pm_slot(pm_sel); var opts := _pm_opts(sl); var o: Dictionary = opts[pm_opt]
	if bool(o["dis"]): sfx.play("error"); return
	if o["id"] == "_reset": _reset_pad(); sfx.play("confirm"); pm_sel = ""; return
	if not bool(o["cur"]):
		var old: Dictionary = (main.pad[o["id"]] as Dictionary).duplicate()
		for pb in main.PADBIND:
			if pb[0] != o["id"] and _pm_eq(main.pad[pb[0]], sl): main.pad[pb[0]] = old.duplicate()
		main.pad[o["id"]] = {"t": sl["t"], "i": sl["i"], "s": sl["s"]}
		main.apply_pad(); main._save_cfg(); check_custom()
	sfx.play("confirm"); pm_sel = ""

func _pm_lock_reason() -> String:                                           # при схеме 2 и на уровне «Киборг» кнопки геймпада переназначить нельзя
	if main.scheme == 1: return "Включена схема геймпада 2: кнопки в ней закреплены, переназначение недоступно. Схему можно сменить в разделе «Управление»."
	if main._lvl() == 4: return "На уровне «Киборг» действует схема геймпада 2: переназначение кнопок недоступно. Выберите другой уровень сложности."
	return ""

func _padmap_input(ev: InputEvent) -> void:
	if pm_sel != "": return
	if _pm_lock_reason() != "":
		if (ev is InputEventJoypadButton and ev.pressed and (ev as InputEventJoypadButton).button_index != JOY_BUTTON_B) or (ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > 0.8 and not pm_lat.has(int((ev as InputEventJoypadMotion).axis))):
			if ev is InputEventJoypadMotion: pm_lat[int((ev as InputEventJoypadMotion).axis)] = true
			sfx.play("error")
		elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) < 0.4: pm_lat.erase(int((ev as InputEventJoypadMotion).axis))
		return
	var hit := {}
	if ev is InputEventJoypadButton and ev.pressed:
		var bi := (ev as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_B: return                                          # B — назад (обработает навигация)
		for sl in MenuSkin.PAD_SLOTS: if sl["t"] == "b" and int(sl["i"]) == bi: hit = sl
	elif ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion; var ax := int(m.axis); var v := m.axis_value
		if absf(v) < 0.4: pm_lat.erase(ax); return
		if absf(v) < 0.7 or pm_lat.has(ax): return
		for sl in MenuSkin.PAD_SLOTS:
			if sl["t"] == "a" and int(sl["i"]) == ax and (ax >= 4 or (int(sl["s"]) < 0) == (v < 0.0)): hit = sl
		if not hit.is_empty() or ax < 4: pm_lat[ax] = true
	if hit.is_empty(): return
	get_viewport().set_input_as_handled(); pm_frame = Engine.get_process_frames(); pm_cur = String(hit["id"])
	_pm_open(hit)

func _padmap_nav() -> void:                                                  # клавиатура и подтверждение/отмена
	var fr := Engine.get_process_frames()
	if fr == pm_frame or fr == opened_frame: return
	if pm_sel != "":
		var opts := _pm_opts(_pm_slot(pm_sel)); var n := opts.size(); var o0 := pm_opt
		if Input.is_action_just_pressed("ui_down"): pm_opt = (pm_opt + 1) % n
		if Input.is_action_just_pressed("ui_up"): pm_opt = (pm_opt - 1 + n) % n
		if pm_opt != o0: sfx.play("move")
		if pm_opt < pm_top: pm_top = pm_opt
		if pm_opt > pm_top + 7: pm_top = pm_opt - 7
		if pm_opt == 0: pm_top = 0
		if Input.is_action_just_pressed("ui_accept"): _pm_assign()
		elif Input.is_action_just_pressed("ui_cancel"): pm_sel = ""; sfx.play("back")
		return
	if _pm_lock_reason() != "":
		if Input.is_action_just_pressed("ui_cancel"): back_page()
		elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"): sfx.play("error")
		return
	var order: Array = []
	for sl in MenuSkin.PAD_SLOTS: order.append(sl["id"])
	var k := order.find(pm_cur); var k0 := k
	if Input.is_action_just_pressed("ui_down"): k = (k + 1) % order.size()
	if Input.is_action_just_pressed("ui_up"): k = (k - 1 + order.size()) % order.size()
	if k != k0: pm_cur = order[k]; sfx.play("move")
	if Input.is_action_just_pressed("ui_accept"): _pm_open(_pm_slot(pm_cur))
	elif Input.is_action_just_pressed("ui_cancel"): back_page()

func _padmap_sync() -> void:
	if skin == null: return
	var acts := {}; var live := {}
	var pads := Input.get_connected_joypads()
	for sl in MenuSkin.PAD_SLOTS:
		var names: Array = []
		for pb in main.PADBIND: if _pm_eq(main.pad[pb[0]], sl): names.append(pb[1])
		acts[sl["id"]] = " · ".join(names)
		for dev in pads:
			if sl["t"] == "b":
				if Input.is_joy_button_pressed(dev, int(sl["i"])): live[sl["id"]] = true
			else:
				var v := Input.get_joy_axis(dev, int(sl["i"]))
				if (int(sl["i"]) >= 4 and v > 0.5) or (int(sl["i"]) < 4 and v * float(sl["s"]) > 0.5): live[sl["id"]] = true
	var lockr := _pm_lock_reason()
	if lockr != "": pm_sel = ""; live = {}
	var pm := {"acts": acts, "sel": pm_sel, "cur": pm_cur, "live": live, "locked": lockr}
	var bt := func(k: String, g: String, l: String) -> Dictionary: return {"k": k, "g": g, "l": l}
	if lockr != "":
		pm["hint"] = "Кнопки геймпада сейчас переназначить нельзя."
		skin.hint_btns = [bt.call("B", "", "Назад")]
	elif pm_sel != "":
		pm["pop"] = {"rows": _pm_opts(_pm_slot(pm_sel)), "sel": pm_opt, "top": pm_top}
		pm["hint"] = "Выберите действие. Если оно уже занято, элементы поменяются местами."
		skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("A", "", "Назначить"), bt.call("B", "", "Отмена")]
	else:
		pm["hint"] = pm_msg if Time.get_ticks_msec() / 1000.0 < pm_msg_t else "Нажмите кнопку или отклоните стик на геймпаде, и откроется список действий для неё."
		skin.hint_btns = [bt.call("pad", "↑↓", "Выбор"), bt.call("A", "", "Открыть"), bt.call("B", "", "Назад")]
	skin.padmap = pm

# ---------- Результаты ----------
func _build_results() -> void:
	res_panel = Control.new(); res_panel.set_anchors_preset(Control.PRESET_CENTER); res_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(res_panel)
	var bg := ColorRect.new(); bg.position = Vector2(-380, -340); bg.size = Vector2(760, 640); bg.color = DARK; res_panel.add_child(bg)
	res_title = _lbl("ФИНИШ", 60, ORANGE, res_panel, Vector2(-350, -336))
	res_sub = _lbl("", 28, CREAM, res_panel, Vector2(-346, -268))
	var rows := VBoxContainer.new(); rows.position = Vector2(-350, -215); rows.add_theme_constant_override("separation", 0); rows.mouse_filter = Control.MOUSE_FILTER_IGNORE; res_panel.add_child(rows)
	for i in 11:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; rows.add_child(hb)
		var row := [_lbl("", 22, CREAM, hb), _lbl("", 22, CREAM, hb), _lbl("", 22, CREAM, hb)]
		(row[0] as Label).custom_minimum_size = Vector2(44, 0)
		var nm := row[1] as Label; nm.custom_minimum_size = Vector2(390, 0); nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nm.size_flags_horizontal = Control.SIZE_FILL
		(row[2] as Label).custom_minimum_size = Vector2(240, 0); (row[2] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		res_rows.append(row)
	for i in 2: res_btns.append(_lbl("", 34, CREAM, res_panel, Vector2(-350 + i * 330, 252)))
	res_panel.visible = false

func _update_results() -> void:
	var ents := []
	ents.append({"n": "Вы", "fin": main.p_fin, "t": main.p_fin_t, "p": (-1.0 if main.p_dsq else main.p_prog), "me": true, "dnf": main.p_dsq})
	for b in main.bots: ents.append({"n": b["name"], "fin": b["fin"], "t": b["fin_t"], "p": b["prog"], "me": false, "dnf": b.get("dnf", false)})
	ents.sort_custom(func(a, b):
		if a["fin"] and b["fin"]: return a["t"] < b["t"]
		if a["fin"] != b["fin"]: return a["fin"]
		return a["p"] > b["p"])
	var place := 1
	for i in res_rows.size():
		var r: Array = res_rows[i]
		if i >= ents.size(): for l in r: (l as Label).text = ""; continue
		var e: Dictionary = ents[i]
		var col := ORANGE if e["me"] else CREAM
		(r[0] as Label).text = "%d" % (i + 1); (r[1] as Label).text = e["n"]
		(r[2] as Label).text = ("%.1f с" % e["t"]) if e["fin"] else (("дисквал." if (e["me"] and main.p_dsq) else "сошёл") if e["dnf"] else "%d%% дистанции" % int(clampf(float(e["p"]) / main.race_len, 0.0, 1.0) * 100.0))
		for l in r: (l as Label).add_theme_color_override("font_color", col)
	res_sub.text = "дисквалификация" if main.p_dsq else "место %d из %d  ·  %.1f с" % [main.rank, main.bots.size() + 1, main.p_fin_t]
	var rws: Array = []
	for i in ents.size():
		var e2: Dictionary = ents[i]
		rws.append({"n": e2["n"], "place": i + 1, "me": e2["me"], "dnf": not e2["fin"], "time": skin._mmss(float(e2["t"])) if e2["fin"] else (("дисквал." if (e2["me"] and main.p_dsq) else "сошёл") if e2["dnf"] else "%d%%" % int(clampf(float(e2["p"]) / main.race_len, 0.0, 1.0) * 100.0))})
	skin.res["dsq"] = main.p_dsq; skin.res["rows"] = rws; skin.res["place"] = (main.bots.size() + 1 if main.p_dsq else main.rank); skin.res["of"] = main.bots.size() + 1
	skin.res["ship"] = main.SHIP_NAMES[clampi(int(main.cfg.get("ship", 0)), 0, main.SHIP_NAMES.size() - 1)]; skin.res["level"] = main.LEVEL_NAMES[main._lvl()]
	skin.res["time_txt"] = skin._mmss(main.p_fin_t) if main.p_fin else "—"
	skin.res["rec_new"] = bool(fin_info.get("rec_new", false)); skin.res["rec_prev"] = skin._mmss(float(fin_info["rec_prev"])) if float(fin_info.get("rec_prev", -1.0)) >= 0.0 else ""
	var rk: String = "%d:%d" % [main._lvl(), int(main.cfg.get("ship", 0))]
	skin.res["rec_txt"] = "рекорд трассы " + skin._mmss(float(main.cfg.get("rec", {}).get(rk, main.p_fin_t))) if main.p_fin else ""
	skin.res["ach"] = fin_info.get("ach", [])

# ---------- Маркеры соперников: подписи одного размера независимо от расстояния ----------
const MARKER_MAX_DIST := 40000.0                                               # дальше этого расстояния (м) корабль уже меньше пикселя: подпись скрыта; последняя четверть — плавное затухание
const MARKER_LOS_MIN := 1500.0                                                 # ближе этого подпись всегда показывается, видимость по рельефу проверяется только дальше
var marker_los: Dictionary = {}                                                # номер бота -> [время проверки, виден]

# Виден ли бот из камеры: луч камера -> бот не должен уходить под рельеф (стены каньона, повороты). Результат кешируется на 0.15 с
func _marker_visible(i: int, from: Vector3, to: Vector3) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var c = marker_los.get(i)
	if c != null and now - float(c[0]) < 0.15: return bool(c[1])
	var vis := true
	var n := clampi(int(from.distance_to(to) / 500.0), 4, 80)
	for k in range(1, n):                                                       # концы луча не берём: рельеф под самой камерой и под ботом не считается
		var q := from.lerp(to, float(k) / float(n))
		if main.height(q.x, q.z) > q.y - 4.0: vis = false; break
	marker_los[i] = [now, vis]
	return vis

func _update_markers() -> void:
	var cam: Camera3D = main.cam
	var show := state in ["hud", "pause", "results"] and cam != null
	marker_root.visible = show
	if not show: return
	while marker_lbls.size() < main.bots.size():
		var l := _lbl("", 17, CREAM, marker_root); l.add_theme_constant_override("outline_size", 5); marker_lbls.append(l)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var sc := Vector2(vs.x / maxf(1.0, float(get_viewport().size.x)), vs.y / maxf(1.0, float(get_viewport().size.y)))
	var me: Vector3 = main.ship.global_position
	for i in main.bots.size():
		var b: Dictionary = main.bots[i]; var l: Label = marker_lbls[i]
		var p: Vector3 = (b["rb"] as RigidBody3D).global_position + Vector3(0, 28, 0)
		if cam.is_position_behind(p): l.visible = false; continue
		var d := me.distance_to(p)
		if d > MARKER_MAX_DIST: l.visible = false; continue                      # улетел далеко (например, со старта): подпись только мешает
		if d > MARKER_LOS_MIN and not _marker_visible(i, cam.global_position, p): l.visible = false; continue     # закрыт стеной каньона: корабля не видно, подписи тоже
		l.modulate.a = clampf((MARKER_MAX_DIST - d) / (MARKER_MAX_DIST * 0.25), 0.0, 1.0)
		var sp := cam.unproject_position(p) * sc
		if sp.x < 0.0 or sp.y < 0.0 or sp.x > vs.x or sp.y > vs.y: l.visible = false; continue          # подпись только у кораблей в поле зрения
		l.text = "%s  %s" % [b["name"], ("%d м" % int(d)) if d < 1000.0 else ("%.1f км" % (d / 1000.0))]
		l.reset_size()
		var half := l.size * 0.5
		sp = Vector2(clampf(sp.x, half.x + 8.0, vs.x - half.x - 8.0), clampf(sp.y, half.y + 8.0, vs.y - half.y - 8.0))
		l.position = sp - Vector2(half.x, l.size.y)
		l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65) if b["fin"] else (ORANGE if main.rank > 1 and float(b["prog"]) > float(main.p_prog) else CREAM))
		l.visible = true
	var placed: Array = []                                                      # разводим перекрывающиеся подписи по вертикали
	for l2 in marker_lbls:
		if not (l2 as Label).visible: continue
		var lab: Label = l2; var rect := Rect2(lab.position, lab.size)
		for _k in 6:
			var hit := false
			for r in placed:
				if rect.intersects(r): lab.position.y = (r as Rect2).end.y + 2.0; rect = Rect2(lab.position, lab.size); hit = true; break
			if not hit: break
		placed.append(rect)

# ---------- Каждый кадр ----------
func _process(_dt: float) -> void:
	if main == null or not is_instance_valid(main) or main.ship == null: return
	if toast_lbl != null and toast_lbl.visible:                                    # плашка получения достижения гаснет
		var left := toast_t - Time.get_ticks_msec() / 1000.0
		if left <= 0.0: toast_lbl.visible = false
		else: toast_lbl.modulate.a = clampf(left / 0.8, 0.0, 1.0)
	_update_markers()
	# HUD
	var v: float = main.ship.linear_velocity.length()
	lbl_rank.text = "%d/%d" % [main.rank, main.bots.size() + 1]
	var t: float = main.race_t
	lbl_time.text = "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
	lbl_speed.text = "%d м/с" % int(v)
	lbl_alt.text = "высота %d м   ·   %d км/ч" % [int(main.ship.global_position.y), int(v * 3.6)]
	lbl_lvl.text = "Уровень: " + main.LEVEL_NAMES[main._lvl()]
	prog_bar.size.x = 440.0 * clampf(float(main.p_prog) / main.race_len, 0.0, 1.0) if main.race_len < 1e11 else 0.0
	dmg_ctl.queue_redraw(); map_ctl.queue_redraw()
	# обратный отсчёт
	if state in ["hud", "pause"]: hud_root.visible = not main.in_cutscene()
	lbl_skip.visible = state == "hud" and main.in_cutscene()
	lbl_stab.visible = state == "hud" and not main.assist and int(main.cfg["level"]) < 4 and not main.in_cutscene()
	ov_ctl.visible = state == "hud" and main.intro_t() < 7.0
	if ov_ctl.visible: ov_ctl.queue_redraw()
	var cnt: int = int(ceil(main.start_t)) if main.start_t > 0.0 and main.start_t <= 6.0 and state == "hud" else 0
	if cnt > 0: lbl_count.text = str(cnt); lbl_count.visible = true; go_t = 0.9; last_count = cnt
	elif go_t > 0.0 and state == "hud": go_t -= _dt if _dt > 0.0 else 0.016; lbl_count.text = "СТАРТ!"; lbl_count.visible = true
	else: lbl_count.visible = false
	# финиш -> результаты
	if state == "hud" and main.p_fin and res_t_show < 0.0: res_t_show = Time.get_ticks_msec() / 1000.0 + 2.5
	if state == "hud" and res_t_show > 0.0 and Time.get_ticks_msec() / 1000.0 >= res_t_show:
		_show_state("results"); _update_results()
	if state == "results": _update_results()
	# навигация
	if page == "pad" and state in ["menu", "pause"] and not main.tech_open: _padmap_nav(); _padmap_sync()
	elif state in ["menu", "pause", "results"] and not main.tech_open and capturing == "":
		var gn := items.size()
		var sel0 := sel
		if page == "ach" and state == "menu":                                   # грамоты сеткой 4×3: ↑↓ по рядам, ◀▶ по одной
			if Input.is_action_just_pressed("ui_down"): sel = sel + 4 if sel + 4 < gn else sel % 4; _refresh_items()
			if Input.is_action_just_pressed("ui_up"): sel = sel - 4 if sel >= 4 else mini((gn - 1) / 4 * 4 + sel % 4, gn - 1); _refresh_items()
			if Input.is_action_just_pressed("ui_left"): sel = posmod(sel - 1, gn); _refresh_items()
			if Input.is_action_just_pressed("ui_right"): sel = posmod(sel + 1, gn); _refresh_items()
		else:
			if Input.is_action_just_pressed("ui_down"): sel = (sel + 1) % gn; _refresh_items()
			if Input.is_action_just_pressed("ui_up"): sel = (sel - 1 + gn) % gn; _refresh_items()
			if state != "results":
				if Input.is_action_just_pressed("ui_left"): _step(-1)
				if Input.is_action_just_pressed("ui_right"): _step(1)
		if sel != sel0: sfx.play("move")
		if Input.is_action_just_pressed("ui_accept"): _activate()
		elif state != "results" and Input.is_action_just_pressed("ui_cancel") and Engine.get_process_frames() != opened_frame:
			if page != "main": back_page()
			elif state == "pause": close_pause()
