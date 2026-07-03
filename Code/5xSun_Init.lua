-- ============================================================================
-- Mod: 5xSun
-- Prefijo Unificado: FIVESUN
-- Descripción: Escanea y rellena automáticamente los yacimientos 5 veces al Sol.
-- ============================================================================

local lf_print = false -- Cambiar a true para depuración en consola local
local ModDir = CurrentModPath
local FIVESUN_ENABLE_NOTIFICATION = true -- Notificación visual en pantalla activa.
local icon5SunNotice = "UI/Icons/Notifications/deposits.tga" -- Icono nativo del juego para depósitos
local IsValidPos = CObject.IsValidPos

-- Tabla de horarios fija y optimizada: 5 chequeos distribuidos simétricamente
local SUN_TIME_CHECKS = { 0, 5, 10, 15, 20 }

local function FIVESUNReadOption(options, key, fallback)
  if not options then
    return fallback
  end

  -- CurrentModOptions is typically a plain table in Relaunched.
  local value = options[key]
  if value ~= nil then
    return value
  end

  -- Compatibility fallback for environments exposing GetProperty.
  if type(options.GetProperty) == "function" then
    value = options:GetProperty(key)
    if value ~= nil then
      return value
    end
  end

  return fallback
end

-- Opciones globales de configuración de 5xSun en Relaunched
g_5xSunOptions = {
  AutoDismiss = false,
  AutoDismissTime = 15000,
  FIVESUNlowPercent = 30,
  SurfaceDepositWater = true,
  SurfaceDepositMetals = true,
  SurfaceDepositPreciousMetals = true,
  SurfaceDepositConcrete = true,
  SurfaceDepositPreciousMinerals = true,
}

-- Tabla global en memoria para inspección en tiempo real desde la consola
g_5xSun_MapDeposits = {
  SurfaceDepositConcrete         = {},
  SurfaceDepositMetals           = {},
  SurfaceDepositPreciousMetals   = {},
  SurfaceDepositWater            = {},
  SurfaceDepositPreciousMinerals = {},
}

-- Sincroniza las opciones visuales del juego con la tabla lógica g_5xSunOptions
local function FIVESUNUpdateOptions()
  local options = rawget(_G, "CurrentModOptions")
  if options then
    -- Sincronizar porcentaje de recarga
    g_5xSunOptions.FIVESUNlowPercent = FIVESUNReadOption(options, "FIVESUNlowPercent", g_5xSunOptions.FIVESUNlowPercent)
    
    -- Sincronizar interruptores individuales de recursos
    for depositType, _ in pairs(g_5xSun_MapDeposits) do
      g_5xSunOptions[depositType] = FIVESUNReadOption(options, depositType, g_5xSunOptions[depositType])
    end

    if lf_print then
      print("5xSun: Opciones sincronizadas. Umbral=" .. tostring(g_5xSunOptions.FIVESUNlowPercent) .. "%")
    end
  end
end

-- Ejecuta la restauración de recursos igualando la cantidad actual al máximo original
local function FIVESUNRefillDeposit(deposit)
  if IsValid(deposit) then
    deposit.amount = deposit.max_amount
  end
end

