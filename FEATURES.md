# Orvion Hub — Feature Reference (Updated 2026-08-17)

> Auto-generated context for AI assistant on Linux.
> File: `test.lua` in this repo. Source library: `KnullXDgt/Orvion-UI-Library` (`source.luau`).

---

## Tab Structure

```
Info | Main | Teleport | Automation | Shop
```

---

## Info Tab
- **What is Orvion?** — About paragraph, credits (idan + ALE)

---

## Main Tab

### Support Features
- Disable Obtained Fish notification
- Disable Fishing Animation
- Disable Cutscenes
- Disable Skin Effect
- Disable Ability VFX
- Disable Weather VFX
- Auto Equip Rod
- Hide Other Players
- Walk on Water
- Lock Position

### Instant Fishing (V1)
- Toggle on/off
- Perfect Cast (task.wait 0.277s between charge→minigame)
- Cast Wait slider
- Remotes: `RF/ChargeFishingRod`, `RF/RequestFishingMinigameStarted`, `RE/CatchFishCompleted`

### Instant Fishing V2
- Charge + minigame simultaneous
- Perfect Cast variant
- Config delay slider

### Blatant (Visual)
- Visual mode with double TextNotification per catch
- n-charge cycling

### Stable Results
- One-shot stable catch cycle

### Sell Features
- Auto Sell (Delay / Count mode)
- Disable Fish Notification option
- Sell All Now button
- Remote: `RF/SellAllItems`

---

## Teleport Tab

### Teleport to Island
- Dropdown of all island locations
- Teleport button

### Teleport to Event
- Priority Event + Select Event dropdowns
- Event list: Megalodon Hunt, Glacial Serpent Hunt, etc.
- Auto-detect event end via `workspace.DescendantRemoving`

### Teleport to NPC
- Grid buttons for all NPCs
- Uses `model:GetPivot()` (not HumanoidRootPart — server sets position underwater)

### Teleport to Player
- Dropdown of players in server

### Saved Location
- Save Current Location (stores CFrame as JSON array)
- Teleport to Saved
- Reset Saved Location
- Auto Teleport on Spawn toggle
- Format: `CFrame:GetComponents()` → JSON array → `CFrame.new(table.unpack(data))`

---

## Automation Tab (NEW — added this session)

### Weather Features
- **Select Weather** — multi-select dropdown (max 3): Fog, Wind, Radiant, Storm, Snow, Galaxy, etc.
- **Buy Weather** toggle — event-driven via `EventsReplion:OnArrayRemove("WeatherMachine")`
- Remote: `RF/PurchaseWeatherEvent:InvokeServer("eventName")`
- Lazy-loaded EventsReplion on first use

### Totem Features
- **Select Totem** dropdown: `Luck Totem`, `Mutation Totem`, `Shiny Totem`
- **Refresh Totem List** button — checks UUID in inventory
- **Auto Spawn Totem** toggle:
  - Finds UUID via `ItemUtility.GetItemDataFromItemType(catName, item.Id)`
  - Fires `RE/SpawnTotem:FireServer(uuid)`
  - Event-driven respawn via `RE/TotemCreated` listener + `model.AncestryChanged`
  - **Distance monitor**: if player moves > 100 studs from totem (checked every 10s) → auto re-spawn
  - Filter: only captures own totem (distance < 50 studs from player at spawn time)
  - task.wait(2) before re-spawn after pickup
- **Spawn Now** button (manual, single fire)

---

## Shop Tab (NEW — added this session)

### Rod Features
- **Select Rod** — dropdown (18 rods):
  Starter(1), Luck(79), Carbon(76), Grass(85), Demascus(77), Ice(78),
  Lucky(4), Midnight(80), Seabreeze(657), Eclipse(656), Steampunk(6),
  Chrome(7), Fluorescent(255), Magma(3), Astral(5), Ares(126),
  Angler(168), Bamboo(258)
- **Buy Rod** button:
  - `RF/PurchaseFishingRod:InvokeServer(rodId)` → returns `(success, UUID)`
  - Auto equip: `RE/EquipItem:FireServer(UUID, "Fishing Rods")`

### Bait Features
- **Select Bait** — dropdown (9 baits):
  Topwater(10), Luck(2), Midnight(3), Nature(17), Chroma(6),
  Dark Matter(8), Corrupt(15), Aether(16), Singularity(18)
- **Buy Bait** button:
  - `RF/PurchaseBait:InvokeServer(baitId)` → returns `(success, shouldEquip)`
  - Auto equip: `RE/EquipBait:FireServer(baitId)` if shouldEquip

### Black Market Features
- **Location**: Lucky Volcano → CFrame stored at `Lucky Volcano Black Market`
- **Select Item** — multi-select dropdown (19 items):

| item.Id | Display Name | Price |
|---|---|---|
| undersea_racer | Undersea Racer | 400M |
| venombone_skin | Venombone | 3M |
| phantom_skin | Phantom Tide | 3M |
| hadalith_skin | Raging Hadalith | 1.5M |
| trinket_skin | Mecha Nautical Trinket | 2.2M |
| basic_flippers | Basic Flippers | 4M |
| gilded_boots | Gilded Boots | 30M |
| winged_boots_m | Winged Boots M | 15M |
| winged_boots_f | Winged Boots F | 15M |
| luck_3_potion | Luck III Potion | 3M |
| mut_3_potion | Mutation III Potion | 5M |
| mut_4_potion | Mutation IV Potion | 9M |
| wet_1_potion | Dark Megalodon Hunt Potion | 12M |
| wet_2_potion | Megalodon Hunt Potion | 8M |
| wet_3_potion | Meteor Shower Potion | 10M |
| wet_4_potion | Aurora Borealis Potion | 12M |
| wet_5_potion | Glacial Serpent Hunt Potion | 18M |
| coin_toss | Coin Toss Emote | 2M |
| minor_fort_ability | Minor Fortune Ability | 1.5M |

