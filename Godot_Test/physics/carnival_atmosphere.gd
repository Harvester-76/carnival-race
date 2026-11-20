extends RefCounted
## Simplified configurable atmosphere for Carnival.
## SI units throughout. Pure calculations: no scene tree or Godot physics state.
##
## Planet/environment parameters are collected here so they can be tuned without
## changing the aerodynamic model or main.gd. Current values are provisional.

# Surface conditions
const SEA_LEVEL_TEMPERATURE_K := 298.15 # 25 C; tune for Carnival
const SEA_LEVEL_PRESSURE_PA := 80000.0 # 0.8 bar; provisional until planet pressure is decided

# Atmosphere composition: equal molar (approximately equal volume) fractions.
const CO2_MOLAR_FRACTION := 0.5
const N2_MOLAR_FRACTION := 0.5
# Effective properties for the 50/50 molar CO2/N2 mixture near room temperature.
const AIR_GAS_CONSTANT := 230.9 # J/(kg K)
const AIR_GAMMA := 1.335

# Simplified vertical temperature profile.
const GRAVITY_M_S2 := 9.80665
const TROPOPAUSE_ALTITUDE_M := 11000.0
const TEMPERATURE_LAPSE_RATE_K_PER_M := 0.0065

static func sample(altitude_m: float) -> Dictionary:
	var h := maxf(altitude_m, 0.0)
	var temperature: float
	var pressure: float
	var tropopause_temperature := SEA_LEVEL_TEMPERATURE_K - TEMPERATURE_LAPSE_RATE_K_PER_M * TROPOPAUSE_ALTITUDE_M
	if h <= TROPOPAUSE_ALTITUDE_M:
		temperature = SEA_LEVEL_TEMPERATURE_K - TEMPERATURE_LAPSE_RATE_K_PER_M * h
		pressure = SEA_LEVEL_PRESSURE_PA * pow(temperature / SEA_LEVEL_TEMPERATURE_K, GRAVITY_M_S2 / (AIR_GAS_CONSTANT * TEMPERATURE_LAPSE_RATE_K_PER_M))
	else:
		temperature = tropopause_temperature
		var p11 := SEA_LEVEL_PRESSURE_PA * pow(tropopause_temperature / SEA_LEVEL_TEMPERATURE_K, GRAVITY_M_S2 / (AIR_GAS_CONSTANT * TEMPERATURE_LAPSE_RATE_K_PER_M))
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
