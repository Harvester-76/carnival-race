class_name SB
extends RigidBody3D
# Тело в уменьшенном мире: физика Jolt работает в метрах × K, вся игровая логика (боты, трасса, рельеф, HUD) — в прежних «игровых» метрах.
# gpos / gvel / gtf — состояние в игровых метрах; gforce* и gimpulse — усилия, заданные в игровых единицах (ускорение × масса).
const K := 0.1

var gpos: Vector3:
	get: return global_position / K
	set(v): global_position = v * K
var gvel: Vector3:
	get: return linear_velocity / K
	set(v): linear_velocity = v * K
var gtf: Transform3D:
	get: return Transform3D(global_transform.basis, global_position / K)
	set(t): global_transform = Transform3D(t.basis, t.origin * K)

func gforce(f: Vector3) -> void: apply_central_force(f * K)
func gforce_at(f: Vector3, off_phys: Vector3) -> void: apply_force(f * K, off_phys)     # off_phys: плечо в физических метрах (из модели корабля)
func gtorque_lever(t: Vector3) -> void: apply_torque(t * K)                              # момент = сила (игровая) × плечо (физическое)
func gtorque(t: Vector3) -> void: apply_torque(t * K * K)                                # момент = сила × плечо, оба игровые
func gimpulse(i: Vector3) -> void: apply_central_impulse(i * K)
