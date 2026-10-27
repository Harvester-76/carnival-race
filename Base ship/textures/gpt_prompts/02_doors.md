# Двери коридора — лицевые текстуры для GPT

Перед промптом вставить блок ограничений из `00_common_rules.md`.

Двери стали простой плоской панелью (рамка, лампы-индикаторы и красный огонёк остались геометрией). Окно, ручка, табличка, панель состояния и полоса опасности рисуются текстурой.

| Дверь | Размер листа | Размер картинки | Карта-подсказка (прикладывать) | Куда сохранить |
|---|---|---|---|---|
| Каюты (10 шт., одна и та же картинка) | 1,30 x 2,40 м | 1040 x 1920 | `textures/interior/door_cabin_layout_guide_1040x1920.png` | `textures/interior/door_cabin_albedo.png` |
| Машинное отделение (торец коридора) | 1,70 x 2,60 м | 1088 x 1664 | `textures/interior/door_engine_layout_guide_1088x1664.png` | `textures/interior/door_engine_albedo.png` |

Картинка показана так, как её видит человек в коридоре (лицом к двери). В Blender картинка подменяется в материалах `MAT_Corr_DoorFront` и `MAT_Corr_DoorFrontEngine` (узел картинки), или просто положить файл поверх заглушки `door_*_albedo_placeholder.png`.

## Промпт: дверь каюты (1040 x 1920)

Use the attached image as an exact layout guide: a 1040x1920 portrait canvas that is ONE flat sliding cabin door of a spaceship, seen straight on, orthographic, no perspective. The yellow rectangles mark where elements go; do NOT draw the guide lines or the yellow labels themselves. Fill the whole canvas edge to edge with the door surface (no background, no wall around it, no frame outside the canvas).

Door surface: painted dark blue-grey steel (#4a5460) with a lighter worn edge, two shallow recessed rectangular panels above and below the window, thin panel seams, a few small rivets or hex bolts, light scratches and subtle edge wear, matte industrial finish. Clean, readable, game-ready PBR albedo (no baked lighting, no shadows cast outside, no ambient occlusion banding, no glare).
- WINDOW (upper middle): a rounded-rectangle viewport with a thick dark steel frame and tinted blue-grey glass with a very faint diagonal reflection streak.
- HANDLE (left side, middle): a vertical recessed grab handle with a small dark lock slot above it.
- NUMBER PLATE: a small blank light-grey plate with a thin border, leave it EMPTY (numbers are added later).
- STATUS PANEL (left side, upper): a small dark panel with one round red indicator and one round green indicator, unlit (no glow).
- KICK STRIP (bottom): a yellow-and-black diagonal hazard stripe band across the full width of the door, worn and scuffed.
Everything symmetric where possible, nothing outside the marked zones except panel seams and wear. No text at all; leave all plates unlabeled.

## Промпт: дверь машинного отделения (1088 x 1664)

Same as above, but the canvas is a 1088x1664 portrait HEAVY engine-room bulkhead door, thicker and more industrial: darker steel (#3f464e) with a diagonal-brushed texture, larger bolts around the perimeter, a central horizontal reinforcement band, and the same zones as in the attached guide (small round viewport, recessed handle, a WARNING PLATE as an empty light plate with a yellow border and a small generic hazard pictogram without any text, status panel, hazard kick strip at the bottom). No text.

## Что я сделаю после получения
Заменю заглушки, проверю развёртку (зеркальность для левых и правых дверей уже учтена), при необходимости добавлю номера кают отдельными табличками.
