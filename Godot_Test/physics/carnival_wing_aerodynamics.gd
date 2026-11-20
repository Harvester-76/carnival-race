extends RefCounted
## Aerodynamic lift and induced/profile drag for detachable wing meshes.
## Geometry is measured from the mesh actually instantiated by the ship.
## SI units throughout.

const DEFAULT_WING_PROFILE := {
	"enabled": true,
	"cl_max": 1.2,
	"profile_cd": 0.025,
	"oswald_efficiency": 0.8,
	"min_speed_mps": 5.0
}

static func build_surfaces(parts: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in parts.keys():
		var name := String(key)
		if not name.begins_with("SM_Wing_Top_") and not name.begins_with("SM_Wing_Bot_"):
			continue
		var mi := parts[key] as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var faces := mi.mesh.get_faces()
		if faces.size() < 3:
			continue
		var projected_area_sum := 0.0
		var weighted_center := Vector3.ZERO
		for i in range(0, faces.size() - 2, 3):
			var a: Vector3 = mi.transform * faces[i]
			var b: Vector3 = mi.transform * faces[i + 1]
			var c: Vector3 = mi.transform * faces[i + 2]
			var projected_triangle_area := absf((b - a).cross(c - a).y) * 0.5
			if projected_triangle_area <= 0.000001:
				continue
			projected_area_sum += projected_triangle_area
			weighted_center += (a + b + c) / 3.0 * projected_triangle_area
		# Closed wing meshes contain both pressure and suction sides.
		var planform_area := projected_area_sum * 0.5
		if planform_area <= 0.01 or projected_area_sum <= 0.000001:
			continue
		var center_local := weighted_center / projected_area_sum
		var side_sign := -1.0 if name.ends_with("_L") else 1.0
		var span := maxf(float(mi.get_aabb().size.x), 0.1) * absf(mi.scale.x)
		var aspect_ratio := maxf(span * span / planform_area, 0.1)
		result.append({
			"name": name,
			"node": mi,
			"area_m2": planform_area,
			"center_local": center_local,
			"side_sign": side_sign,
			"aspect_ratio": aspect_ratio
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))
	return result

static func _lift_slope(mach: float, aspect_ratio: float, efficiency: float) -> float:
	var e := clampf(efficiency, 0.5, 1.0)
	var ar := maxf(aspect_ratio, 0.1)
	var sub_beta := sqrt(maxf(1.0 - mach * mach, 0.04))
	var sup_beta := sqrt(maxf(mach * mach - 1.0, 0.04))
	var a0_sub := minf(2.0 * PI / sub_beta, 12.0)
	var a0_sup := minf(4.0 / sup_beta, 12.0)
	var blend_t := clampf((mach - 0.85) / 0.3, 0.0, 1.0)
	var blend := blend_t * blend_t * (3.0 - 2.0 * blend_t)
	var a0 := lerpf(a0_sub, a0_sup, blend)
	return a0 / (1.0 + a0 / (PI * e * ar))

static func apply_forces(body: RigidBody3D, surfaces: Array[Dictionary], parts: Dictionary, density_kg_m3: float, speed_of_sound_mps: float, profile: Dictionary = {}) -> Dictionary:
	var wing_profile: Dictionary = profile.get("wings", {})
	if not bool(wing_profile.get("enabled", DEFAULT_WING_PROFILE["enabled"])):
		return {"lift_n": 0.0, "drag_n": 0.0, "active_wings": 0}
	if density_kg_m3 <= 0.0 or speed_of_sound_mps <= 0.0:
		return {"lift_n": 0.0, "drag_n": 0.0, "active_wings": 0}
	var cl_max := maxf(float(wing_profile.get("cl_max", DEFAULT_WING_PROFILE["cl_max"])), 0.1)
	var profile_cd := maxf(float(wing_profile.get("profile_cd", DEFAULT_WING_PROFILE["profile_cd"])), 0.0)
	var efficiency := clampf(float(wing_profile.get("oswald_efficiency", DEFAULT_WING_PROFILE["oswald_efficiency"])), 0.5, 1.0)
	var min_speed := maxf(float(wing_profile.get("min_speed_mps", DEFAULT_WING_PROFILE["min_speed_mps"])), 0.0)
	var basis := body.global_transform.basis
	var inverse_basis := basis.inverse()
	var total_lift := 0.0
	var total_drag := 0.0
	var total_moment_local := Vector3.ZERO
	var top_moment_local := Vector3.ZERO
	var bottom_moment_local := Vector3.ZERO
	var total_force_local := Vector3.ZERO
	var active_count := 0
	var surface_diagnostics: Array[Dictionary] = []
	for surface in surfaces:
		var name := String(surface["name"])
		if not parts.has(name):
			continue
		var node := surface["node"] as MeshInstance3D
		if node == null or not is_instance_valid(node) or node.get_parent() != body:
			continue
		var center_local: Vector3 = surface["center_local"]
		var center_world := body.to_global(center_local)
		var radius_world := center_world - body.global_position
		var point_velocity_world := body.linear_velocity + body.angular_velocity.cross(radius_world)
		var local_velocity := inverse_basis * point_velocity_world
		var speed := local_velocity.length()
		if speed < min_speed:
			continue
		var mach := speed / speed_of_sound_mps
		# AoA is measured in the chord plane (local YZ).
		# Forward is -Z; local_velocity is the ship velocity, opposite to the incoming airflow.
		# Keep the longitudinal sign: abs(z) incorrectly mirrors reverse flow into forward flow.
		var forward_speed := -local_velocity.z
		var alpha := atan2(-local_velocity.y, forward_speed) if forward_speed > 0.001 else 0.0
		var slope := _lift_slope(mach, float(surface["aspect_ratio"]), efficiency)
		var cl := cl_max * tanh(slope * alpha / cl_max)
		var cd_induced := cl * cl / (PI * efficiency * maxf(float(surface["aspect_ratio"]), 0.1))
		var cd := profile_cd + cd_induced
		var q := 0.5 * density_kg_m3 * speed * speed
		var area := float(surface["area_m2"])
		# Reverse flow is outside this wing model's lift polar. Keep profile drag,
		# but do not apply a forward-flight lift coefficient to a reversed flow.
		if forward_speed <= 0.001:
			cl = 0.0
			cd_induced = 0.0
			cd = profile_cd
		var lift_magnitude := q * area * cl
		var velocity_dir_local := local_velocity / speed
		# Lift must be perpendicular to the local airflow. Prefer the wing-span
		# cross-flow direction, oriented toward projected ship-up. If flow is
		# nearly parallel to the span, use projected ship-up as a stable fallback.
		var up_projected := Vector3.UP - velocity_dir_local * Vector3.UP.dot(velocity_dir_local)
		var lift_dir_local := Vector3.RIGHT.cross(velocity_dir_local)
		if lift_dir_local.length_squared() > 0.000001:
			lift_dir_local = lift_dir_local.normalized()
			if up_projected.length_squared() > 0.000001 and lift_dir_local.dot(up_projected) < 0.0:
				lift_dir_local = -lift_dir_local
		elif up_projected.length_squared() > 0.000001:
			lift_dir_local = up_projected.normalized()
		else:
			lift_dir_local = Vector3.ZERO
		var drag_dir_local := -velocity_dir_local
		var force_local := lift_dir_local * lift_magnitude + drag_dir_local * (q * area * cd)
		body.apply_force(basis * force_local, center_local)
		var surface_moment_local := (center_local - body.center_of_mass).cross(force_local)
		# Diagnostic snapshot only: does not participate in force or moment calculation.
		surface_diagnostics.append({
			"name": name,
			"area_m2": area,
			"center_local_m": [center_local.x, center_local.y, center_local.z],
			"local_velocity_mps": [local_velocity.x, local_velocity.y, local_velocity.z],
			"speed_mps": speed,
			"mach": mach,
			"alpha_rad": alpha,
			"dynamic_pressure_pa": q,
			"cl": cl,
			"cd": cd,
			"lift_n": lift_magnitude,
			"drag_n": q * area * cd,
			"lift_direction_local": [lift_dir_local.x, lift_dir_local.y, lift_dir_local.z],
			"force_local_n": [force_local.x, force_local.y, force_local.z],
			"moment_local_nm": [surface_moment_local.x, surface_moment_local.y, surface_moment_local.z]
		})
		total_moment_local += surface_moment_local
		if name.begins_with("SM_Wing_Top_"):
			top_moment_local += surface_moment_local
		else:
			bottom_moment_local += surface_moment_local
		total_force_local += force_local
		total_lift += absf(lift_magnitude)
		total_drag += q * area * cd
		active_count += 1
	return {
		"lift_n": total_lift,
		"drag_n": total_drag,
		"moment_local_nm": total_moment_local,
		"top_moment_local_nm": top_moment_local,
		"bottom_moment_local_nm": bottom_moment_local,
		"force_local_n": total_force_local,
		"active_wings": active_count,
		"surface_diagnostics": surface_diagnostics
	}
