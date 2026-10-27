# Промпты для GPT: текстура корпуса SM_Spaceship

Размер корабля: около 82 м в длину (масштаб x15.2). Основной атлас корпуса 4096x4096 даёт около 3 см на пиксель, поэтому в нём только крупные вещи: краска, полосы, люки, пятна ржавчины, подтёки. Мелкие заклёпки и шестигранник идут отдельным тайлом (hex_tile_*) в Unreal.

Прикладывайте к запросу картинки:
1. hull_uv_region_map_with_edges_4k.png (цветная карта зон)
2. референс-рисунок 517e...jpg (форма и расположение деталей)

Легенда зон: зелёный = верх, синий = борта, красный = днище, оранжевый = задняя панель у двигателей, жёлтый = нос, фиолетовый = крылья и штанги, бирюзовый = трубки.

---

## Вариант A (рекомендуемый): бесшовные образцы, потом я собираю атлас по маскам

Сгенерируйте ПО ОДНОМУ запросу каждый из четырёх образцов. Каждый: бесшовный (tileable), 2048x2048, вид строго сверху, без перспективы, без освещения и теней, без объектов и надписей.

### A1. Чистая белая краска (верх, борта, крылья)
```
Seamless tileable texture, 2048x2048, top-down flat orthographic view, no perspective, no lighting, no baked shadows.
Painted white sci-fi spaceship hull plating: large rectangular panels with fine panel seams, tiny scratches, very light grey dust, faint chipped paint at panel edges, a few small rust-coloured specks. Overall color stays clean off-white (about RGB 235,235,232).
Style: realistic game PBR albedo, hard-surface, subtle wear only. No text, no logos, no bolts bigger than 3 px.
```

### A2. Сильный износ (днище и задняя панель)
```
Seamless tileable texture, 2048x2048, top-down flat orthographic view, no perspective, no lighting, no baked shadows.
Heavily weathered metal spaceship underbelly: dull grey and brown-red rusted steel, streaky rust runs, oil and soot stains, exhaust grime, worn paint remnants, scratches, dirty metallic tones. Mostly mid-dark values, warm rust oranges and cold steel greys.
Style: realistic game PBR albedo, hard-surface. No text, no logos, no large objects.
```

### A3. Чёрная краска (полосы)
```
Seamless tileable texture, 2048x2048, top-down flat orthographic view, no perspective, no lighting, no baked shadows.
Satin black painted metal with light wear: fine scratches showing grey primer, tiny chips at the edges of panels, slight dust. Overall color near black (about RGB 25,25,28) with grey scratches.
Style: realistic game PBR albedo. No text, no logos.
```

### A4. Моторы в хорошем состоянии
```
Seamless tileable texture, 2048x2048, top-down flat orthographic view, no perspective, no lighting, no baked shadows.
Clean machined dark steel for turbine casings: brushed gun-metal grey with very light heat tint near edges, tiny scratches, no rust. Overall color mid-dark neutral grey (about RGB 90,92,98).
Style: realistic game PBR albedo. No text, no logos.
```

Вернуть мне все четыре файла (PNG). Дальше я собираю атлас: белая основа + чёрные полосы, износ усиливается на днище и заднике по маске зон, люки и стыки панелей из геометрии.

---

## Вариант B (экспериментальный): рисовать сразу по развёртке

Модель изображений не гарантирует точного попадания в развёртку, поэтому результат придётся подгонять. Если захотите попробовать:
```
You get a UV layout of a spaceship hull colored by zone (green top, blue sides, red belly, orange rear panel, yellow nose, purple wings, cyan pipes) and a reference sketch. Paint a 4096x4096 albedo (base color) texture that fits exactly into the colored UV islands, keeping the island borders and positions unchanged. Do not add lighting or shadows.
Hull: white painted metal. Black racing stripes: one wide stripe along each side at window height, two narrow parallel stripes along the top centerline from nose to tail (stripes continue across the zones that belong to the same surface). Roof hatches as rectangular hatch outlines with thin dark panel lines on the green zones. Panel seams everywhere, fine scratches, small rust specks and streaks of dirt running downward on the sides.
Heavier wear on the red zone (belly) and the orange zone (rear panel): rust-brown and metallic grey tones, soot, oil stains, scratches. Wings (purple) moderately worn. Leave the dark background (outside the islands) as flat dark grey. No text.
```

---

## Мелкая фактура в Unreal (шестигранник с рамкой и швы, без заклёпок)
Заклёпки на облицовке не нужны. Они будут только у креплений люков и других деталей, отдельно от этих текстур.
Файлы: hex_tile_height_2k.png (16 бит), hex_tile_height_2k_8bit.png, hex_tile_normal_dx_2k.png (формат DirectX, для Unreal).
- Тайл бесшовный, 14 ячеек по ширине. Размер тайла около 1.7 м в мире, то есть ячейка около 12 см.
- В материале корпуса: WorldAlignedTexture или TexCoord с масштабом 1/170 (в сантиметрах), нормаль смешать с основной через BlendAngleCorrectedNormals, высоту использовать для затемнения швов.
