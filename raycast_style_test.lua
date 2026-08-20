-- Raycast Style Hub UI Test
-- Run in executor to preview style in-game

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- cleanup
if pg:FindFirstChild("RaycastTest") then pg.RaycastTest:Destroy() end

-- ─── Colors ──────────────────────────────────────────────────────────────────
local C = {
    BG        = Color3.fromRGB(7, 8, 10),
    SURFACE   = Color3.fromRGB(16, 17, 17),
    SURFACE2  = Color3.fromRGB(27, 28, 30),
    ACCENT    = Color3.fromRGB(255, 99, 99),
    BLUE      = Color3.fromRGB(85, 179, 255),
    GREEN     = Color3.fromRGB(95, 201, 146),
    TEXT      = Color3.fromRGB(249, 249, 249),
    TEXT2     = Color3.fromRGB(206, 206, 206),
    TEXT3     = Color3.fromRGB(156, 156, 157),
    MUTED     = Color3.fromRGB(106, 107, 108),
    BORDER    = Color3.fromRGB(37, 40, 41),
    TRANSPARENT = Color3.fromRGB(0, 0, 0),
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function new(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function corner(r, parent)
    return new("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
end

local function stroke(t, c, parent)
    return new("UIStroke", {Thickness = t, Color = c, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
end

local function padding(top, right, bottom, left, parent)
    return new("UIPadding", {
        PaddingTop    = UDim.new(0, top),
        PaddingRight  = UDim.new(0, right),
        PaddingBottom = UDim.new(0, bottom),
        PaddingLeft   = UDim.new(0, left),
    }, parent)
end

local function listLayout(dir, gap, parent)
    return new("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, gap or 0),
    }, parent)
end

local function label(text, size, weight, color, parent)
    local l = new("TextLabel", {
        Text              = text,
        TextSize          = size,
        FontFace          = Font.new("rbxasset://fonts/families/GothamSSm.json", weight, Enum.FontStyle.Normal),
        TextColor3        = color,
        BackgroundTransparency = 1,
        TextXAlignment    = Enum.TextXAlignment.Left,
        AutomaticSize     = Enum.AutomaticSize.XY,
    }, parent)
    return l
end

-- ─── ScreenGui ───────────────────────────────────────────────────────────────
local gui = new("ScreenGui", {
    Name = "RaycastTest",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 100,
}, pg)

-- ─── Window ───────────────────────────────────────────────────────────────────
local win = new("Frame", {
    Name             = "Window",
    Size             = UDim2.fromOffset(520, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    Position         = UDim2.new(0.5, -260, 0.5, -200),
    BackgroundColor3 = C.BG,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
}, gui)
corner(14, win)
stroke(1, C.BORDER, win)
listLayout(Enum.FillDirection.Vertical, 0, win)

-- drag
do
    local dragging, dragStart, startPos
    win.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = inp.Position
            startPos = win.Position
        end
    end)
    win.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ─── Titlebar ─────────────────────────────────────────────────────────────────
local titlebar = new("Frame", {
    Name             = "Titlebar",
    Size             = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = C.BG,
    BorderSizePixel  = 0,
}, win)
padding(0, 16, 0, 16, titlebar)

-- dots
local dots = new("Frame", {
    Size             = UDim2.fromOffset(0, 10),
    AutomaticSize    = Enum.AutomaticSize.X,
    Position         = UDim2.new(0, 0, 0.5, -5),
    BackgroundTransparency = 1,
}, titlebar)
listLayout(Enum.FillDirection.Horizontal, 6, dots)
for _, col in ipairs({Color3.fromRGB(255, 95, 87), Color3.fromRGB(254, 188, 46), Color3.fromRGB(40, 200, 64)}) do
    local d = new("Frame", {Size = UDim2.fromOffset(10,10), BackgroundColor3 = col, BorderSizePixel = 0}, dots)
    corner(5, d)
end

-- title
local titleLabel = new("TextLabel", {
    Text             = "Orvion Hub",
    TextSize         = 13,
    FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
    TextColor3       = C.TEXT3,
    BackgroundTransparency = 1,
    Position         = UDim2.new(0, 82, 0.5, -8),
    Size             = UDim2.fromOffset(100, 16),
}, titlebar)

-- version badge
local vbadge = new("Frame", {
    Size             = UDim2.fromOffset(0, 16),
    AutomaticSize    = Enum.AutomaticSize.X,
    Position         = UDim2.new(0, 182, 0.5, -8),
    BackgroundColor3 = C.ACCENT,
    BorderSizePixel  = 0,
}, titlebar)
corner(4, vbadge)
padding(0, 6, 0, 6, vbadge)
local vt = new("TextLabel", {
    Text             = "v2.1",
    TextSize         = 10,
    FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
    TextColor3       = Color3.new(1,1,1),
    BackgroundTransparency = 1,
    Size             = UDim2.fromOffset(0, 16),
    AutomaticSize    = Enum.AutomaticSize.X,
}, vbadge)

-- close btn
local closeBtn = new("TextButton", {
    Text             = "✕",
    TextSize         = 12,
    FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
    TextColor3       = C.MUTED,
    BackgroundTransparency = 1,
    Position         = UDim2.new(1, -28, 0.5, -10),
    Size             = UDim2.fromOffset(20, 20),
    BorderSizePixel  = 0,
}, titlebar)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- titlebar divider
new("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = C.BORDER,
    BorderSizePixel  = 0,
}, win)

-- ─── Tab Bar ──────────────────────────────────────────────────────────────────
local tabbar = new("Frame", {
    Name             = "TabBar",
    Size             = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = C.BG,
    BorderSizePixel  = 0,
}, win)
padding(0, 16, 0, 16, tabbar)
listLayout(Enum.FillDirection.Horizontal, 4, tabbar)

local tabs = {"Fishing", "Enchant", "Quest", "Player", "Settings"}
local activeTab = "Fishing"
local tabButtons = {}

for _, name in ipairs(tabs) do
    local btn = new("TextButton", {
        Text             = name,
        TextSize         = 12,
        FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
        TextColor3       = name == activeTab and C.TEXT or C.MUTED,
        BackgroundTransparency = 1,
        Size             = UDim2.fromOffset(0, 36),
        AutomaticSize    = Enum.AutomaticSize.X,
        BorderSizePixel  = 0,
    }, tabbar)
    padding(0, 10, 0, 10, btn)
    tabButtons[name] = btn

    -- active underline
    local underline = new("Frame", {
        Name             = "Underline",
        Size             = UDim2.new(1, -20, 0, 2),
        Position         = UDim2.new(0, 10, 1, -2),
        BackgroundColor3 = C.ACCENT,
        BorderSizePixel  = 0,
        Visible          = name == activeTab,
    }, btn)
    corner(1, underline)
end

-- tab divider
new("Frame", {Size = UDim2.new(1,0,0,1), BackgroundColor3 = C.BORDER, BorderSizePixel = 0}, win)

-- ─── Body ─────────────────────────────────────────────────────────────────────
local body = new("Frame", {
    Name             = "Body",
    Size             = UDim2.new(1, 0, 0, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel  = 0,
}, win)
padding(12, 12, 12, 12, body)
listLayout(Enum.FillDirection.Vertical, 10, body)

-- ─── Helper: Section ──────────────────────────────────────────────────────────
local function makeSection(title, actionText)
    local sec = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.SURFACE,
        BorderSizePixel  = 0,
    }, body)
    corner(10, sec)
    stroke(1, Color3.fromRGB(30, 32, 32), sec)
    listLayout(Enum.FillDirection.Vertical, 0, sec)

    -- header
    local hdr = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, sec)
    padding(0, 14, 0, 14, hdr)
    new("TextLabel", {
        Text             = title:upper(),
        TextSize         = 10,
        FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
        TextColor3       = C.MUTED,
        BackgroundTransparency = 1,
        Size             = UDim2.new(0.7, 0, 1, 0),
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, hdr)
    if actionText then
        new("TextButton", {
            Text             = actionText,
            TextSize         = 11,
            FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
            TextColor3       = C.ACCENT,
            BackgroundTransparency = 1,
            Position         = UDim2.new(1, -80, 0, 0),
            Size             = UDim2.fromOffset(80, 32),
            TextXAlignment   = Enum.TextXAlignment.Right,
            BorderSizePixel  = 0,
        }, hdr)
    end
    -- header divider
    new("Frame", {Size = UDim2.new(1,0,0,1), BackgroundColor3 = Color3.fromRGB(25,27,27), BorderSizePixel = 0}, sec)

    return sec
end

-- ─── Helper: Row with Toggle ──────────────────────────────────────────────────
local function makeToggleRow(parent, labelText, subText, isOn, divider)
    local row = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, parent)
    padding(0, 14, 0, 14, row)

    new("TextLabel", {
        Text             = labelText,
        TextSize         = 13,
        FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
        TextColor3       = C.TEXT,
        BackgroundTransparency = 1,
        Position         = UDim2.new(0, 0, 0, 8),
        Size             = UDim2.new(0.7, 0, 0, 16),
        TextXAlignment   = Enum.TextXAlignment.Left,
    }, row)
    if subText then
        new("TextLabel", {
            Text             = subText,
            TextSize         = 11,
            FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
            TextColor3       = C.MUTED,
            BackgroundTransparency = 1,
            Position         = UDim2.new(0, 0, 0, 26),
            Size             = UDim2.new(0.7, 0, 0, 14),
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, row)
    end

    -- toggle
    local on = isOn
    local track = new("Frame", {
        Size             = UDim2.fromOffset(36, 20),
        Position         = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = on and C.ACCENT or Color3.fromRGB(40, 42, 42),
        BorderSizePixel  = 0,
    }, row)
    corner(10, track)
    if on then stroke(1, C.ACCENT, track) end

    local ball = new("Frame", {
        Size             = UDim2.fromOffset(14, 14),
        Position         = on and UDim2.fromOffset(20, 3) or UDim2.fromOffset(2, 3),
        BackgroundColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(120,120,120),
        BorderSizePixel  = 0,
    }, track)
    corner(7, ball)

    -- click
    local clickArea = new("TextButton", {
        Size             = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Text             = "",
        BorderSizePixel  = 0,
    }, track)
    clickArea.MouseButton1Click:Connect(function()
        on = not on
        track.BackgroundColor3 = on and C.ACCENT or Color3.fromRGB(40, 42, 42)
        TweenService:Create(ball, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position         = on and UDim2.fromOffset(20, 3) or UDim2.fromOffset(2, 3),
            BackgroundColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(120,120,120),
        }):Play()
    end)

    if divider then
        new("Frame", {
            Size             = UDim2.new(1, -28, 0, 1),
            Position         = UDim2.new(0, 14, 1, -1),
            BackgroundColor3 = Color3.fromRGB(25,27,27),
            BorderSizePixel  = 0,
        }, row)
    end

    return row
end

-- ─── Helper: Button Row ───────────────────────────────────────────────────────
local function makeBtnRow(parent, buttons)
    local row = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, parent)
    padding(8, 12, 8, 12, row)
    new("Frame", {
        Size             = UDim2.new(1,-28,0,1),
        Position         = UDim2.new(0,14,0,0),
        BackgroundColor3 = Color3.fromRGB(25,27,27),
        BorderSizePixel  = 0,
    }, parent)
    listLayout(Enum.FillDirection.Horizontal, 6, row)

    for _, bdata in ipairs(buttons) do
        local isPrimary = bdata[2] == "primary"
        local isSecondary = bdata[2] == "secondary"
        local btn = new("TextButton", {
            Text             = bdata[1],
            TextSize         = 12,
            FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
            TextColor3       = isPrimary and Color3.new(1,1,1) or C.TEXT2,
            BackgroundColor3 = isPrimary and C.ACCENT or (isSecondary and Color3.fromRGB(28,30,30) or Color3.fromRGB(20,22,22)),
            Size             = UDim2.new(1/#buttons, -(6*(#buttons-1)/#buttons), 1, 0),
            BorderSizePixel  = 0,
        }, row)
        corner(7, btn)
        if not isPrimary then stroke(1, Color3.fromRGB(35,38,38), btn) end
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
        end)
    end
    return row
