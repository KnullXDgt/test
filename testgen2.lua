-- ====================================================================
--                 ORVION HUB Gen2 - SKELETON (UI TEST)
--          No game-specific logic - works in any game
-- ====================================================================

-- ====== SERVICES ======
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ====== CONFIG ======
local Config = {
    AutoFish          = false,
    AutoSell          = false,
    AutoSellMode      = "Tier",
    SellTier          = 4,
    SellCount         = 10,
    DisableFishNotif  = false,
    TeleportLocation  = "Ancient Jungle",
    PerfectCast       = false,
    BlatantActive     = false,
    BlatantDelay      = 0,
    PriorityEvent         = "Select Option",
    SelectEvent           = "Select Option",
    SelectedWeatherEvents = {},
    BuyWeatherActive      = false,
    SelectedTotem         = "Luck Totem",
    AutoSpawnTotem        = false,
    EnchantType           = "Normal Enchant Stone",
    TargetEnchant         = "Select Option",
    AutoEnchantReroll     = false,
    SelectedSecretFish    = "Select Option",
    TranscendedAmount     = 1,
    AutoCreateTranscended = false,
    SelectedRod           = "Starter Rod",
    SelectedBait          = "Topwater Bait",
    SelectedBMItems       = {},
    AutoBuyBM             = false,
    SelectedBPSlots       = {},
    AutoBuyBP             = false,
    SelectedMerchantItem  = "Select Option",
    MerchantQty           = 1,
    AutoBuyMerchant       = false,
}

-- ====== CONSTANTS ======
local LOCATION_NAMES = {
    "Ancient Jungle", "Ancient Ruin", "Aquarium",
    "Copper Canyon [SPOT 1]", "Copper Canyon [SPOT 2]", "Copper Canyon Mines",
    "Coral Reefs", "Crater Island", "Crystal Depths",
    "Esoteric Depths", "Fisherman Island", "Gloomcap Grotto",
    "Kohana", "Kohana Lab", "Kohana Volcano",
    "Lava Basin", "Leviathan Den", "Lucky Abyss", "Lucky Volcano",
    "Mariana Trench", "Mutation Vents",
    "Pirate Cove", "Planetary Observatory",
    "Sacred Temple", "Sewers", "Shiny Abyss", "Silent Reach",
    "Sisyphus Statue", "Starfall Gardens",
    "The Celestarium", "Titan Pressure", "Treasure Room", "Tropical Grove",
    "Underground Cellar", "Underwater City",
    "Volcanic Cavern", "Weather Machine"
}

local EVENT_LIST = {
    "Admin - Black Hole", "Admin - Bloodmoon", "Admin - Frostmoon",
    "Admin - Ghost Worm", "Admin - Leviathan Awakening", "Admin - Meteor Rain",
    "Dark Megalodon Hunt", "Glacial Serpent Hunt", "Megalodon Hunt", "Thunderzilla Hunt",
}

local TOTEM_LIST = {
    "Abyssal Totem", "Cosmic Totem", "Easter Totem", "Love Totem",
    "Luck Totem", "Mutation Totem", "Noob Totem", "Shiny Totem",
    "Super Cosmic Totem", "Super Easter Totem", "Super Love Totem"
}

-- ====== STATE ======
local isFishing = false

-- ====== UTILITIES ======
local function teleportTo(name) end
local function findEventPosition(eventName) return nil end
local function getRodInfo() return "None", "None", "None" end
local function getSecretFish() return {} end

-- ====== ORVION GEN2 UI LOAD ======
local _execName = (identifyexecutor and identifyexecutor()) or "Unknown"
local Orvion = loadstring(game:HttpGet("https://raw.githubusercontent.com/KnullXDgt/Orvion-UI-Library-Gen2/main/source.luau?t=" .. os.time()))()

-- ====== WINDOW ======
local Window = Orvion:CreateWindow({
    Title          = "Orvion Hub",
    Icon           = "rbxassetid://95126399202412",
    TitleImage     = "rbxassetid://138517423977481",
    Subtitle       = "",
    Badges         = {"v0.1", "Executor: " .. _execName},
    Center         = true,
    Draggable      = true,
    Resizable      = true,
    MinimizeKey    = Enum.KeyCode.RightShift,
    ToggleButton = true,
    Config = {
        Enabled  = true,
        Folder   = "OrvionHub",
        AutoLoad = true,
    },
})

-- ====== TABS ======
local InfoTab       = Window:CreateTab("Info",          "rbxassetid://94529541997278")
local FishingTab    = Window:CreateTab("Main",          "rbxassetid://117906088481880")
local TpTab         = Window:CreateTab("Teleport",      "rbxassetid://6723742952")
local AutomationTab = Window:CreateTab("Automation",    "rbxassetid://102105242487044")
local ShopTab       = Window:CreateTab("Shop",          "rbxassetid://87353934937155")

