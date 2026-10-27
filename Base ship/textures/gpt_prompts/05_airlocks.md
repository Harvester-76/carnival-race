# Шлюзы: два внешних люка (диски) и внутренняя дверь шлюза кают-компании

Перед каждым промптом вставить блок ограничений из `00_common_rules.md`.

Атлас шлюзов `textures/interior/airlock_atlas_2048.png` собирает `textures/tools/compose_airlock.py` (в UV_Airlock). Сейчас там заглушки. Диски рисуются каждый отдельно как квадратная картинка, скрипт вклеит их в атлас по кругам (я это сделаю сам, ничего резать не нужно).

| Что | Размер на корабле | Картинка | Карта-подсказка | Куда сохранить |
|---|---|---|---|---|
| Грузовой люк A (левый борт, корма, y от −15 до −6) | диск 9 м | 1536 x 1536, квадрат | `textures/interior/airlock_disc_cargo_guide_1536.png` | `textures/interior/airlock_disc_cargo.png` |
| Люк кают-компании B (левый борт, y около 20) | диск 4,4 м | 1536 x 1536, квадрат | `textures/interior/airlock_disc_hatch_guide_1536.png` | `textures/interior/airlock_disc_hatch.png` |
| Внутренняя дверь шлюза (лист) | 3,96 x 2,98 м | 1536 x 1152 | `textures/interior/airlock_inner_door_layout_guide_1536x1152.png` | `textures/interior/airlock_inner_door.png` |

Для дисков: белая окружность на карте-подсказке это внешний край кольца-фланца (100% радиуса), жёлтая окружность это внутренний плоский диск люка (около 80% радиуса). Круг должен касаться всех четырёх краёв квадрата, за кругом прозрачный фон (PNG с альфой) или чёрный. В центре плоского диска нарисован сам люк; кольцо снаружи это рама.

## Грузовой люк A (диск 9 м)

Use the attached guide: a 1536x1536 square, the outer white circle is the edge of the hatch frame, the inner yellow circle is the flat hatch door. Draw a heavy circular spaceship cargo hatch seen straight on, orthographic. Outer ring (between the circles): a thick steel frame with a yellow-and-black diagonal hazard band, 24 hex bolts evenly spaced, worn paint, scuffs. Inner disc: dark blue-grey steel (#4a5460) hatch door split into 12 radial segments with thin recessed seams, three concentric reinforcement rings, a small central locking hub, a rectangular access door outline in the lower middle with two small unlit indicator lights (one red, one green), a few panel plates, subtle dirt and edge wear. Flat even lighting, no shadows, no text, no numbers, no logos. Everything outside the white circle transparent.

## Люк кают-компании B (диск 4,4 м)

Same layout rules as above but a smaller personnel airlock hatch: outer frame with a simple hazard band and 16 bolts; inner disc in dark blue-grey steel, 8 radial segments, a clear central round viewport with a thick steel ring and tinted blue glass, a recessed wheel handle on the right side, a status panel with two unlit indicator lights (red and green) on the left, light scuffs. No text, no numbers, no logos. Outside the white circle transparent.

## Внутренняя дверь шлюза (1536 x 1152)

Use the attached guide: a flat rectangular heavy airlock door leaf seen straight on, filling the whole canvas edge to edge. Dark blue-grey steel (#4a5460) with a thick steel border, four recessed panels, small hex bolts. Marked zones: WINDOW (upper middle, rounded rectangle viewport with a thick dark frame and tinted glass), WHEEL HANDLE (right middle, a recessed circular wheel handle), STATUS LIGHTS (upper left, a dark panel with two unlit round indicators red and green), HAZARD STRIP (a yellow-and-black diagonal band along the bottom). Do not draw the guide lines or labels. No text, no numbers, no logos, no shadows.

## Что я сделаю после получения
- вклею диски в атлас `UV_Airlock` и проверю на корабле, при необходимости подстрою круги;
- подключу картинку к внутренней двери (`MAT_Cabin_AirlockDoor`);
- манжета между рамкой двери и стеной (`SM_Cabin_AirlockCollar`) красится стальным материалом кабины, при желании дам ей отдельную текстуру.
