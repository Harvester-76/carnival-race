extends RefCounted
## Anisotropic aerodynamic drag. SI units throughout.
## Velocity is resolved in ship-local axes so lateral drag cannot masquerade as a
## general-purpose stabilizer. Areas are effective reference areas per axis.

const DEFAULT_PROFILE := {
	"front_area_m2": 18.0,
	"side_area_m2": 24.0,
	"top_area_m2": 18.0,
	"cd_mach": [
		Vector2(0.0, 0.24),
		Vector2(0.8, 0.25),
		Vector2(1.0, 0.34),
		Vector2(1.2, 0.38),
		Vector2(2.0, 0.32),
		Vector2(3.0, 0.29),
		Vector2(5.0, 0.27),
		Vector2(8.0, 0.26)
	]
}

static func cd_for_mach(mach: float, profile: Dictionary = DEFAULT_PROFILE) -> float:
	var table: Array = profile.get("cd_mach", DEFAULT_PROFILE["cd_mach"])
	if table.is_empty():
		return 0.3
	if mach <= float(table[0].x):
		return float(table[0].y)
	for i in range(1, table.size()):
		var upper: Vector2 = table[i]
		var lower: Vector2 = table[i - 1]
		if mach <= upper.x:
			var span: float = maxf(upper.x - lower.x, 0.0001)
			return lerpf(lower.y, upper.y, clampf((mach - lower.x) / span, 0.0, 1.0))
	return float(table[table.size() - 1].y)

static func evaluate_drag(body: RigidBody3D, density_kg_m3: float, speed_of_sound_mps: float, wind_mps: Vector3 = Vector3.ZERO, profile: Dictionary = DEFAULT_PROFILE) -> Dictionary:
	var relative_velocity := body.linear_velocity - wind_mps
	var speed := relative_velocity.length()
	if speed < 0.01 or density_kg_m3 <= 0.0 or speed_of_sound_mps <= 0.0:
		return {
			"force_n": Vector3.ZERO, "longitudinal_force_n": Vector3.ZERO,
			"transverse_force_n": Vector3.ZERO, "local_velocity_mps": Vector3.ZERO,
			"local_force_n": Vector3.ZERO, "speed_mps": speed,
			"mach": 0.0, "cd": 0.0, "area_m2": 0.0,
			"dynamic_pressure_pa": 0.0
		}

	var basis := body.global_transform.basis
	var local_velocity := basis.inverse() * relative_velocity
	var mach := speed / speed_of_sound_mps
	var cd := cd_for_mach(mach, profile)
	var dynamic_pressure := 0.5 * density_kg_m3 * speed * speed

	# Independent quadratic components: forward (local Z), lateral (X), vertical (Y).
	# This avoids the previous projected-area model's 65/45 m2 side/top penalty.
	var local_drag := Vector3(
		-0.5 * density_kg_m3 * cd * float(profile.get("side_area_m2", DEFAULT_PROFILE["side_area_m2"])) * local_velocity.x * absf(local_velocity.x),
		-0.5 * density_kg_m3 * cd * float(profile.get("top_area_m2", DEFAULT_PROFILE["top_area_m2"])) * local_velocity.y * absf(local_velocity.y),
		-0.5 * density_kg_m3 * cd * float(profile.get("front_area_m2", DEFAULT_PROFILE["front_area_m2"])) * local_velocity.z * absf(local_velocity.z)
	)
	var longitudinal_local := Vector3(0.0, 0.0, local_drag.z)
	var transverse_local := Vector3(local_drag.x, local_drag.y, 0.0)
	var total_force := basis * local_drag
	var longitudinal_force := basis * longitudinal_local
	var transverse_force := basis * transverse_local
	var effective_area := total_force.length() / maxf(dynamic_pressure * cd, 0.0001)

	return {
		"force_n": total_force,
		"longitudinal_force_n": longitudinal_force,
		"transverse_force_n": transverse_force,
		"local_velocity_mps": local_velocity,
		"local_force_n": local_drag,
		"speed_mps": speed,
		"mach": mach,
		"cd": cd,
		"area_m2": effective_area,
		"dynamic_pressure_pa": dynamic_pressure
	}