-- ====== INFO TAB ======
do
    -- Welcome Card (no loop, one-time async headshot load)
    local WelcomeCard = Instance.new("Frame")
    WelcomeCard.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    WelcomeCard.BackgroundTransparency = 0.3
    WelcomeCard.BorderSizePixel = 0
    WelcomeCard.Size = UDim2.new(1, 0, 0, 88)
    WelcomeCard.LayoutOrder = 0
    WelcomeCard.Parent = InfoTab
    Instance.new("UICorner", WelcomeCard).CornerRadius = UDim.new(0, 12)

    local AvatarFrame = Instance.new("Frame")
    AvatarFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    AvatarFrame.BorderSizePixel = 0
    AvatarFrame.Position = UDim2.new(0, 14, 0.5, -28)
    AvatarFrame.Size = UDim2.new(0, 56, 0, 56)
    AvatarFrame.Parent = WelcomeCard
    Instance.new("UICorner", AvatarFrame).CornerRadius = UDim.new(1, 0)

    local AvatarImg = Instance.new("ImageLabel")
    AvatarImg.Size = UDim2.new(1, 0, 1, 0)
    AvatarImg.BackgroundTransparency = 1
    AvatarImg.BorderSizePixel = 0
    AvatarImg.Parent = AvatarFrame
    Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

    -- One-time async headshot (no loop)
    task.spawn(function()
        local ok, img = pcall(function()
            return game:GetService("Players"):GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok and img then AvatarImg.Image = img end
    end)

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Text = "Hey, " .. LocalPlayer.Name .. "!"
    NameLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    NameLabel.TextSize = 14
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.BackgroundTransparency = 1
    NameLabel.BorderSizePixel = 0
    NameLabel.Size = UDim2.new(1, -96, 0, 20)
    NameLabel.Position = UDim2.new(0, 82, 0, 24)
    NameLabel.Parent = WelcomeCard

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Font = Enum.Font.Gotham
    SubLabel.Text = "Welcome to Orvion Hub"
    SubLabel.TextColor3 = Color3.fromRGB(130, 130, 155)
    SubLabel.TextSize = 12
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.BackgroundTransparency = 1
    SubLabel.BorderSizePixel = 0
    SubLabel.Size = UDim2.new(1, -96, 0, 16)
    SubLabel.Position = UDim2.new(0, 82, 0, 50)
    SubLabel.Parent = WelcomeCard

    local InfoSection = Window:AddCollapsible(InfoTab, "Information", true)
    Window:AddParagraph(InfoSection, "What is Orvion Hub?",
        "Orvion Hub is a reflection of my coding journey, built through trial, error, and a lot of iteration.")
end

-- ====== MAIN TAB ======
do
    local FishSection = Window:AddCollapsible(FishingTab, "Auto Fishing", false)
    Window:AddToggle(FishSection, "Auto Fish", "", false, function(v) Config.AutoFish = v end, "Toggle_AutoFish")
    Window:AddToggle(FishSection, "Perfect Cast", "", false, function(v) Config.PerfectCast = v end, "Toggle_PerfectCast")
    Window:AddToggle(FishSection, "Blatant Mode", "", false, function(v) Config.BlatantActive = v end, "Toggle_Blatant")

    local SellSection = Window:AddCollapsible(FishingTab, "Auto Sell", false)
    Window:AddToggle(SellSection, "Auto Sell", "", false, function(v) Config.AutoSell = v end, "Toggle_AutoSell")
    Window:AddDropdown(SellSection, "Sell Mode", "", {"Tier", "Count"}, false, "Tier", function(v) Config.AutoSellMode = v end, "Dropdown_SellMode")
end

-- ====== TELEPORT TAB ======
do
    local TpIslandSection = Window:AddCollapsible(TpTab, "Teleport to Island", false)
    Window:AddDropdown(TpIslandSection, "Location", "", LOCATION_NAMES, false, "Ancient Jungle", function(v) Config.TeleportLocation = v end, "Dropdown_Location")
    Window:AddButton(TpIslandSection, "Teleport", "", "", function() teleportTo(Config.TeleportLocation) end)

    local TpEventSection = Window:AddCollapsible(TpTab, "Teleport to Event", false)
    Window:AddDropdown(TpEventSection, "Priority Event", "", EVENT_LIST, false, "Select Option", function(v) Config.PriorityEvent = v end, "Dropdown_PriorityEvent")
    Window:AddDropdown(TpEventSection, "Select Event", "", EVENT_LIST, false, "Select Option", function(v) Config.SelectEvent = v end, "Dropdown_SelectEvent")
    Window:AddButton(TpEventSection, "Teleport to Event", "", "", function() end)
end

-- ====== AUTOMATION TAB ======
do
    local WeatherSection = Window:AddCollapsible(AutomationTab, "Auto Buy Weather", false)
    Window:AddToggle(WeatherSection, "Enable Auto Buy Weather", "", false, function(v) Config.BuyWeatherActive = v end, "Toggle_BuyWeather")

    local TotemSection = Window:AddCollapsible(AutomationTab, "Auto Spawn Totem", false)
    Window:AddDropdown(TotemSection, "Select Totem", "", TOTEM_LIST, false, "Luck Totem", function(v) Config.SelectedTotem = v end, "Dropdown_Totem")
    Window:AddToggle(TotemSection, "Auto Spawn Totem", "", false, function(v) Config.AutoSpawnTotem = v end, "Toggle_AutoSpawnTotem")

    do
        local EnchantSection = Window:AddCollapsible(AutomationTab, "Enchant Features", false)
        Window:AddParagraph(EnchantSection, "Enchant Status", "Current Rod: None")
        Window:AddDropdown(EnchantSection, "Enchant Type", "", {"Normal Enchant Stone","Runic Enchant Stone","Evolved Enchant Stone"}, false, "Normal Enchant Stone", function(v) Config.EnchantType = v end, "Dropdown_EnchantType")
        Window:AddDropdown(EnchantSection, "Target Enchant", "", {}, false, "Select Option", function(v) Config.TargetEnchant = v end, "Dropdown_TargetEnchant")
        Window:AddToggle(EnchantSection, "Auto Enchant Reroll", "", false, function(v) Config.AutoEnchantReroll = v end, "Toggle_AutoEnchantReroll")
        Window:AddButtonGrid(EnchantSection,
            { Title = "Teleport to Altar 1", Callback = function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then pcall(function() root.CFrame = CFrame.new(3246.00122, -1300.65588, 1395.11926, -0.430797249, 0, 0.902448714, 0, 1, 0, -0.902448714, 0, -0.430797249) end) end
            end },
            { Title = "Teleport to Altar 2", Callback = function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then pcall(function() root.CFrame = CFrame.new(1478.63489, 130.679703, -609.361938, -0.996601522, 2.26994281e-08, -0.0823735297, 2.58843453e-08, 1, -3.7596422e-08, 0.0823735297, -3.96008382e-08, -0.996601522) end) end
            end }
        )
    end

    do
        local TranscendedSection = Window:AddCollapsible(AutomationTab, "Create Transcended Stone", false)
        Window:AddParagraph(TranscendedSection, "Status", "Waiting")
        Window:AddDropdown(TranscendedSection, "Select Secret Fish", "", {}, false, "Select Option", function(v) Config.SelectedSecretFish = v end, "Dropdown_SecretFish")
        Window:AddButton(TranscendedSection, "Refresh Fish List", "", "rbxassetid://16932740082", function() end)
        Window:AddInput(TranscendedSection, "Amount", "", "Enter amount...", function(v) Config.TranscendedAmount = tonumber(v) or 1 end, "Input_TranscendedAmount")
        Window:AddToggle(TranscendedSection, "Enable Auto Create", "", false, function(v) Config.AutoCreateTranscended = v end, "Toggle_AutoCreateTranscended")
    end
end

-- ====== SHOP TAB ======
do
    local BMSection = Window:AddCollapsible(ShopTab, "Black Market", false)
    Window:AddButton(BMSection, "Refresh", "", "", function() end)
    Window:AddToggle(BMSection, "Auto Buy Black Market", "", false, function(v) Config.AutoBuyBM = v end, "Toggle_AutoBuyBM")

    local MerchantSection = Window:AddCollapsible(ShopTab, "Merchant", false)
    Window:AddDropdown(MerchantSection, "Select Item", "", {}, false, "Select Option", function(v) Config.SelectedMerchantItem = v end, "Dropdown_MerchantItem")
    Window:AddButton(MerchantSection, "Refresh", "", "", function() end)
    Window:AddToggle(MerchantSection, "Auto Buy Merchant", "", false, function(v) Config.AutoBuyMerchant = v end, "Toggle_AutoBuyMerchant")

    local RodSection = Window:AddCollapsible(ShopTab, "Rod Shop", false)
    Window:AddDropdown(RodSection, "Select Rod", "", {}, false, "Select Option", function(v) Config.SelectedRod = v end, "Dropdown_Rod")
    Window:AddButton(RodSection, "Buy Rod", "", "", function() end)

    local BaitSection = Window:AddCollapsible(ShopTab, "Bait Shop", false)
    Window:AddDropdown(BaitSection, "Select Bait", "", {}, false, "Select Option", function(v) Config.SelectedBait = v end, "Dropdown_Bait")
    Window:AddButton(BaitSection, "Buy Bait", "", "", function() end)
end

-- ====== SHOW ======
Window:Show()
