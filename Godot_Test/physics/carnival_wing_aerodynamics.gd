extends RefCounted
## Swept-wing aerodynamic forces from mesh-derived planform geometry.
## Geometry is measured from the mesh actually instantiated by the ship.
## SI units throughout.

const DEFAULT_WING_PROFILE := {
	"enabled": true,
	"cl_max": 1.2,
	"profile_cd": 0.025,
	"oswald_efficiency": 0.8,
	"min_speed_mps": 5.0
}

static func _estimate_le_slope(points: Array[Vector2], span_min: float, span_max: float) -> float:
	# Estimate the leading-edge line from the forwardmost points near the root
	# and tip. Using endpoint bands avoids mistaking sparse trailing-edge
	# vertices for the leading edge in imported triangulated meshes.
	var span_extent := span_max - span_min
	if span_extent <= 0.001 or points.is_empty():
		return 0.0
	var root_limit := span_min + span_extent * 0.18
	var tip_limit := span_max - span_extent * 0.18
	var root_x := INF
	var root_z := INF
	var tip_x := -INF
	var tip_z := INF
	for point in points:
		if point.x <= root_limit and point.y < root_z:
			root_x = point.x
			root_z = point.y
		if point.x >= tip_limit and point.y < tip_z:
			tip_x = point.x
			tip_z = point.y
	if root_x >= INF or tip_x <= -INF or tip_x - root_x <= 0.001:
		return 0.0
	return (tip_z - root_z) / (tip_x - root_x)