-- Escanea dinámicamente todos los reinos cargados (Superficie, Subsuelo y Asteroides)
function FIVESUNGetDeposits()
  local MapDeposits = g_5xSun_MapDeposits
  local Options = g_5xSunOptions
  local cities_list = rawget(_G, "Cities") or rawget(_G, "empty_table") or {}
  local can_scan_realms = type(rawget(_G, "GetRealmByID")) == "function"
  local can_scan_global = type(rawget(_G, "MapForEach")) == "function"
  local realm_ids = {}
  local has_any_realm = false
  local RESOURCE_BY_DEPOSIT_TYPE = {
    SurfaceDepositMetals = "Metals",
    SurfaceDepositPreciousMetals = "PreciousMetals",
    SurfaceDepositConcrete = "Concrete",
    SurfaceDepositWater = "Water",
    SurfaceDepositPreciousMinerals = "PreciousMinerals",
  }
  local CLASS_ALIASES = {
    SurfaceDepositWater = { "SurfaceDepositWater", "SubsurfaceDepositWater", "TerrainDepositWater" },
    SurfaceDepositMetals = { "SurfaceDepositMetals", "SubsurfaceDepositMetals", "TerrainDepositMetals" },
    SurfaceDepositPreciousMetals = { "SurfaceDepositPreciousMetals", "SubsurfaceDepositPreciousMetals", "TerrainDepositPreciousMetals" },
    SurfaceDepositConcrete = { "SurfaceDepositConcrete", "SubsurfaceDepositConcrete", "TerrainDepositConcrete" },
    SurfaceDepositPreciousMinerals = { "SurfaceDepositPreciousMinerals", "SubsurfaceDepositPreciousMinerals", "TerrainDepositPreciousMinerals" },
  }

  local function add_realm_id(id)
    if id ~= nil and not realm_ids[id] then
      realm_ids[id] = true
      has_any_realm = true
    end
  end

  -- Vaciar las tablas temporales antes de cada escaneo
  for depositType, _ in pairs(MapDeposits) do
    MapDeposits[depositType] = {}
  end

  -- Recolectar realms conocidos (multi-colonia) y realm principal activo.
  for _, city in ipairs(cities_list) do
    if city and city.map_id then
      add_realm_id(city.map_id)
    end
  end
  local main_city = rawget(_G, "MainCity")
  if main_city and main_city.map_id then
    add_realm_id(main_city.map_id)
  end

  -- Callback de filtro común para evitar inconsistencias entre scans por realm/global.
  local function collect_deposit(deposits, obj, depositType)
    if not IsValid(obj) then return end
    -- Solo aceptar objetos que realmente tengan recursos (descartar DepositMarker, DepositExplorer, etc.)
    if not obj.max_amount or obj.max_amount <= 0 then return end
    if not obj.amount and type(obj.GetAmount) ~= "function" then return end
    local aliases = CLASS_ALIASES[depositType] or { depositType }
    for i = 1, #aliases do
      if IsKindOf(obj, aliases[i]) then
        deposits[#deposits + 1] = obj
        return
      end
    end
    -- Fallback: aceptar por recurso si la clase no coincide con ningún alias
    local expected = RESOURCE_BY_DEPOSIT_TYPE[depositType]
    if expected and obj.resource == expected then
      deposits[#deposits + 1] = obj
    end
  end

  local function collect_deposit_by_resource(deposits, obj, depositType)
    if not IsValid(obj) then return end
    if not obj.max_amount or obj.max_amount <= 0 then return end
    if not obj.amount and type(obj.GetAmount) ~= "function" then return end
    local expected = RESOURCE_BY_DEPOSIT_TYPE[depositType]
    if expected and obj.resource == expected then
      deposits[#deposits + 1] = obj
    end
  end

  for depositType, deposits in pairs(MapDeposits) do
    -- Verificar que al menos una de las clases alias exista en g_Classes
    local aliases = CLASS_ALIASES[depositType] or { depositType }
    local classExists = false
    for i = 1, #aliases do
      if g_Classes[aliases[i]] then
        classExists = true
        break
      end
    end
    if classExists and Options[depositType] then
      if can_scan_realms and has_any_realm then
        for realm_id, _ in pairs(realm_ids) do
          local realm = GetRealmByID(realm_id)
          if realm and type(realm.MapForEach) == "function" then
            realm:MapForEach("map", depositType, function(obj)
              collect_deposit(deposits, obj, depositType)
            end)
          end
        end
      end

      -- Fallback ultra-seguro usando city.labels (estándar nativo de Haemimont cuando los escáneres globales están bloqueados)
      if #deposits == 0 then
        local checked_objects = {}
        local function try_labels_for_city(city)
          if city and type(city.labels) == "table" then
            for label_name, label_array in pairs(city.labels) do
              if type(label_name) == "string" and string.find(label_name, "Deposit", 1, true) then
                if type(label_array) == "table" then
                  for j = 1, #label_array do
                    local obj = label_array[j]
                    if obj and not checked_objects[obj] then
                      collect_deposit(deposits, obj, depositType)
                      checked_objects[obj] = true
                    end
                  end
                end
              end
            end
          end
        end
        for _, city in ipairs(cities_list) do try_labels_for_city(city) end
        try_labels_for_city(rawget(_G, "MainCity"))
      end

      -- Fallback final: scan global del mapa actual si no se detectó nada por realm ni por etiquetas.
      if #deposits == 0 then
        if can_scan_global then
          MapForEach("map", "Deposit", function(obj)
            collect_deposit(deposits, obj, depositType)
          end)
        elseif type(rawget(_G, "MapGet")) == "function" then
          local found = MapGet("map", "Deposit") or {}
          for i = 1, #found do
            collect_deposit(deposits, found[i], depositType)
          end
        else
          if lf_print and not rawget(_G, "g_5xSun_Diag_MapGetPrinted") then
            print("5xSun diag: ATENCIÓN, ni MapForEach ni MapGet están disponibles globalmente.")
            rawset(_G, "g_5xSun_Diag_MapGetPrinted", true)
          end
        end
      end

      -- Fallback adicional para builds donde todos vienen como SurfaceDeposit + resource.
      if #deposits == 0 and g_Classes and g_Classes.SurfaceDeposit then
        if can_scan_global then
          MapForEach("map", "SurfaceDeposit", function(obj)
            collect_deposit_by_resource(deposits, obj, depositType)
          end)
        elseif type(rawget(_G, "MapGet")) == "function" then
          local found = MapGet("map", "SurfaceDeposit") or {}
          for i = 1, #found do
            collect_deposit_by_resource(deposits, found[i], depositType)
          end
        else
          -- Etiquetas con Deposit (es el nombre base global en Haemimont para la etiqueta)
          local checked_objects = {}
          local function try_labels_for_city_resource(city)
            if city and type(city.labels) == "table" then
              for label_name, label_array in pairs(city.labels) do
                if type(label_name) == "string" and string.find(label_name, "Deposit", 1, true) then
                  if type(label_array) == "table" then
                    for j = 1, #label_array do
                      local obj = label_array[j]
                      if obj and not checked_objects[obj] then
                        collect_deposit_by_resource(deposits, obj, depositType)
                        checked_objects[obj] = true
                      end
                    end
                  end
                end
              end
            end
          end
          for _, city in ipairs(cities_list) do try_labels_for_city_resource(city) end
          try_labels_for_city_resource(rawget(_G, "MainCity"))
        end
      end

      if lf_print then
        -- Descomentar si se desea verbosidad por cada tipo de depósito
        -- print("5xSun: " .. depositType .. " detectados = " .. #deposits)
      end
    end
  end
end

-- Nombres legibles por recurso para la notificación
local RESOURCE_DISPLAY_NAMES = {
  SurfaceDepositConcrete = "Concrete",
  SurfaceDepositMetals = "Metals",
  SurfaceDepositPreciousMetals = "Rare Metals",
  SurfaceDepositWater = "Water",
  SurfaceDepositPreciousMinerals = "Rare Minerals",
}

-- Calcula el estado de los depósitos identificados y devuelve un resumen detallado
local function FIVESUNCalcPercentRemaining()
  local MapDeposits = g_5xSun_MapDeposits
  local Options = g_5xSunOptions
  local DepositsNeedingRefill = {}
  local summary = {} -- { depositType = { refilled = N, skipped = N, total = N } }

  for depositType, deposits in pairs(MapDeposits) do
    local info = { refilled = 0, skipped = 0, total = #deposits }
    for i = 1, #deposits do
      local obj = deposits[i]
      if Options[depositType] and IsValid(obj) and obj.max_amount and obj.max_amount > 0 then
        local current = obj.amount
        if current == nil and type(obj.GetAmount) == "function" then
          local ok, val = pcall(obj.GetAmount, obj)
          if ok then current = val end
        end
        if current and current < obj.max_amount then
          local percent = MulDivRound(100, current, obj.max_amount)
          if percent <= Options.FIVESUNlowPercent then
            DepositsNeedingRefill[#DepositsNeedingRefill+1] = obj
            info.refilled = info.refilled + 1
          else
            info.skipped = info.skipped + 1
          end
        else
          info.skipped = info.skipped + 1
        end
      end
    end
    summary[depositType] = info
  end
  return DepositsNeedingRefill, summary
end

-- Dispara el proceso de restauración y genera la alerta interactiva en UI
local function FIVESUNExecuteRefill()
  local deposits, summary = FIVESUNCalcPercentRemaining()

  -- Construir resumen detallado para consola y notificación
  local lines = {}
  local total_refilled = 0
  local total_scanned = 0
  local total_skipped = 0

  for depositType, info in pairs(summary) do
    local name = RESOURCE_DISPLAY_NAMES[depositType] or depositType
    total_refilled = total_refilled + info.refilled
    total_skipped = total_skipped + info.skipped
    total_scanned = total_scanned + info.total
    if info.refilled > 0 then
      lines[#lines + 1] = name .. ": " .. info.refilled .. " refilled"
    end
    if info.skipped > 0 then
      lines[#lines + 1] = name .. ": " .. info.skipped .. " OK"
    end
  end

  if lf_print then
    print("5xSun: === Resumen de ciclo ===")
    print("5xSun: Escaneados=" .. total_scanned .. " Rellenados=" .. total_refilled .. " Sin cambio=" .. total_skipped)
    for _, line in ipairs(lines) do
      print("5xSun:   " .. line)
    end
  end

  -- Construir texto de notificación usando objetos T para localización
  local notif_title
  local notif_text_t
  local notif_text_plain
  if #deposits > 0 then
    -- Ejecutar el refill
    for i = 1, #deposits do
      FIVESUNRefillDeposit(deposits[i])
    end
    notif_title = Untranslated("5xSun: Deposits Refilled")
    local notif_detail = table.concat(lines, ", ")
    notif_text_plain = "Refilled " .. total_refilled .. " / " .. total_scanned .. " deposits. " .. notif_detail
    notif_text_t = Untranslated(notif_text_plain)
  else
    notif_title = Untranslated("5xSun: All Deposits OK")
    notif_text_plain = total_scanned .. " deposits scanned, all above " .. tostring(g_5xSunOptions.FIVESUNlowPercent) .. "% threshold."
    notif_text_t = Untranslated(notif_text_plain)
    if lf_print then
      print("5xSun: Ningún yacimiento requiere recarga en este ciclo.")
    end
  end

  -- Notificación en pantalla (siempre, tanto para refill como para status)
  if FIVESUN_ENABLE_NOTIFICATION then
    local main_city = rawget(_G, "MainCity")
    local map_id = main_city and main_city.map_id or nil
    local notif_sent = false
    local notif_id = (#deposits > 0) and "5xSun_Refill" or "5xSun_Status"

    -- Notificación en UI
    if type(rawget(_G, "AddOnScreenNotification")) == "function" then
      local ok, err = pcall(function()
        AddOnScreenNotification(notif_id, nil, {
          title = notif_title,
          override_text = notif_text_t,
          expiration = 15000,
        })
      end)
      if not ok then
        -- Intento 1b: firma alternativa
        pcall(function()
          AddOnScreenNotification(notif_id, {
            title = notif_title,
            override_text = notif_text_t,
            expiration = 15000,
          })
        end)
      end
    end

    -- Intentar sonido de notificación
    if #deposits > 0 then
      pcall(function() PlayFX("UINotificationResearchComplete") end)
    end
  end
end

-- ============================================================================
-- Registro de Presets de Notificación
-- ============================================================================

function OnMsg.ClassesPostprocess()
  if rawget(_G, "PlaceObj") then
    local preset_class = rawget(_G, "NotificationPreset") and "NotificationPreset" or (rawget(_G, "OnScreenNotificationPreset") and "OnScreenNotificationPreset" or nil)
    local presets_table = rawget(_G, "NotificationPresets") or rawget(_G, "OnScreenNotificationPresets")
    
    if preset_class and presets_table then
      -- Notificación de refill
      if not presets_table["5xSun_Refill"] then
        PlaceObj(preset_class, {
          id = "5xSun_Refill",
          title = Untranslated("5xSun: Deposits Refilled"),
          text = Untranslated("Refilled deposits"),
          icon = "UI/Icons/Notifications/deposits.tga",
          dismissable = true,
          expiration = 15000,
        })
      end
      -- Notificación de status
      if not presets_table["5xSun_Status"] then
        PlaceObj(preset_class, {
          id = "5xSun_Status",
          title = Untranslated("5xSun: All Deposits OK"),
          text = Untranslated("All deposits are fine"),
          icon = "UI/Icons/Notifications/deposits.tga",
          dismissable = true,
          expiration = 10000,
        })
      end
      if lf_print then print("5xSun: Presets de notificación registrados usando " .. preset_class) end
    else
      if lf_print then print("5xSun: No se encontró clase de Preset de notificación para registrar.") end
    end
  end
end

-- ============================================================================
-- Mensajes de Sincronización Temporal e Interfaz Nativa
-- ============================================================================

-- Escucha cada cambio de hora en el reloj de la colonia
function OnMsg.NewHour(hour)
  for _, hourmark in ipairs(SUN_TIME_CHECKS) do
    if hour == hourmark then
      FIVESUNUpdateOptions() -- Asegurar que lea las últimas preferencias antes del ciclo
      if lf_print then print("5xSun: Iniciando ciclo de escaneo en hora " .. hour) end
      FIVESUNGetDeposits()
      FIVESUNExecuteRefill()
      break
    end
  end
end

-- Asegura la carga de opciones al iniciar el mapa de juego o cargar partida
function OnMsg.CityStart()
  FIVESUNUpdateOptions()
end

function OnMsg.LoadGame()
  FIVESUNUpdateOptions()
end