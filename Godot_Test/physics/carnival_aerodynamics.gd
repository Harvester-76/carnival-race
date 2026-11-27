extends RefCounted
## Anisotropic aerodynamic drag. SI units throughout.
## Effective area and Cd scale are independently configurable for each exposed face.

# Сопротивление после звукового барьера не спадает, а растёт: атмосфера Карнавала сама тормозит корабль.
# Эталон: равновесие ~3000 м/с при полном газе на высоте 2000 м (базовый корпус, cd_scale носа 2).
# Чем выше — тем меньше плотность (carnival_atmosphere.gd) и тем выше равновесная скорость.
const DEFAULT_CD_MACH := [
	Vector2(0.0, 0.24), Vector2(0.8, 0.25), Vector2(1.0, 0.34),
	Vector2(1.2, 0.38), Vector2(2.0, 0.34), Vector2(4.0, 0.355),
	Vector2(6.0, 0.38), Vector2(8.0, 0.39), Vector2(10.5, 0.40),
	Vector2(14.0, 0.415), Vector2(20.0, 0.43)
]
const DEFAULT_PROFILE := {
	"nose": {"area_m2": 18.0, "cd_scale": 1.0},
	"tail": {"area_m2": 18.0, "cd_scale": 1.0},
	"left": {"area_m2": 24.0, "cd_scale": 1.0},
	"right": {"area_m2": 24.0, "cd_scale": 1.0},
	"top": {"area_m2": 60.0, "cd_scale": 1.0},
	"bottom": {"area_m2": 60.0, "cd_scale": 1.0},
	"cd_mach": DEFAULT_CD_MACH
}

static func cd_for_mach(mach: float, profile: Dictionary = DEFAULT_PROFILE) -> float:
	var table: Array = profile.get("cd_mach", DEFAULT_CD_MACH)
	if table.is_empty(): return 0.3
	if mach <= float(table[0].x): return float(table[0].y)
	for i in range(1, table.size()):
		var upper: Vector2 = table[i]
		var lower: Vector2 = table[i - 1]
		if mach <= upper.x:
			return lerpf(lower.y, upper.y, clampf((mach - lower.x) / maxf(upper.x - lower.x, 0.0001), 0.0, 1.0))
	return float(table[table.size() - 1].y)

static func _face(profile: Dictionary, key: String) -> Dictionary:
	var value = profile.get(key, DEFAULT_PROFILE[key])
	return value if typeof(value) == TYPE_DICTIONARY else DEFAULT_PROFILE[key]

static func evaluate_drag(body: RigidBody3D, density_kg_m3: float, speed_of_sound_mps: float, wind_mps: Vector3 = Vector3.ZERO, profile: Dictionary = DEFAULT_PROFILE) -> Dictionary:
	var relative_velocity := body.linear_velocity - wind_mps
	var speed := relative_velocity.length()
	if speed < 0.01 or density_kg_m3 <= 0.0 or speed_of_sound_mps <= 0.0:
		return {"force_n": Vector3.ZERO, "longitudinal_force_n": Vector3.ZERO, "transverse_force_n": Vector3.ZERO, "local_velocity_mps": Vector3.ZERO, "local_force_n": Vector3.ZERO, "speed_mps": speed, "mach": 0.0, "cd": 0.0, "area_m2": 0.0, "dynamic_pressure_pa": 0.0}
	var basis := body.global_transform.basis
	var local_velocity := basis.inverse() * relative_velocity
	var mach := speed / speed_of_sound_mps
	var base_cd := cd_for_mach(mach, profile)
	var dynamic_pressure := 0.5 * density_kg_m3 * speed * speed

	# Выбирается наветренная грань: нормаль грани сонаправлена относительной скорости.
	# Нос = -Z (как в main.gd): полёт вперёд (v_z < 0) бьёт в nose. Правый борт = +X, верх = +Y.
	var x_face := "right" if local_velocity.x >= 0.0 else "left"
	var y_face := "top" if local_velocity.y >= 0.0 else "bottom"
	var z_face := "tail" if local_velocity.z >= 0.0 else "nose"
	var xf := _face(profile, x_face)
	var yf := _face(profile, y_face)
	var zf := _face(profile, z_face)
	var local_drag := Vector3(
		-0.5 * density_kg_m3 * base_cd * float(xf.get("cd_scale", 1.0)) * float(xf.get("area_m2", 24.0)) * local_velocity.x * absf(local_velocity.x),
		-0.5 * density_kg_m3 * base_cd * float(yf.get("cd_scale", 1.0)) * float(yf.get("area_m2", 60.0)) * local_velocity.y * absf(local_velocity.y),
		-0.5 * density_kg_m3 * base_cd * float(zf.get("cd_scale", 1.0)) * float(zf.get("area_m2", 18.0)) * local_velocity.z * absf(local_velocity.z)
	)
	var longitudinal_local := Vector3(0.0, 0.0, local_drag.z)
	var transverse_local := Vector3(local_drag.x, local_drag.y, 0.0)
	var total_force := basis * local_drag
	return {
		"force_n": total_force,
		"longitudinal_force_n": basis * longitudinal_local,
		"transverse_force_n": basis * transverse_local,
		"local_velocity_mps": local_velocity,
		"local_force_n": local_drag,
		"speed_mps": speed,
		"mach": mach,
		"cd": base_cd,
		"area_m2": total_force.length() / maxf(dynamic_pressure * base_cd, 0.0001),
		"dynamic_pressure_pa": dynamic_pressure,
		"faces": [x_face, y_face, z_face]
	}
