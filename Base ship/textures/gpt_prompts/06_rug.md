# Ковёр кают-компании (5,4 x 4,0 м)

Перед промптом вставить блок ограничений из `00_common_rules.md`.
Файл-подсказка: `textures/interior/rug_layout_guide_1620x1200.png` (белая рамка = край ковра, жёлтая рамка = внутренняя граница каймы). Результат сохранить как `textures/interior/rug_albedo.png` (1620 x 1200, без прозрачности); дальше подключит `tools/build_rug_uv.py`.

## Промпт (вариант 1: ретро-геометрия)

Use the attached guide: a 1620x1200 landscape image, the whole canvas is a rug seen straight from above, edge to edge, no floor around it, no fringe, no shadows. Design an ORIGINAL retro geometric woven wool rug in a 1970s mid-century style: a wide ornamental border band (about 6% of the height) with a repeating small pattern, an inner thin stripe, and a large central field filled with interlocking concentric diamonds and rectangles around one big central medallion. Palette: warm burnt orange, deep teal, mustard yellow, cream and dark brown, muted and slightly faded like a lived-in rug, visible wool weave texture, subtle wear. Perfectly symmetrical left-right and top-bottom. Flat even lighting, no perspective, no folds, no text, no letters, no numbers, no logos, no figures.

## Промпт (вариант 2: спокойный, под космический интерьер)

Same layout rules as above. An ORIGINAL calm modern rug for a spaceship lounge: dark slate-blue wool field with a subtle woven texture, a thin cream double border line, a large central pattern made of concentric rounded rectangles and a faint orbit-ring motif in muted teal and warm copper, a few small star-like dots in the corners of the field. Soft, low contrast, no text, no logos.

## Заметки
- Любое сходство с известным реквизитом из кино нежелательно: делайте свой узор и свою палитру, без цитат и названий.
- Верх картинки = в сторону мостика (+Y), низ = к корме.
