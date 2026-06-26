--!strict
-- FarmController — turns player input on slots into remote intents (§19, §20). TRACK B. STUB.
--
-- Tap/click a slot -> open the right panel (SeedPicker for empty, growing info, or
-- Harvest for ready) -> fire PlantSeed / HarvestSlot. Keyboard: E nearest slot,
-- B shop, R rebirth, Esc close. Gamepad via ContextActionService (§20). Animates
-- growth stages cosmetically from replicated timestamps; the server is the authority.

local FarmController = {}
FarmController.Name = "FarmController"

function FarmController.Init() end
function FarmController.Start() end

return FarmController