- **Refresh List** button — shows item count in stock
- **Buy Black Market Item** toggle:
  - TP to `Lucky Volcano Black Market` CFrame
  - task.wait(1.5) for load
  - Fire `RF/PurchaseBlackMarketItem:InvokeServer(item.Id)` per selected item
  - TP back to pre-BM position
  - Auto toggle-off after done

### Battlepass Shop Features
- **Status** paragraph — updates during buy (e.g. `Buy 2/5 (Slot 3)`, `Done — bought 3/5`)
- **Buy Item** — multi-select dropdown (18 slots):
  Slot 1 (Star Charm 2000) through Slot 18 (Low Gravity 60000)
- **Buy Battlepass Item** toggle:
  - Checks `PlayerData:Get("GalaxyBP26")[tostring(index)]` for ownership
  - Skips already-owned slots
  - Remote: `RE/BPPurchaseRequest:FireServer(index)`
  - task.wait(0.8) between slots
  - Notif if no Galaxy Points / all owned
  - Auto toggle-off after done

### Merchant Features
- **Status** paragraph — shows `Item: X`, `Price: Y Coins`, `Buy: Z/Q`
- **Select Item** dropdown — populated on Refresh (no static list, daily rotation)
  - Known items: Singularity Bait, Luck Totem, Mutation Totem, Shiny Totem, rods, potions, etc.
  - Uses `MarketItemData` module → `ItemUtility.GetItemDataFromItemType(type, identifier)`
  - Auto-selects first item after refresh
- **Quantity** input — number of items to buy (used by toggle)
- **Refresh Item Merchant** button:
  - Reads `Replion.Client:WaitReplion("Merchant"):GetExpect("Items")`
  - Resolves names via `RS.Shared.MarketItemData` + `ItemUtility`
  - Updates dropdown via `:Refresh(newList, defaultItem)`
- **Buy Manual** button — buys 1x with coin check
- **Buy Merchant Item** toggle:
  - Buys `qty` times (from input), coin check per iteration
  - Remote: `RF/PurchaseMarketItem:InvokeServer(itemId)`
  - Auto toggle-off after done

---

## Remote Map (sleitnick_net@0.2.0 label-sibling pattern)

```lua
local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
-- label at index i → actual remote at i+1
```

Key remotes:
| Label | Type | Args |
|---|---|---|
| RF/ChargeFishingRod | RF | InvokeServer(tick()) |
| RF/RequestFishingMinigameStarted | RF | InvokeServer(1.2854545116425, 1) |
| RE/CatchFishCompleted | RE | FireServer() |
| RF/SellAllItems | RF | InvokeServer() |
| RF/PurchaseBait | RF | InvokeServer(baitId: number) → (bool, bool) |
| RE/EquipBait | RE | FireServer(baitId: number) |
| RF/PurchaseFishingRod | RF | InvokeServer(rodId: number) → (bool, UUID) |
| RE/EquipItem | RE | FireServer(UUID, "Fishing Rods") |
| RF/PurchaseBlackMarketItem | RF | InvokeServer(itemId: string) → {Success: bool} |
| RE/BPPurchaseRequest | RE | FireServer(slotIndex: number) |
| RF/PurchaseMarketItem | RF | InvokeServer(marketItemDataId) → bool |
| RF/PurchaseWeatherEvent | RF | InvokeServer("eventName") |
| RE/SpawnTotem | RE | FireServer(uuid: string) |
| RE/TotemCreated | RE | OnClientEvent → (model, totemId) |
| RE/TotemSpawned | RE | OnClientEvent → (position: Vector3) |

---

## Config Keys (autoload-able)

```lua
Config = {
    -- Fishing
    InstantFishing, CastWait, PerfectCast, BlatantActive, BlatantDelay,
    AutoSell, AutoSellMode, SellDelay, SellCount, DisableFishNotif,
    -- Teleport
    TeleportLocation, PriorityEvent, SelectEvent,
    -- Weather
    SelectedWeatherEvents = {}, BuyWeatherActive,
    -- Totem
    SelectedTotem, AutoSpawnTotem,
    -- Rod/Bait
    SelectedRod, SelectedBait,
    -- Black Market
    SelectedBMItems = {}, AutoBuyBM,
    -- Battlepass
    SelectedBPSlots = {}, AutoBuyBP,
    -- Merchant
    SelectedMerchantItem, MerchantQty, AutoBuyMerchant,
}
```

---

## Platform Notes
- Executor: Madium (PC) / Delta (Android)
- Delta pitfalls: wrap InputBegan/Changed/Ended in pcall, no hookmetamethod
- UI: English only, no emoji, no Indonesian in UI text
- GitHub staging: `KnullXDgt/test` → `test.lua`
- Orvion UI Library: `KnullXDgt/Orvion-UI-Library` → `source.luau`
- ConfigFolder: `OrvionFishIt`
