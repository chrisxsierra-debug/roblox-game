--!strict
-- PlotFactory — builds a placeholder plot model (§11, §22). TRACK C owns this. STUB.
--
-- Each plot: owner sign, spawn point, farm ground, 12 grow-slot positions (first 2
-- active), locked-slot markers, rebirth altar, shop sign, decorative border, and a
-- future-raid-entry placeholder. Anchored parts only; spaced for large final creatures.

local PlotFactory = {}

-- TODO(Track C): build(plotId, originCFrame) -> Model (Workspace plot).
function PlotFactory.build(_plotId: number, _origin: CFrame): Model?
	return nil
end

return PlotFactory
