# Материалы (авто-описание из spaceship_4.blend)

Материалы создаются в Unreal заново по ИМЕНИ СЛОТА (FBX переносит только имена). Параметры ниже взяты из Principled BSDF в Blender.
Текстуры цвета (albedo) импортировать как sRGB, normal/rough/metallic как Non-Color/Linear (значение colorspace указано). Normal-карты, сгенерированные скриптом, при необходимости импортировать с Flip Green Channel (проверить на глаз).

## Особые материалы

- **MAT_Airlock**: Использует ТРЕТИЙ UV-канал UV_Airlock (в UE индекс 2, TexCoord[2]).
- **MAT_Cabin_Light**: Эмиссия светильников (в UE MI с параметром яркости + Rect Light).
- **MAT_Cargo_Hatch**: Диск внутренней двери люка A (airlock_disc_cargo.png).
- **MAT_Cargo_Light**: Эмиссия светильников грузового отсека.
- **MAT_Engine_Core**: Свечение по взгляду: Layer Weight(Facing, Blend 0.5) -> Color Ramp (0.0: 0.45,0.75,1.0 ; 0.6: 0.06,0.32,1.0) -> Base Color и Emission Color; Emission Strength 3.0. В UE: Fresnel/ dot(normal,camera) -> Lerp двух цветов -> Emissive.
- **MAT_Engine_Glow**: Диск свечения у сопла (эмиссия).
- **MAT_Glass**: ОДНОСТОРОННЕЕ стекло: Translucent + Two Sided. Opacity = saturate(TwoSidedSign)*0.47+0.03 (снаружи 0.5, изнутри 0.03). Base Color (0.06,0.15,0.25), Roughness 0.04, Specular 0.6. Если эффект вывернут, поменять знак.
- **MAT_Holo**: Голо-окна: прозрачность по яркости, Additive/Translucent, атлас holo_atlas_2048x1280.png.
- **MAT_Holo_Column**: Цилиндр голограммы: прозрачность по яркости, 4 панели по окружности.
- **MAT_Hull_Inside**: Тёмный потёртый металл для граней изломов и торцов (скелет разлома).
- **Material**: Обшивка. Базовые текстуры по UV (UVMap): hull_albedo_4096/roughness/metallic; поверх шестигранники, наклейка decal_third_chance.png и маска выбитых ячеек hull_fallen_mask_4096.png (UV). В UE шестигранники рисовать ПО ФОРМУЛЕ из Data/hex_lattice.json (WorldAligned по доминирующей оси нормали), а не из hex_tile_*.

## Все материалы

