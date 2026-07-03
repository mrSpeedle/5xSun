return {
	PlaceObj('ModItemCode', {
		'name', "5xSun_Init",
		'CodeFileName', "Code/5xSun_Init.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "5xSun_Panels",
		'CodeFileName', "Code/5xSun_Panels.lua",
	}),
	PlaceObj('ModItemOptionNumber', {
		'name', "FIVESUNlowPercent",
		'DisplayName', "Porcentaje de Recarga",
		'Help', "Define el porcentaje restante del depósito para activar el autorrelleno. (ej: 95 = rellena cuando el depósito cae por debajo del 95%)",
		'DefaultValue', 95,
		'MinValue', 10,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "SurfaceDepositWater",
		'DisplayName', "Rellenar Depósitos de Agua",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "SurfaceDepositMetals",
		'DisplayName', "Rellenar Depósitos de Metales",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "SurfaceDepositPreciousMetals",
		'DisplayName', "Rellenar Metales Preciosos",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "SurfaceDepositConcrete",
		'DisplayName', "Rellenar Depósitos de Hormigón",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "SurfaceDepositPreciousMinerals",
		'DisplayName', "Rellenar Minerales Preciosos (Asteroides)",
		'DefaultValue', true,
	}),
}