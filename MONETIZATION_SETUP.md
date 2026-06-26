# Monetization Setup

All IDs live in [`src/ReplicatedStorage/Shared/Config/MonetizationConfig.luau`](src/ReplicatedStorage/Shared/Config/MonetizationConfig.luau).
Every ID defaults to `0`. **The game must not error on 0, and the client must hide any
pass/product whose id is still 0** (`MonetizationConfig.isConfigured`). Nothing is purchasable until
you fill these in.

## Where to create them
Roblox **Creator Dashboard → your experience → Monetization** → Passes / Developer Products. Copy each
id into the matching field in `MonetizationConfig`.

### Game passes (`MonetizationConfig.GamePasses[...].Id`)
| Key | Name | Suggested | Effect |
| --- | --- | ---: | --- |
| `DoubleGrowth` | 2x Growth Speed | 199 R | halves grow time for **future** crops (§18) |
| `AutoCollect` | Auto-Collect | 149 R | server auto-harvests ready crops while online |
| `GoldenPlotVIP` | Golden Plot VIP | 499 R | gold farm + sign + **+15% income (once)** + exclusive variant |

### Developer products (`MonetizationConfig.Products[...].Id`)
| Key | Name | Suggested | Effect |
| --- | --- | ---: | --- |
| `InstantGrow` | Instant Grow | 29 R | completes one selected slot (pending-purchase context, §24) |
| `FertilizerPack` | Fertilizer Pack | 49 R | 10 charges; each −25% of a crop's remaining time |
| `CoinPackSmall/Medium/Large` | Coin Packs | 49/199/499 R | grants Coins (never required to progress) |

## Receipt safety (§24)
`ProcessReceipt` is implemented in `MonetizationService` (Track A) and must be idempotent: record
each `PurchaseId` in `PlayerData.Purchases.ProcessedReceipts`, grant once, and for slot-targeted
products verify the slot still belongs to the player — otherwise grant a safe fallback. Prune old
receipts so the profile doesn't grow unbounded.

## Sounds / icons
`AssetConfig` holds sound + image ids (also default 0 = skip). Fill in alongside the juice work (Track C/B).