end

-- ─── Stat Bar ─────────────────────────────────────────────────────────────────
do
    local statSec = makeSection("Player Stats")
    local statRow = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 64),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, statSec)
    padding(8, 10, 8, 10, statRow)
    listLayout(Enum.FillDirection.Horizontal, 6, statRow)

    local stats = {{"42,221","CAUGHT"},{"2.88M","COINS"},{"389","LEVEL"},{"5","SECRETS"}}
    for _, sd in ipairs(stats) do
        local card = new("Frame", {
            Size             = UDim2.new(0.25, -5, 1, 0),
            BackgroundColor3 = Color3.fromRGB(20, 22, 22),
            BorderSizePixel  = 0,
        }, statRow)
        corner(8, card)
        stroke(1, Color3.fromRGB(30,32,32), card)
        new("TextLabel", {
            Text             = sd[1],
            TextSize         = 15,
            FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            TextColor3       = C.TEXT,
            BackgroundTransparency = 1,
            Position         = UDim2.new(0, 8, 0, 8),
            Size             = UDim2.new(1, -16, 0, 18),
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, card)
        new("TextLabel", {
            Text             = sd[2],
            TextSize         = 9,
            FontFace         = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
            TextColor3       = C.MUTED,
            BackgroundTransparency = 1,
            Position         = UDim2.new(0, 8, 0, 28),
            Size             = UDim2.new(1, -16, 0, 12),
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, card)
    end
end

-- ─── Auto Fishing Section ──────────────────────────────────────────────────────
do
    local sec = makeSection("Auto Fishing", "Config")
    makeToggleRow(sec, "Auto Fish", "Charge → wait → catch loop", true, true)
    makeToggleRow(sec, "Perfect Cast", "Force perfect throw", true, true)
    makeToggleRow(sec, "Auto Sell", "Sell when inventory full", false, true)
    makeToggleRow(sec, "Teleport to Area", "Jump to fishing spot", false, false)

    -- progress bar
    local prog = new("Frame", {
        Size             = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, sec)
    padding(8, 14, 8, 14, prog)
    new("Frame", {Size=UDim2.new(1,-28,0,1), Position=UDim2.new(0,14,0,0), BackgroundColor3=Color3.fromRGB(25,27,27), BorderSizePixel=0}, sec)
    new("TextLabel", {
        Text="Element Quest — Obj3: SECRET at Sacred Temple",
        TextSize=11, FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Medium,Enum.FontStyle.Normal),
        TextColor3=C.TEXT2, BackgroundTransparency=1,
        Position=UDim2.new(0,0,0,0), Size=UDim2.new(0.7,0,0,14),
        TextXAlignment=Enum.TextXAlignment.Left,
    }, prog)
    new("TextLabel", {
        Text="0 / 1", TextSize=11,
        FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Medium,Enum.FontStyle.Normal),
        TextColor3=C.MUTED, BackgroundTransparency=1,
        Position=UDim2.new(1,-32,0,0), Size=UDim2.fromOffset(32,14),
        TextXAlignment=Enum.TextXAlignment.Right,
    }, prog)
    local track = new("Frame", {
        Size=UDim2.new(1,0,0,4), Position=UDim2.new(0,0,0,22),
        BackgroundColor3=Color3.fromRGB(25,28,28), BorderSizePixel=0,
    }, prog)
    corner(2, track)
    local fill = new("Frame", {
        Size=UDim2.new(0.05,0,1,0), BackgroundColor3=C.ACCENT, BorderSizePixel=0,
    }, track)
    corner(2, fill)

    makeBtnRow(sec, {{"Start","primary"},{"Teleport","secondary"},{"Reset","ghost"}})
end

-- ─── Enchant Section ──────────────────────────────────────────────────────────
do
    local sec = makeSection("Enchant — Ghostfinn Rod", "Refresh")

    local function enchantRow(e, id, divider)
        local row = new("Frame", {Size=UDim2.new(1,0,0,46), BackgroundTransparency=1, BorderSizePixel=0}, sec)
        padding(0,14,0,14,row)
        new("TextLabel", {
            Text=e, TextSize=13,
            FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Medium,Enum.FontStyle.Normal),
            TextColor3=C.TEXT, BackgroundTransparency=1,
            Position=UDim2.new(0,0,0,8), Size=UDim2.new(0.7,0,0,16),
            TextXAlignment=Enum.TextXAlignment.Left,
        }, row)
        new("TextLabel", {
            Text="id="..id, TextSize=11,
            FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Regular,Enum.FontStyle.Normal),
            TextColor3=C.MUTED, BackgroundTransparency=1,
            Position=UDim2.new(0,0,0,26), Size=UDim2.new(0.7,0,0,14),
            TextXAlignment=Enum.TextXAlignment.Left,
        }, row)
        -- chip
        local chip = new("Frame", {
            Size=UDim2.fromOffset(0,18), AutomaticSize=Enum.AutomaticSize.X,
            Position=UDim2.new(1,-60,0.5,-9),
            BackgroundColor3=Color3.fromRGB(40,20,20), BorderSizePixel=0,
        }, row)
        corner(4, chip)
        stroke(1, Color3.fromRGB(80,30,30), chip)
        padding(0,8,0,8,chip)
        new("TextLabel", {
            Text="ACTIVE", TextSize=9,
            FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal),
            TextColor3=C.ACCENT, BackgroundTransparency=1,
            Size=UDim2.fromOffset(0,18), AutomaticSize=Enum.AutomaticSize.X,
        }, chip)
        if divider then
            new("Frame", {Size=UDim2.new(1,-28,0,1), Position=UDim2.new(0,14,1,-1), BackgroundColor3=Color3.fromRGB(25,27,27), BorderSizePixel=0}, row)
        end
    end

    enchantRow("E1 · Stormhunter II", "19", true)
    enchantRow("E2 · Glistening I", "1", false)
    makeBtnRow(sec, {{"Go to Altar","primary"},{"Create T-Stone","secondary"}})