| Материал | Где используется | Текстуры (colorspace) | Параметры |
|---|---|---|---|
| MAT_Airlock | SM_Hatch_A, SM_Hatch_B | airlock_atlas_2048.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.5; rough 0.5; alpha 1.0 |
| MAT_Cabin_AirlockDoor | SM_Cabin_Doors | airlock_inner_door_placeholder_1536x1152.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.4; rough 0.5; alpha 1.0 |
| MAT_Cabin_AirlockLeaf | SM_Cabin_Doors | door_engine_albedo.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.4; rough 0.5; alpha 1.0 |
| MAT_Cabin_Appliance | SM_Cabin_Kitchen | - | цвет (0.62,0.64,0.67); metal 0.8; rough 0.35; alpha 1.0 |
| MAT_Cabin_Black | SM_Cabin_Kitchen, SM_Cabin_Screens, SM_Cabin_Seats | - | цвет (0.015,0.017,0.02); metal 0.0; rough 0.15; alpha 1.0 |
| MAT_Cabin_Buttons | SM_Cabin_Dash | - | цвет (0.02,0.02,0.02); metal 0.0; rough 0.4; эмиссия (1.0,0.55,0.1); сила эм. 3.0; alpha 1.0 |
| MAT_Cabin_Cabinet | SM_Cabin_Kitchen | - | цвет (0.8,0.82,0.84); metal 0.0; rough 0.45; alpha 1.0 |
| MAT_Cabin_Ceiling | SM_Cabin_Shell | ceiling_bridge_albedo.png (sRGB); ceiling_bridge_rough.png (Non-Color); ceiling_bridge_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.1; rough 0.5; alpha 1.0 |
| MAT_Cabin_Counter | SM_Cabin_Kitchen | - | цвет (0.06,0.07,0.09); metal 0.0; rough 0.25; alpha 1.0 |
| MAT_Cabin_Dash | SM_Cabin_Dash, SM_Cabin_Doors, SM_Cabin_Seats | - | цвет (0.03,0.032,0.04); metal 0.5; rough 0.4; alpha 1.0 |
| MAT_Cabin_Edge | SM_Cabin_Lounge | - | цвет (0.8,0.62,0.05); metal 0.2; rough 0.6; alpha 1.0 |
| MAT_Cabin_Fabric | SM_Cabin_Lounge | - | цвет (0.16,0.22,0.28); metal 0.0; rough 0.9; alpha 1.0 |
| MAT_Cabin_Floor | SM_Cabin_Shell | floor_bridge_albedo.png (sRGB); floor_bridge_rough.png (Non-Color); floor_bridge_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.3; rough 0.5; alpha 1.0 |
| MAT_Cabin_Handle | SM_Cabin_Kitchen, SM_Cabin_Lounge, SM_Cabin_Seats | - | цвет (0.75,0.77,0.8); metal 0.9; rough 0.3; alpha 1.0 |
| MAT_Cabin_Keys | SM_Cabin_Keyboards | kb_albedo_2560x1024.png (sRGB); kb_emission_2560x1024.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.0; rough 0.45; эмиссия (1.0,1.0,1.0); сила эм. 2.0; alpha 1.0 |
| MAT_Cabin_Leather | SM_Cabin_Lounge, SM_Cabin_Seats | - | цвет (0.11,0.055,0.035); metal 0.0; rough 0.45; alpha 1.0 |
| MAT_Cabin_Light | SM_Cabin_Lounge | - | цвет (0.9,0.8,0.6); metal 0.0; rough 0.4; эмиссия (1.0,0.85,0.55); сила эм. 6.0; alpha 1.0 |
| MAT_Cabin_Panel | SM_Cabin_Doors, SM_Cabin_Lounge | - | цвет (0.4,0.42,0.45); metal 0.4; rough 0.5; alpha 1.0 |
| MAT_Cabin_Plant | SM_Cabin_Lounge | - | цвет (0.08,0.25,0.07); metal 0.0; rough 0.7; alpha 1.0 |
| MAT_Cabin_Pot | SM_Cabin_Lounge | - | цвет (0.55,0.5,0.45); metal 0.0; rough 0.8; alpha 1.0 |
| MAT_Cabin_Rug | SM_Cabin_Lounge | rug_albedo.png (sRGB) | цвет (0.45,0.12,0.1); metal 0.0; rough 0.95; alpha 1.0 |
| MAT_Cabin_Screen | SM_Cabin_Dash, SM_Cabin_Seats | - | цвет (0.02,0.05,0.09); metal 0.0; rough 0.2; эмиссия (0.1,0.45,0.9); сила эм. 1.2; alpha 1.0 |
| MAT_Cabin_Steel | SM_Cabin_AirlockCollar, SM_Cabin_Doors, SM_Cabin_Lounge … | - | цвет (0.55,0.56,0.58); metal 1.0; rough 0.3; alpha 1.0 |
| MAT_Cabin_Wall | SM_Cabin_Shell | wall_bridge_albedo.png (sRGB); wall_bridge_rough.png (Non-Color); wall_bridge_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.1; rough 0.5; alpha 1.0 |
| MAT_Cabin_Wood | SM_Cabin_Lounge | - | цвет (0.3,0.17,0.09); metal 0.0; rough 0.5; alpha 1.0 |
| MAT_Cargo_Floor | SM_Cargo_Shell | floor_cargo_albedo.png (sRGB); floor_cargo_rough.png (Non-Color); floor_cargo_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.6; rough 0.5; alpha 1.0 |
| MAT_Cargo_Hatch | SM_Cargo_Hatch | airlock_disc_cargo.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.5; rough 0.5; alpha 1.0 |
| MAT_Cargo_Light | SM_Cargo_Lights | - | цвет (0.9,0.8,0.6); metal 0.0; rough 0.4; эмиссия (1.0,0.85,0.55); сила эм. 6.0; alpha 1.0 |
| MAT_Cargo_Wall | SM_Cargo_Shell | wall_cargo_albedo.png (sRGB); wall_cargo_rough.png (Non-Color); wall_cargo_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.7; rough 0.5; alpha 1.0 |
| MAT_Console_Body | SM_Cabin_HoloColumn | - | цвет (0.035,0.07,0.16); metal 0.85; rough 0.3; alpha 1.0 |
| MAT_Console_Dark | SM_Cabin_HoloColumn | - | цвет (0.01,0.02,0.05); metal 0.5; rough 0.35; alpha 1.0 |
| MAT_Console_Glow | SM_Cabin_HoloColumn | - | цвет (0.2,0.8,1.0); metal 0.0; rough 0.5; эмиссия (0.25,0.85,1.0); сила эм. 6.0; alpha 1.0 |
| MAT_Console_Orange | SM_Cabin_HoloColumn | - | цвет (1.0,0.4,0.1); metal 0.0; rough 0.5; эмиссия (1.0,0.42,0.1); сила эм. 10.0; alpha 1.0 |
| MAT_Corr_Ceiling | SM_Corridor_Shell | ceiling_corr_albedo.png (sRGB); ceiling_corr_rough.png (Non-Color); ceiling_corr_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.2; rough 0.5; alpha 1.0 |
| MAT_Corr_Dark | SM_Corridor_Details, SM_Corridor_Doors | - | цвет (0.02,0.025,0.03); metal 0.5; rough 0.5; alpha 1.0 |
| MAT_Corr_Door | SM_Corridor_Doors | - | цвет (0.34,0.4,0.47); metal 0.7; rough 0.45; alpha 1.0 |
| MAT_Corr_DoorFront | SM_Corridor_Doors | door_cabin_albedo.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.3; rough 0.5; alpha 1.0 |
| MAT_Corr_DoorFrontEngine | SM_Corridor_Doors | door_engine_albedo.png (sRGB) | цвет (0.8,0.8,0.8); metal 0.3; rough 0.5; alpha 1.0 |
| MAT_Corr_DoorGlass | SM_Corridor_Doors | - | цвет (0.1,0.25,0.5); metal 0.0; rough 0.1; эмиссия (0.2,0.5,1.0); сила эм. 1.2; alpha 1.0 |
| MAT_Corr_Floor | SM_Corridor_Shell | floor_corr_albedo.png (sRGB); floor_corr_rough.png (Non-Color); floor_corr_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.4; rough 0.5; alpha 1.0 |
| MAT_Corr_Hazard | SM_Corridor_Details, SM_Corridor_Doors, SM_Corridor_Shell | - | цвет (0.75,0.58,0.04); metal 0.2; rough 0.6; alpha 1.0 |
| MAT_Corr_Light | SM_Corridor_Details, SM_Corridor_Doors | - | цвет (0.8,0.9,1.0); metal 0.0; rough 0.3; эмиссия (0.75,0.9,1.0); сила эм. 8.0; alpha 1.0 |
| MAT_Corr_Panel | SM_Corridor_Details, SM_Corridor_Doors | - | цвет (0.16,0.21,0.27); metal 0.6; rough 0.5; alpha 1.0 |
| MAT_Corr_Red | SM_Corridor_Doors | - | цвет (0.5,0.02,0.02); metal 0.0; rough 0.4; эмиссия (1.0,0.05,0.05); сила эм. 4.0; alpha 1.0 |
| MAT_Corr_Wall | SM_Corridor_Details, SM_Corridor_Shell | wall_corr_albedo.png (sRGB); wall_corr_rough.png (Non-Color); wall_corr_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.2; rough 0.5; alpha 1.0 |
| MAT_Engine_Core | SM_Engine_Shunt_Bot_L, SM_Engine_Shunt_Bot_R, SM_Engine_Shunt_Top_L … | - | цвет (0.25,0.55,1.0); metal 0.0; rough 0.5; эмиссия (0.2,0.5,1.0); сила эм. 3.0; alpha 1.0 |
| MAT_Engine_Glow | SM_Engine_Shunt_Bot_L, SM_Engine_Shunt_Bot_R, SM_Engine_Shunt_Top_L … | - |  |
| MAT_Engines | SM_Engine_Shunt_Bot_L, SM_Engine_Shunt_Bot_R, SM_Engine_Shunt_Top_L … | engine_albedo_4096.png (sRGB); engine_roughness_4096.png (Non-Color); engine_metallic_4096.png (Non-Color) | цвет (0.12,0.12,0.14); metal 1.0; rough 0.35; alpha 1.0 |
| MAT_Glass | SM_Glass_01, SM_Glass_02, SM_Glass_03 … | - | цвет (0.06,0.15,0.25); metal 0.0; rough 0.04; alpha 0.25 |
| MAT_Holo | SM_Cabin_Holo | holo_atlas_2048x1280.png (sRGB) |  |
| MAT_Holo_Column | SM_Cabin_HoloTube | holo_column.png (sRGB) |  |
| MAT_Holo_Emitter | SM_Cabin_Holo | - |  |
| MAT_Hull_Inside | SM_Hull_Solid, SM_Hull_Solid, SM_Hull_Solid … | - | цвет (0.07,0.06,0.055); metal 0.6; rough 0.7; alpha 1.0 |
| MAT_LED_Strip | SM_Hull_Body, SM_Hull_Body_LOD1, SM_Hull_Solid | - | цвет (0.85,0.95,1.0); metal 0.0; rough 0.5; эмиссия (0.85,0.95,1.0); сила эм. 28.0; alpha 1.0 |
| MAT_Lamp_Lens | SM_Spotlight_Belly_FL, SM_Spotlight_Belly_FR, SM_Spotlight_Belly_RL … | - | цвет (1.0,0.93,0.78); metal 0.0; rough 0.5; эмиссия (1.0,0.93,0.78); сила эм. 40.0; alpha 1.0 |
| MAT_Marker_Glow | SM_Wing_L, SM_Wing_R | - |  |
| MAT_Marker_Red | SM_Wing_L, SM_Wing_R | - | цвет (1.0,0.03,0.02); metal 0.0; rough 0.5; эмиссия (1.0,0.0,0.0); сила эм. 250.0; alpha 1.0 |
| MAT_Pipes | SM_Hull_Body, SM_Hull_Body_LOD1, SM_Hull_Solid | - | цвет (0.55,0.38,0.2); metal 1.0; rough 0.4; alpha 1.0 |
| MAT_Room_Ceiling | SM_Room_01, SM_Room_02, SM_Room_03 … | ceiling_room_albedo.png (sRGB); ceiling_room_rough.png (Non-Color); ceiling_room_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.0; rough 0.5; alpha 1.0 |
| MAT_Room_Crate | SM_Room_06 | - | цвет (0.3,0.36,0.22); metal 0.3; rough 0.65; alpha 1.0 |
| MAT_Room_Crate2 | SM_Room_06 | - | цвет (0.45,0.3,0.12); metal 0.3; rough 0.65; alpha 1.0 |
| MAT_Room_Cross | SM_Room_01 | - | цвет (0.6,0.02,0.02); metal 0.0; rough 0.4; эмиссия (1.0,0.1,0.1); сила эм. 3.0; alpha 1.0 |
| MAT_Room_Dark | SM_Room_01, SM_Room_02, SM_Room_03 … | - | цвет (0.03,0.035,0.04); metal 0.5; rough 0.5; alpha 1.0 |
| MAT_Room_Fabric | SM_Room_02, SM_Room_04, SM_Room_08 … | - | цвет (0.12,0.22,0.4); metal 0.0; rough 0.9; alpha 1.0 |
| MAT_Room_Fabric2 | SM_Room_02, SM_Room_03, SM_Room_04 … | - | цвет (0.35,0.2,0.12); metal 0.0; rough 0.9; alpha 1.0 |
| MAT_Room_Floor | SM_Room_01, SM_Room_02, SM_Room_03 … | floor_room_albedo.png (sRGB); floor_room_rough.png (Non-Color); floor_room_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.0; rough 0.5; alpha 1.0 |
| MAT_Room_Glass | SM_Room_07 | - | цвет (0.35,0.55,0.7); metal 0.0; rough 0.05; alpha 0.3 |
| MAT_Room_Hazard | SM_Room_06 | - | цвет (0.75,0.58,0.04); metal 0.2; rough 0.6; alpha 1.0 |
| MAT_Room_Light | SM_Room_01, SM_Room_02, SM_Room_03 … | - | цвет (0.8,0.9,1.0); metal 0.0; rough 0.3; эмиссия (0.8,0.92,1.0); сила эм. 7.0; alpha 1.0 |
| MAT_Room_Metal | SM_Room_01, SM_Room_02, SM_Room_03 … | - | цвет (0.38,0.41,0.45); metal 0.9; rough 0.35; alpha 1.0 |
| MAT_Room_Mirror | SM_Room_07 | - | цвет (0.7,0.78,0.85); metal 1.0; rough 0.05; alpha 1.0 |
| MAT_Room_Panel | SM_Room_01, SM_Room_02, SM_Room_03 … | - | цвет (0.22,0.27,0.33); metal 0.5; rough 0.5; alpha 1.0 |
| MAT_Room_Pillow | SM_Room_02, SM_Room_03, SM_Room_04 … | - | цвет (0.75,0.78,0.8); metal 0.0; rough 0.9; alpha 1.0 |
| MAT_Room_Rug | SM_Room_02, SM_Room_03, SM_Room_04 … | - | цвет (0.28,0.07,0.07); metal 0.0; rough 1.0; alpha 1.0 |
| MAT_Room_Screen | SM_Room_01, SM_Room_02, SM_Room_03 … | - | цвет (0.05,0.2,0.3); metal 0.0; rough 0.2; эмиссия (0.1,0.6,1.0); сила эм. 3.0; alpha 1.0 |
| MAT_Room_Wall | SM_Room_01, SM_Room_02, SM_Room_03 … | wall_room_albedo.png (sRGB); wall_room_rough.png (Non-Color); wall_room_normal.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.0; rough 0.5; alpha 1.0 |
| MAT_Room_White | SM_Room_01, SM_Room_07 | - | цвет (0.8,0.82,0.84); metal 0.1; rough 0.4; alpha 1.0 |
| MAT_Room_Wood | SM_Room_02, SM_Room_03, SM_Room_04 … | - | цвет (0.45,0.33,0.22); metal 0.0; rough 0.6; alpha 1.0 |
| MAT_Screen_Big | SM_Cabin_Screens | screen_big.png (sRGB) |  |
| MAT_Screen_Climate | SM_Cabin_Screens | screen_climate.png (sRGB) |  |
| Material | SM_HexPlate_A, SM_HexPlate_B, SM_HexPlate_C … | hull_albedo_4096.png (sRGB); hull_roughness_4096.png (Non-Color); hull_metallic_4096.png (Non-Color); hex_tile_height_2k_8bit.png (Non-Color); hex_tile_cellid_2k.png (Non-Color); decal_third_chance.png (sRGB); hull_fallen_mask_4096.png (Non-Color) | цвет (0.8,0.8,0.8); metal 0.0; rough 0.5; alpha 1.0 |
