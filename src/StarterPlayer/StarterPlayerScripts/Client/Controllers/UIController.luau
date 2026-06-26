--!strict
-- UIController — owns the ScreenGui and the UI modules (HUD, panels) (§19). TRACK B. STUB.
--
-- Builds one ScreenGui under PlayerGui (IgnoreGuiInset, ResetOnSpawn=false),
-- instantiates HUD + SlotPanel + SeedPicker + ShopPanel + RebirthPanel +
-- NotificationPanel, and routes DataUpdated/SlotUpdated/Notification snapshots to them.
-- Display only — never computes payouts (§19).

local UIController = {}
UIController.Name = "UIController"

function UIController.Init()
	-- TODO(Track B): create ScreenGui, build UI modules.
end

function UIController.Start()
	-- TODO(Track B): subscribe to Remotes server->client events; render snapshots.
end

return UIController