static func _normal_force_coefficient_90(mach: float) -> float:
	# Modified-Newtonian stagnation pressure coefficient. For subsonic flow,
	# use a broadside flat-plate engineering reference value (approximately 1.28).
	const GAMMA := 1.4
	if mach <= 1.0:
		return 1.28
	var mach_sq := mach * mach
	var p2_p1 := 1.0 + 2.0 * GAMMA / (GAMMA + 1.0) * (mach_sq - 1.0)
	var downstream_mach_sq := (1.0 + 0.5 * (GAMMA - 1.0) * mach_sq) / (GAMMA * mach_sq - 0.5 * (GAMMA - 1.0))
	var p02_p1 := p2_p1 * pow(1.0 + 0.5 * (GAMMA - 1.0) * downstream_mach_sq, GAMMA / (GAMMA - 1.0))
	var dynamic_pressure_ratio := 0.5 * GAMMA * mach_sq
	return (p02_p1 - 1.0) / dynamic_pressure_ratio

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
		var planform_points: Array[Vector2] = []
		var min_abs_x := INF
		var max_abs_x := 0.0
		for i in range(0, faces.size() - 2, 3):
			var a: Vector3 = mi.transform * faces[i]
			var b: Vector3 = mi.transform * faces[i + 1]
			var c: Vector3 = mi.transform * faces[i + 2]
			for p in [a, b, c]:
				planform_points.append(Vector2(absf(p.x), p.z))
				min_abs_x = minf(min_abs_x, absf(p.x))
				max_abs_x = maxf(max_abs_x, absf(p.x))
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
		var le_slope := _estimate_le_slope(planform_points, min_abs_x, max_abs_x)
		# Aerodynamic section axes follow the actual wing geometry:
		# local X is the span direction, local -Z is the chord direction,
		# and local +Y is the surface normal. Leading-edge sweep is a separate
		# planform property; it must not rotate the span axis or chord axis.
		# Sweep is retained as geometry metadata until a validated swept-wing
		# correction is applied to the aerodynamic coefficients.
		var span_axis := Vector3.RIGHT
		var chord_axis := Vector3(0.0, 0.0, -1.0)
		var normal_axis := Vector3.UP
		var span := maxf(max_abs_x - min_abs_x, 0.1)
		var aspect_ratio := maxf(span * span / planform_area, 0.1)
		result.append({
			"name": name,
			"node": mi,
			"area_m2": planform_area,
			"center_local": center_local,
			"side_sign": side_sign,
			"aspect_ratio": aspect_ratio,
			"span_axis_local": span_axis,
			"chord_axis_local": chord_axis,
			"normal_axis_local": normal_axis,
			"leading_edge_sweep_rad": atan(absf(le_slope)),
			"span_m": span
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
		var total_speed := local_velocity.length()
		# Resolve flow in the plane normal to the measured leading edge.
		# Spanwise flow is removed; the remaining velocity contains vertical
		# incidence and the chord-normal component affected by sweep.
		var span_axis: Vector3 = surface.get("span_axis_local", Vector3.RIGHT)
		var chord_axis: Vector3 = surface.get("chord_axis_local", Vector3(0.0, 0.0, -1.0))
		var normal_axis: Vector3 = surface.get("normal_axis_local", Vector3.UP)
		var spanwise_velocity := local_velocity.dot(span_axis)
		var section_velocity_local := local_velocity - span_axis * spanwise_velocity
		var section_speed := section_velocity_local.length()
		if section_speed < min_speed:
			continue
		var mach := section_speed / speed_of_sound_mps
		var forward_speed := section_velocity_local.dot(chord_axis)
		var normal_speed := section_velocity_local.dot(normal_axis)
		# Signed incidence supports both forward and reverse flow (-pi..pi).
		var alpha := atan2(-normal_speed, forward_speed)
		var alpha_abs := absf(alpha)
		var slope := _lift_slope(mach, float(surface["aspect_ratio"]), efficiency)
		var cl_attached := cl_max * tanh(slope * alpha / cl_max)
		var cd_induced_attached := cl_attached * cl_attached / (PI * efficiency * maxf(float(surface["aspect_ratio"]), 0.1))
		var cd_attached := profile_cd + cd_induced_attached
		var q := 0.5 * density_kg_m3 * section_speed * section_speed
		var area := float(surface["area_m2"])
		var velocity_dir_local := section_velocity_local / section_speed
		var lift_dir_local := normal_axis - velocity_dir_local * normal_axis.dot(velocity_dir_local)
		if lift_dir_local.length_squared() > 0.000001:
			lift_dir_local = lift_dir_local.normalized()
		else:
			lift_dir_local = Vector3.ZERO
		var aft_axis := -chord_axis
		var high_aoa_blend := 1.0
		var normal_coefficient := 0.0
		var axial_coefficient := 0.0
		var cn_90 := _normal_force_coefficient_90(mach)
		if forward_speed > 0.001 and alpha_abs < PI * 0.5:
			# Preserve the established attached-flow polar at low incidence.
			var old_normal := cl_attached * cos(alpha) + cd_attached * sin(alpha)
			var old_axial := -cl_attached * sin(alpha) + cd_attached * cos(alpha)
			var blend_t := clampf((alpha_abs - deg_to_rad(45.0)) / deg_to_rad(30.0), 0.0, 1.0)
			high_aoa_blend = blend_t * blend_t * (3.0 - 2.0 * blend_t)
			# Blend the attached-flow polar into a modified-Newtonian broadside
			# normal-force model. This is still a strip-theory approximation for
			# this finite swept planform, not a craft-specific validated polar.
			var plate_normal := -signf(normal_speed) * cn_90 * sin(alpha_abs) * sin(alpha_abs)
			var plate_axial := profile_cd * cos(alpha_abs)
			normal_coefficient = lerpf(old_normal, plate_normal, high_aoa_blend)
			axial_coefficient = lerpf(old_axial, plate_axial, high_aoa_blend)
		else:
			# Reverse flow and near-broadside incidence use a symmetric plate
			# approximation; force opposes each in-plane velocity component.
			normal_coefficient = -signf(normal_speed) * cn_90 * sin(alpha_abs) * sin(alpha_abs)
			axial_coefficient = signf(forward_speed) * profile_cd * absf(cos(alpha))
		# Convert body-axis coefficients into wind-axis telemetry.
		var cl := normal_coefficient * cos(alpha) - axial_coefficient * sin(alpha)
		var cd := normal_coefficient * sin(alpha) + axial_coefficient * cos(alpha)
		var lift_magnitude := q * area * cl
		var force_local := normal_axis * (q * area * normal_coefficient) + aft_axis * (q * area * axial_coefficient)
		body.apply_force(basis * force_local, radius_world)
		var surface_moment_local := (center_local - body.center_of_mass).cross(force_local)
		# Diagnostic snapshot only: does not participate in force or moment calculation.
		surface_diagnostics.append({
			"name": name,
			"area_m2": area,
			"span_m": float(surface.get("span_m", 0.0)),
			"center_local_m": [center_local.x, center_local.y, center_local.z],
			"local_velocity_mps": [local_velocity.x, local_velocity.y, local_velocity.z],
			"total_speed_mps": total_speed,
			"spanwise_velocity_mps": spanwise_velocity,
			"leading_edge_sweep_deg": rad_to_deg(float(surface.get("leading_edge_sweep_rad", 0.0))),
			"forward_speed_mps": forward_speed,
			"normal_speed_mps": normal_speed,
			"section_speed_mps": section_speed,
			"speed_mps": section_speed,
			"mach": mach,
			"normal_mach": mach,
			"alpha_rad": alpha,
			"dynamic_pressure_pa": q,
			"cl": cl,
			"cd": cd,
			"normal_coefficient": normal_coefficient,
			"axial_coefficient": axial_coefficient,
			"high_aoa_blend": high_aoa_blend,
			"lift_n": lift_magnitude,
			"drag_n": q * area * cd,
			"lift_direction_local": [lift_dir_local.x, lift_dir_local.y, lift_dir_local.z],
			"span_axis_local": [span_axis.x, span_axis.y, span_axis.z],
			"chord_axis_local": [chord_axis.x, chord_axis.y, chord_axis.z],
			"normal_axis_local": [normal_axis.x, normal_axis.y, normal_axis.z],
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
