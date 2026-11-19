extends RefCounted
## Earth-like reference atmosphere. SI units throughout.
## Pure calculations: no scene tree or Godot physics state.

const SEA_LEVEL_TEMPERATURE_K := 288.15
const SEA_LEVEL_PRESSURE_PA := 101325.0
const SEA_LEVEL_DENSITY_KG_M3 := 1.225
const GRAVITY_M_S2 := 9.80665
const AIR_GAS_CONSTANT := 287.05287
const AIR_GAMMA := 1.4
const TROPOPAUSE_ALTITUDE_M := 11000.0
const TROPOPAUSE_TEMPERATURE_K := 216.65

static func sample(altitude_m: float) -> Dictionary:
	var h := maxf(altitude_m, 0.0)
	var temperature: float
	var pressure: float
	if h <= TROPOPAUSE_ALTITUDE_M:
		var lapse := 0.0065
		temperature = SEA_LEVEL_TEMPERATURE_K - lapse * h
		pressure = SEA_LEVEL_PRESSURE_PA * pow(temperature / SEA_LEVEL_TEMPERATURE_K, GRAVITY_M_S2 / (AIR_GAS_CONSTANT * lapse))
	else:
		temperature = TROPOPAUSE_TEMPERATURE_K
		var p11 := SEA_LEVEL_PRESSURE_PA * pow(TROPOPAUSE_TEMPERATURE_K / SEA_LEVEL_TEMPERATURE_K, GRAVITY_M_S2 / (AIR_GAS_CONSTANT * 0.0065))
		pressure = p11 * exp(-GRAVITY_M_S2 * (h - TROPOPAUSE_ALTITUDE_M) / (AIR_GAS_CONSTANT * temperature))
	var density := pressure / (AIR_GAS_CONSTANT * temperature)
	var speed_of_sound := sqrt(AIR_GAMMA * AIR_GAS_CONSTANT * temperature)
	return {
		"altitude_m": h,
		"temperature_k": temperature,
		"pressure_pa": pressure,
		"density_kg_m3": density,
		"speed_of_sound_mps": speed_of_sound
	}
