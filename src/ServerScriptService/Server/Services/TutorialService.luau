--!strict
-- TutorialService — first-time onboarding (§6). TRACK A (logic) + TRACK B (UI). STUB.
--
-- Flow: assign farm -> welcome -> highlight slot 1 -> grant ONE free tutorial egg
-- (guaranteed Common, EconomyConfig.TutorialGrowDuration = 15s, no mutation luck)
-- -> plant -> show 4 stages -> reveal -> harvest -> +20 coins -> guide to a normal
-- Tier 1 plant -> introduce slot shop -> save completion. No Robux prompts during
-- tutorial. Tutorial progress must survive reconnect (persisted in PlayerData).

local TutorialService = {}
TutorialService.Name = "TutorialService"

-- TODO(Track A): advance the player's tutorial step + replicate via TutorialUpdated.
function TutorialService.advance(_player: Player, _toStep: number) end

-- True if the given action is allowed in the player's current tutorial step.
-- TODO(Track A): real gating; default-allow once tutorial is completed.
function TutorialService.allowsAction(_player: Player, _action: string): boolean
	return true
end

function TutorialService.Init() end
function TutorialService.Start() end

return TutorialService
