# Промпты GPT для иконок достижений («Карнавальская Гонка»)

44 иконки, по одной на достижение. Файлы класть в `menu_v2/ach/<id>.png` (id — из списка ниже).
Генерировать по одной (или сеткой 2×2, затем резать), всегда добавляя общий блок.

## Общий блок (вставлять в начало каждого промпта)

Create ORIGINAL artwork only. Do not copy or imitate any existing film, TV series, game, book, brand, logo or product. No brand names, no real people, no franchise references, no watermarks or signatures.
Draw a single achievement badge icon, 512x512 px, square, on a fully transparent background (real PNG alpha, no checkerboard, no shadow outside the shape). Centered emblem, about 85% of the canvas, safe margin around it.
Style: flat vector sticker with a chunky dark-brown outline (#2B1A0E, about 10 px), simple bold shapes, 3 to 5 flat colors with one soft inner shade, no gradients on the outline, no photo realism, no tiny details, readable at 64x64 px. Warm retro-futuristic carnival space-racing mood: cream (#F1E3C0), sand (#D8B98A), orange (#FF8A2A), cocoa (#5A3A22), cold blue accent (#5BE0FF) used sparingly. Slightly worn, painted look, like a patch on a pilot's jacket.
No text, no letters, no numbers, no words. No people, no faces, no hands. One clear central symbol only.
Subject:

## Темы по достижениям

Формат: `id` — название — что нарисовать (вставлять после «Subject:»).

### Гонка и места
- `finish` — Первый блин — a pancake with a small checkered flag stuck in it, a bite-size golden pancake on a plate.
- `podium` — На подиуме — a three-step podium with a small spaceship silhouette on the top steps, bronze/silver/gold step colors.
- `win` — Любимец публики — a golden laurel wreath around a small round spaceship, confetti dots around.
- `loser` — Лузер — a small sad spaceship at the very back of an empty line, a droopy wilted flag, a tiny rain cloud over it.
- `book` — Как в книге — an open storybook with a tiny spaceship rising out of the pages, first place ribbon.
- `short_music` — Недолго музыка играла — a small music note cut in half by a stopwatch, the note is cracked and short.

### Чистота и повреждения
- `clean` — Без единой царапины — a shiny spaceship hull plate with a sparkle and one clean white check mark, no scratches.
- `intact` — Целёхонек — a spaceship with all its parts drawn as a tidy set of bolts and engines arranged around it, a heart shield.
- `crash_total` — Полный крах — a spaceship broken into many scattered pieces (wing, engine, hull plate) with a small explosion puff and sparks.
- `aggressor` — Агрессор — two small spaceships bumping nose to nose with a starburst impact between them.

### Высота и маршрут
- `low` — Под потолком — a canyon cross-section: spaceship flying low between two cliff walls, a dashed ceiling line above.
- `jeweler` — Ювелир — a spaceship carefully threading through a diamond-shaped gem, magnifying loupe, precise tiny arrows.
- `side` — Не как все — a road sign fork: the main road goes straight, a small spaceship turns onto a narrow side path.
- `lost3` — Заблудился в трёх соснах — three tall pine trees with a spaceship circling a U-turn arrow among them, a compass spinning.
- `unstick3` — Опять застрял — a spaceship stuck nose-down in sand with three circular return arrows (three small rings) around it.
- `brave` — Выпил для храбрости — a spaceship rolled sideways almost upside-down, a small mug with a bubble beside it.
- `eyes` — Глазами пилота — a big eye with a pilot cockpit window reflected in the pupil, a small ship silhouette inside.
- `speed` — Скоростной демон — a spaceship with speed lines and flames, a little horned silhouette hidden in the flame, a speedometer needle at maximum.

### Сложность
- `tourist` — Турист со стажем — a sun hat and a small camera hanging on a tiny spaceship, a travel sticker style.
- `veteran` — Видел всякое — an old scarred helmet with a stripe patch and a few service chevrons, a weary wink.
- `cyborg` — Киборг в душе — a half-organic heart and half-mechanical gear fused into one heart, cold blue glow.
- `academy` — Летная Академия — a graduation cap with a wing badge, five small stars in a row (five difficulty levels).

### Корабли
- `freya` — Старушка Фрея — an old but cozy spaceship with patched hull plates and a flower pot on its roof, a tiny heart.
- `seagull` — Чайка — a seagull flying with a long beak-nose spaceship shape, wings spread, in side view (the ship has a long pointed nose).
- `pilot_test` — Лётчик испытатель — a pilot goggles over a wrench and four small ship silhouettes in a row.
- `klutz` — Криворукий — two crossed bandaged hands drawn as simple mittens with stars of dizziness, no faces, ten small crash marks.

### Управление и настройки
- `gamepad` — Истинный геймер — a game controller with glowing orange buttons, a laurel leaf on each side.
- `keyboard` — Клавиатурный маньяк — a keyboard with a few keycaps flying off, a pair of key caps W A S D highlighted as plain squares (no letters).
- `custom` — Кастомайзер — a slider panel with three sliders and a small wrench.
- `custom_adv` — Продвинутый кастомайзер — a gear with a circuit pattern inside, several sliders and a star on top.
- `shor` — Шор — a game-controller thumb stick with two arrows (pitch and roll) crossing over it, a small crown on the stick.

### Музыка и интерфейс
- `melomaniac` — Меломан — a pair of headphones with sound waves and six little music notes in a circle.
- `tester` — Тестировщик — a magnifying glass over a small checklist with all items ticked, and a bug icon (beetle).
- `not_mine` — Это не мое — an open door with a small suitcase going out, a flag with a shrug (a tilde shape), no person.

### Платформы (без логотипов реальных компаний, только намёки)
- `os_win` — Установщик Винды — a generic four-pane window frame with a progress bar and a small wrench (NOT a company logo, just a plain window).
- `os_mac` — Маковод — a red poppy flower in a small pot with a tiny mouse cursor arrow as a leaf (poppy pun).
- `os_linux` — Собрал ядро — a corn kernel / walnut with a small gear inside it, compile-gear sparks (kernel pun, no animal mascots).
- `os_android` — Ржавое ведерко — an old rusty bucket with a small antenna and two tiny round lights (no robot character, no green droid shape).
- `os_ios` — Владелец огрызка — a bitten pear core (round pear, NOT an apple shape, no leaf with a bite cut like a company logo), a small tag.

### Новые (добавлены позже)
- `will` — Воля к победе — a spaceship with all engines torn off crawling over the finish line on its hull, trailing smoke, a small golden laurel branch above it.
- `timid` — Робкий гонщик — a small spaceship peeking out from behind a door frame with a hesitant pose, an exit sign with an arrow drawn as plain symbol (no text).
- `connoisseur` — Ценитель — a wine-tasting style glass with a tiny spaceship inside, a film clapperboard and a music note around it (no text).
- `graveyard` — Кладбище кораблей — a small hill of broken spaceship wrecks (four different hulls) with a lone flag stuck in the top, dusky sky.

- `hacker` — Мамкин хацкер — a cartoon beginner "hacker": a hooded silhouette-less hoodie with sunglasses floating over a laptop with a skull-and-crossbones-free simple green screen of random symbols, a coffee mug and a sticky note (no text, no face).

### Накопительные
- `record` — Личный рекорд — a stopwatch with a small star and a downward arrow (time got shorter).
- `beat_dev` — Победил Разработчика — a small trophy standing on a tiny keyboard (developer), a broken old record ribbon.
- `km1000` — Налётчик — a long road/trail of stars curving around a planet, a distance marker sign with an arrow (no numbers).
- `vet25` — Ветеран трассы — a medal with a chequered ribbon and a roman style cluster of small tick marks (no numbers, no letters).
- `collector` — Коллекционер грамот — a wooden display shelf with several small badges and one empty slot.

## Дополнительно
- Если GPT рисует текст или цифры — повторить с припиской: «absolutely no letters, digits or symbols that look like text».
- Для единого вида: генерировать все иконки в одном чате подряд и просить «same style as the previous badge».
- Карточка в игре — бежевая плашка (`#F1E3C0`) с тёмной обводкой; иконка 512×512 уменьшается до ≈64–96 px, поэтому форма должна читаться силуэтом.
- Скрытое достижение (`book`) в игре показывается как «?», пока не получено.
