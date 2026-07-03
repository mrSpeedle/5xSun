# 5xSun - Resumen de avances

## Estado actual (Sesión 2026-07-02)
El mod **funciona correctamente**: detecta y rellena depósitos de forma automática cada 5 horas del Sol. La única funcionalidad pendiente es la **notificación visual en pantalla** (arriba a la izquierda, como las del juego), que aún no aparece a pesar de que `AddOnScreenNotification` devuelve `true`.

---

## ✅ Logros de esta sesión

### Motor de escaneo de depósitos — FUNCIONANDO
- Se corrigieron todos los crashes por **strict mode de Lua** (`Attempt to use an undefined global`). Todas las globales opcionales ahora se leen con `rawget(_G, "nombre")`.
- Se descubrió que en **Surviving Mars: Relaunched** los depósitos usan la clase `TerrainDeposit*` (no `SurfaceDeposit*` ni `SubsurfaceDeposit*`). Se añadieron alias para las tres variantes.
- Se descubrió que `MapForEach` y `MapGet` **no están disponibles globalmente** en Relaunched. Se implementó un fallback usando `city.labels` que itera las etiquetas nativas de Haemimont.
- Se arregló el guard `classExists` para que verifique si **alguno** de los alias de clase existe, no solo el nombre primario.
- Se añadieron filtros de validación en `collect_deposit` para descartar objetos falsos (`DepositMarker`, `DepositExplorer`, etc.) que no tienen `amount`/`max_amount`.
- Se corrigió el crash de `GetAmount` nil usando `pcall` defensivo en `FIVESUNCalcPercentRemaining`.

### Umbral dinámico desde opciones — FUNCIONANDO
- El porcentaje de recarga ya **no está hardcodeado**. Se lee del slider `FIVESUNlowPercent` en el panel de opciones del mod.
- El default se cambió a **95%** (antes era 30%).
- Se alinearon los nombres de los toggles en `items.lua` con las claves internas (`SurfaceDeposit*` en lugar de `SubsurfaceDeposit*`).
- La consola confirma: `5xSun: Opciones sincronizadas. Umbral=95%`.

### Resumen detallado en consola — FUNCIONANDO
- Cada ciclo imprime un desglose completo:
  ```
  5xSun: === Resumen de ciclo ===
  5xSun: Escaneados=15 Rellenados=2 Sin cambio=13
  5xSun:   Metals: 2 refilled
  5xSun:   Concrete: 2 OK
  5xSun:   Water: 1 OK
  ```

---

## ❌ Pendiente: Notificación visual en pantalla

### Lo que se intentó
1. `AddCustomOnScreenNotification` — No existe en Relaunched (crash por strict mode).
2. `AddOnScreenNotification("5xSun_Refill", nil, {text=...})` — **Devuelve `true` pero NO muestra nada en pantalla**. Se registraron presets con `PlaceObj("OnScreenNotificationPreset", ...)` en `ClassesPostprocess` pero no está confirmado que el preset se registre correctamente (puede que `OnScreenNotificationPreset` no exista en Relaunched).
3. `ShowNotification` — No existe.
4. `WaitCustomPopupNotification` — No probado exitosamente (puede requerir validación).
5. `AddConsoleLog` — No verificado.

### Diagnóstico relevante
- `pairs(_G)` no itera las funciones de notificación (probablemente están en un metatableto `__index`), pero `rawget` sí las encuentra.
- `AddOnScreenNotification` acepta la llamada sin error pero no produce resultado visual.
- **Hipótesis principal**: el preset `"5xSun_Refill"` no se registró correctamente, o la firma de la función `AddOnScreenNotification` en Relaunched es diferente a la del SM clásico.

### Próximo paso recomendado
1. Investigar si `OnScreenNotificationPreset` existe como clase en Relaunched o si se llama diferente.
2. Probar con un **ID de preset nativo del juego** (ej. `"DepositDepleted"`, `"ResearchComplete"`) para confirmar que `AddOnScreenNotification` funciona con presets conocidos.
3. Si funciona con un preset nativo, el problema es solo el registro. Si no funciona con ninguno, la API tiene una firma diferente en Relaunched.
4. Alternativa: usar `CreateRealTimeThread` + un popup de UI custom con `XDialog` o similar.

---

## Archivos tocados
- [Code/5xSun_Init.lua](Code/5xSun_Init.lua) — Motor principal, escaneo, refill, opciones, notificaciones
- [Code/5xSun_Panels.lua](Code/5xSun_Panels.lua) — Sin cambios en esta sesión
- [items.lua](items.lua) — Nombres de opciones alineados, default del slider a 95%
- [metadata.lua](metadata.lua) — Sin cambios

## Hallazgos técnicos clave sobre Surviving Mars: Relaunched
| Elemento | SM Clásico | SM: Relaunched |
|---|---|---|
| Clases de depósito | `SurfaceDeposit*`, `SubsurfaceDeposit*` | `TerrainDeposit*` |
| `MapForEach` global | ✅ Disponible | ❌ No disponible |
| `MapGet` global | ✅ Disponible | ❌ No disponible |
| `GetRealmByID` | ✅ Disponible | ❌ No disponible |
| Iteración de depósitos | Via `MapForEach("map", clase)` | Via `city.labels[clase]` |
| Strict mode Lua | Parcial | **Agresivo** (crash al leer global undefined) |
| `AddOnScreenNotification` | Requiere preset registrado | Existe, acepta llamada, **no muestra nada** |
| `AddCustomOnScreenNotification` | ✅ Disponible | ❌ No disponible |
