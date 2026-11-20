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
# Change these two fractions together so that their sum remains 1.0.
const CO2_MOLAR_FRACTION := 0.5
const N2_MOLAR_FRACTION := 0.5
const UNIVERSAL_GAS_CONSTANT := 8.314462618 # J/(mol K)
const CO2_MOLAR_MASS_KG_MOL := 0.04401
const N2_MOLAR_MASS_KG_MOL := 0.028014
const CO2_CP_J_KG_K := 846.0 # approximate near room temperature
const N2_CP_J_KG_K := 1040.0 # approximate near room temperature
const MIXTURE_MOLAR_MASS_KG_MOL := CO2_MOLAR_FRACTION * CO2_MOLAR_MASS_KG_MOL + N2_MOLAR_FRACTION * N2_MOLAR_MASS_KG_MOL
const CO2_MASS_FRACTION := CO2_MOLAR_FRACTION * CO2_MOLAR_MASS_KG_MOL / MIXTURE_MOLAR_MASS_KG_MOL
const N2_MASS_FRACTION := N2_MOLAR_FRACTION * N2_MOLAR_MASS_KG_MOL / MIXTURE_MOLAR_MASS_KG_MOL
const AIR_GAS_CONSTANT := UNIVERSAL_GAS_CONSTANT / MIXTURE_MOLAR_MASS_KG_MOL
const MIXTURE_CP_J_KG_K := CO2_MASS_FRACTION * CO2_CP_J_KG_K + N2_MASS_FRACTION * N2_CP_J_KG_K
const AIR_GAMMA := MIXTURE_CP_J_KG_K / (MIXTURE_CP_J_KG_K - AIR_GAS_CONSTANT)

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
