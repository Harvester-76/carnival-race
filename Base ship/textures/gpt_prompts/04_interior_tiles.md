# Тайлы стен, пола и потолка (9 штук) — albedo для GPT

Перед каждым промптом вставить блок ограничений из `00_common_rules.md`.

Каждый тайл покрывает 2 x 2 м, бесшовный по всем четырём краям, вид строго сверху (плоский ортографический, как скан материала), только albedo (цвет): без освещения, теней, бликов, перспективы и виньетки. Размер 2048 x 2048, PNG.
Нормали и шероховатость я сделаю сам из albedo. Файлы класть в `textures/interior/tiles/` с именами `<имя>_albedo.png` поверх заглушек, затем я запускаю `python3 textures/tools/make_interior_tiles.py --from-albedo` и обновляю материалы.
Рисунок швов должен делить тайл ровно по сетке, чтобы стыки совпадали: указанное число панелей по каждой стороне (например «2 x 2 панели» = шов ровно посередине по обеим осям).

## Общая часть промпта (добавлять к каждому)

Seamless tileable PBR albedo texture, top-down orthographic, 2048x2048, covering exactly 2 x 2 meters of a spaceship interior surface. Left and right edges match, top and bottom edges match. Flat even lighting baked out: no shadows, no highlights, no ambient occlusion, no vignette, no perspective. Realistic hand-finished game texture with subtle wear, no text, no logos, no numbers, no signs. Panel seams must lie exactly on a regular grid of N x N panels as specified below, with the seam lines passing through the exact centre of the image when N is even.

## Рубка и кают-компания

1. `wall_bridge` — 2 x 2 панели. Painted light warm-grey (#9e9c94) metal wall panels with thin dark recessed seams, small hex bolts near each panel corner, very light scuffs and a few hairline scratches, slightly different tone per panel.
2. `floor_bridge` — 4 x 4 плит. Dark graphite (#1c1f24) deck plating, 4 x 4 square plates with narrow seams and tiny corner bolts, fine anti-slip grain, light scuffing along the seams.
3. `ceiling_bridge` — 2 x 2 панели. Matte off-white (#cdcdd1) ceiling panels with thin seams and a few tiny maintenance screws, very clean.

## Коридор

4. `wall_corr` — 2 x 2 панели. Blue-grey (#404c5c) industrial corridor wall panels, thin dark seams, bolts at the corners, edge wear showing bare steel, a few light scratches.
5. `floor_corr` — 4 x 4 плит. Dark grey (#2a2c31) steel diamond-tread plates (small raised diagonal bars arranged in alternating directions), 4 x 4 plates with seams, subtle worn bright metal on the raised bars.
6. `ceiling_corr` — 4 x 4 панелей. Dark blue-grey (#333b45) ceiling panels with a fine regular grid of small round perforations inside each panel and thin seams.

## Каюты

7. `wall_room` — 2 x 2 панели. Soft warm off-white (#bdb8aa) cabin wall panels with a subtle fabric-like or satin paint texture, very thin light seams, no bolts, gentle wear.
8. `floor_room` — планки. Warm medium-brown (#573b24) wood-effect composite floor planks, 16 planks across the tile (each 12.5 cm wide), staggered joints, visible fine grain, slight tone variation between planks, thin dark gaps.
9. `ceiling_room` — 2 x 2 панели. Clean matte white (#dcdcdc) ceiling panels, thin seams, a few tiny screws.

## Что проверить в результате
1. Края стыкуются: положить два тайла рядом (проверю я сам при подключении).
2. Нет теней, бликов и текста.
3. Швы совпадают с указанной сеткой (иначе стыки стен будут «ехать»).
