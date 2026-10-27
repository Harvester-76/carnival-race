# Голо-окна над пультами рубки — атлас для GPT

Файлы:
- Карта-подсказка (загружать в GPT вместе с промптом): `textures/interior/holo_layout_guide_2048x1280.png`
- Заглушка, которая сейчас в сцене: `textures/interior/holo_atlas_2048x1280_placeholder.png`
- Результат сохранить как `textures/interior/holo_atlas_2048x1280.png` (PNG с альфой), в Blender в материале `MAT_Holo` заменить картинку `holo_atlas`.

Раскладка атласа 2048x1280, 4 окна по 1024x640 (16:10):
1 слева-сверху — НАВИГАЦИЯ (перед левым креслом), 2 справа-сверху — ДВИГАТЕЛИ (перед пилотом, левое окно), 3 слева-снизу — СИСТЕМЫ КОРАБЛЯ (перед пилотом, правое окно), 4 справа-снизу — СВЯЗЬ (перед правым креслом).

## Промпт
(Перед текстом промпта вставить блок ограничений из `00_common_rules.md`. Первая версия без него принесла картинки с чужими названиями.)

Use the attached image as an exact layout guide: a 2048x1280 canvas split into four 1024x640 cells, each cell is one independent holographic window. Draw the content INSIDE each cell and keep a 24 px empty margin to the cell border. Output a PNG with a real alpha channel: everything outside the interface elements must be fully transparent (no background, no black, no glow outside the window).

Style: sci-fi holographic interface projected in air above a keyboard console, thin glowing cyan and teal lines (#5be0ff, #2bb6d9), a few amber (#ffb347) and red (#ff6a5a) warning accents, semi-transparent dark-teal glass panel fill at about 20 percent opacity, 2 px scan lines, subtle hex pattern, rounded corners, clean readable game UI, flat 2D, no perspective, no 3D, no text in a real language other than short labels and numbers, no people, no logos.

Window 1, NAVIGATION: top-down star map with concentric range rings, a ship marker in the center, a planned route as a dotted curve, three planets and a small asteroid field, coordinates and distance numbers on the edges.
Window 2, ENGINES: six vertical thrust bars with percentage labels, a temperature graph below, a rotating-ring icon, a small warning triangle on bar 4.
Window 3, SHIP SYSTEMS: a wireframe side-view silhouette of a single-hull spaceship (long hull, swept wings, two engine pods) with highlighted sections, a list of seven system lines with status bars (power, shields, life support, airlocks, comms, weapons, cargo).
Window 4, COMMS: a waveform / spectrum analyzer, a signal-strength meter, a list of three contacts with distance and a small radar sweep.

Each window has a title bar with a short label (NAV, ENGINES, SYSTEMS, COMMS) and a thin outer frame. Content must be crisp, high contrast, readable at 1024x640.

## Заметки по настройке
- В игре окна полупрозрачные (alpha * 0.9, эмиссия 2.5); яркость и прозрачность правятся в узлах `MAT_Holo`.
- Окна 1,10 x 0,69 м стоят на приборной панели за наклонным столиком с клавиатурами, наклон 15° назад; у основания светящаяся полоска-излучатель.
- Клавиатуры (3 шт., под каждым креслом) целиком сделаны процедурно: `textures/tools/make_cabin_ui.py` создаёт `kb_albedo/kb_emission_2560x1024.png`, GPT для них не нужен.
