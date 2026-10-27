# Общие правила для всех промптов GPT (вставлять в начало каждого промпта)

## Блок ограничений (копировать целиком)

Create ORIGINAL artwork only. Do not copy, imitate or reference any existing film, TV series, game, book, brand or product: no recognizable screenshots, ship designs, interfaces or logos from any franchise (no The Expanse, Star Wars, Star Trek, Alien, Mass Effect, Elite, etc.). Do not write any brand names, ship names, franchise names, real people names, real company names or trademarks. Do not add watermarks, signatures, stock-photo marks, captions or UI chrome from any app.

Text rules: use only short generic technical labels (for example NAV, ENG, PWR, SYS, O2, TEMP, ALT) and numbers. No sentences, no paragraphs, no names of characters. Letters must be clean and correctly spelled; if unsure, use numbers or symbols instead of words.

Technical rules: output exactly the requested pixel size and aspect ratio, flat orthographic 2D (no perspective, no camera angle, no 3D render of a scene, no photo of a screen, no bezel, no reflections, no glare, no vignette, no motion blur, no film grain). No people, no hands, no animals. Follow the attached layout/guide image exactly: stay inside the marked cells and margins. Where transparency is requested, deliver a real PNG alpha channel, not a black or checkerboard background. For tiling textures the left/right and top/bottom edges must match seamlessly.

## Палитра и стиль корабля («Третий шанс»)
- Корпус: белая краска с чёрными полосами и потёртостями, шестигранный тайл; акценты: красный (#c8372d) и холодный голубой (#5be0ff).
- Интерьер: тёмно-серая сталь, светлые панели, жёлто-чёрная разметка опасных зон, тёплый дерево/кожа в жилых зонах.
- Игровой стиль: чистый реалистичный sci-fi, читаемый на расстоянии, без излишней мелкой детализации.

## Как проверять результат от GPT
1. Нет узнаваемых надписей, логотипов и названий (если есть — не использовать, перегенерировать).
2. Размер и пропорции совпадают с картой-подсказкой.
3. Фон прозрачный там, где нужно, края не «грязные».
4. Складывать в `textures/interior/gpt_raw/`, дальше обработка скриптом (я собираю атласы и альфу сам).
