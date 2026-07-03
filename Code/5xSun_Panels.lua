-- ============================================================================
-- Mod: 5xSun
-- Componente exclusivo: 5xSun_Panels.lua (Inyección por Métodos)
-- ============================================================================

function OnMsg.ClassesGenerate()
  
  -- 1. Inyección forzada en el método de descripción de las Minas Generales
  if Mine and Mine.CreateDescriptionLines then
    local org_Mine_CreateDescriptionLines = Mine.CreateDescriptionLines
    function Mine:CreateDescriptionLines(lines, ...)
      org_Mine_CreateDescriptionLines(self, lines, ...)
      
      local deposit = self.subsurface_deposit or self.surface_deposit
      if IsValid(deposit) then
        local amount = deposit:GetAmount() or 0
        local max_amt = deposit.max_amount or 1
        local pct = MulDivRound(100, amount, max_amt)
        
        -- CORREGIDO: Se formatea usando T{} nativo para que el motor visual de Relaunched lo renderice
        table.insert(lines, T{18855000002, "Yacimiento: <color 255 100 100><amount></color> unidades (<pct>%)", amount = amount, pct = pct})
      end
    end
  end

  -- 2. Inyección forzada en el método de descripción de los Extractores de Agua
  if WaterExtractor and WaterExtractor.CreateDescriptionLines then
    local org_Water_CreateDescriptionLines = WaterExtractor.CreateDescriptionLines
    function WaterExtractor:CreateDescriptionLines(lines, ...)
      org_Water_CreateDescriptionLines(self, lines, ...)
      
      local deposit = self.subsurface_deposit or self.surface_deposit
      if IsValid(deposit) then
        local amount = deposit:GetAmount() or 0
        local max_amt = deposit.max_amount or 1
        local pct = MulDivRound(100, amount, max_amt)
        
        -- CORREGIDO: Se empaqueta con ID único de traducción y paso de variables nativas
        table.insert(lines, T{18855000003, "Yacimiento: <color 255 100 100><amount></color> unidades (<pct>%)", amount = amount, pct = pct})
      end
    end
  end  
  
end