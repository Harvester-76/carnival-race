# Большой экран, климат-экран и цилиндрическая голограмма (кают-компания)

Перед каждым промптом вставить блок ограничений из `00_common_rules.md`.
В игре эти экраны потом заменятся реальными данными корабля (render target); картинки нужны для MVP и как оформление интерфейса.

| Что | Куда в сцене | Размер картинки | Карта-подсказка | Куда сохранить |
|---|---|---|---|---|
| Большой экран 2,9 x 1,63 м | правая стена над диваном | 1920 x 1080 | `textures/interior/screen_big_layout_guide_1920x1080.png` | `textures/interior/screen_big.png` |
| Климат-экран 1,1 x 0,69 м | левая стена правее шлюза | 1024 x 640 | `textures/interior/screen_climate_layout_guide_1024x640.png` | `textures/interior/screen_climate.png` |
| Цилиндрическая голограмма (диаметр 2,0 м (внутри помещается человек в T-позе), высота 2,5 м) | колонна в кают-компании (x −1,6, y 24,75) | 2560 x 1024, альфа, бесшовна по горизонтали | `textures/interior/holo_column_layout_guide_2560x1024.png` | `textures/interior/holo_column.png` |

Заглушки сейчас: `screen_big_placeholder_1920x1080.png`, `screen_climate_placeholder_1024x640.png`, `holo_column_placeholder_2560x1024.png`. Достаточно положить готовый файл поверх (картинка подхватится в материалах `MAT_Screen_Big`, `MAT_Screen_Climate`, `MAT_Holo_Column`; материалы светятся, яркость в узле Emission).

## Большой экран (1920 x 1080)

Use the attached image as a guide for the 16:9 frame; fill the whole canvas, no border, no bezel. Original sci-fi ambient display for a spaceship lounge wall: a calm, dark deep-blue and teal screen showing a stylized schematic star map of an unnamed star system with orbit lines and 5 generic planets (no names), a small ship-position marker, a thin coordinate grid, a slim status strip at the bottom with 4 small generic gauges (PWR, O2, TEMP, NAV) and numbers only, and a soft nebula glow on one side. Low contrast, easy on the eyes, minimal UI, large readable shapes. No real-world constellations with names, no logos, no sentences.

## Климат-экран (1024 x 640)

Use the attached guide: a 1024x640 canvas, a title bar at the top and five horizontal rows below. Original dark-teal climate-control panel: title bar with the generic label CLIMATE and a small AUTO badge; five rows, each with a short label (TEMP, HUM, O2, CO2, PRES), a large number with its unit, and a horizontal bar gauge; the TEMP row has a small up/down arrows control. Cyan (#5be0ff) and white lines on a very dark teal background (#06161e), amber (#ffb347) for the AUTO badge only. Flat 2D, crisp, no glare, no real text beyond those labels and numbers.

## Цилиндрическая голограмма (2560 x 1024, PNG с альфой, бесшовная по горизонтали)

Use the attached guide: a 2560x1024 canvas that will be wrapped around a vertical cylinder (the left and right edges must connect seamlessly; the image wraps 360 degrees, 4 quarters of 640 px). Transparent PNG with a real alpha channel, nothing opaque or dark in the background. Draw thin glowing cyan (#5be0ff) lines only: a vertical stack of horizontal scan lines, four large data panels (one per quarter) separated by thin vertical dividers, each panel with a different original graphic (a rotating-ring diagram, a bar chart of 8 bars with 2-digit labels, a waveform, and a wireframe silhouette of a generic ship side view), a few small amber (#ffb347) markers, bright lines along the very top and very bottom edges (10 px). Keep the middle band mostly airy so that the far side of the cylinder stays readable. No text except numbers and short generic labels.