end

-- ─── Statusbar ────────────────────────────────────────────────────────────────
new("Frame", {Size=UDim2.new(1,0,0,1), BackgroundColor3=C.BORDER, BorderSizePixel=0}, win)
local sb = new("Frame", {
    Size=UDim2.new(1,0,0,32), BackgroundColor3=C.BG, BorderSizePixel=0,
}, win)
padding(0,16,0,16,sb)

local dot = new("Frame", {
    Size=UDim2.fromOffset(6,6), Position=UDim2.new(0,0,0.5,-3),
    BackgroundColor3=C.GREEN, BorderSizePixel=0,
}, sb)
corner(3, dot)

new("TextLabel", {
    Text="Idle — Sacred Temple",
    TextSize=11,
    FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Medium,Enum.FontStyle.Normal),
    TextColor3=C.MUTED, BackgroundTransparency=1,
    Position=UDim2.new(0,14,0.5,-7), Size=UDim2.fromOffset(200,14),
    TextXAlignment=Enum.TextXAlignment.Left,
}, sb)

new("TextLabel", {
    Text="Orvion · Delta 1.1.733",
    TextSize=10,
    FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Regular,Enum.FontStyle.Normal),
    TextColor3=Color3.fromRGB(60,62,63), BackgroundTransparency=1,
    Position=UDim2.new(1,-160,0.5,-7), Size=UDim2.fromOffset(160,14),
    TextXAlignment=Enum.TextXAlignment.Right,
}, sb)

print("Raycast Style Test loaded.")
