-- Probe: FULL game dump - all possible items + rod enchants
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
local inventory = PlayerData and PlayerData:Get("Inventory") or {}

-- ====== ROD ENCHANTS (check raw item data) ======
log("=== GHOSTFINN ROD RAW DATA ===")
pcall(function()
    local rods = inventory["Fishing Rods"] or {}
    for _, item in ipairs(rods) do
        if item.UUID == "1fe5376d-09f0-44f8-9f55-e4dc5bcaaa76" then
            -- Dump ALL fields of this item
            local parts = {}
            for k,v in pairs(item) do
                if type(v) == "table" then
                    local tp = {}
                    for k2,v2 in pairs(v) do table.insert(tp, tostring(k2).."="..tostring(v2)) end
                    table.insert(parts, tostring(k).."={"..table.concat(tp,",").."}")
                else
                    table.insert(parts, tostring(k).."="..tostring(v))
                end
            end
            log("  item: "..table.concat(parts, " | "))
            -- Also check ItemData
            local ok, data = pcall(IU.GetItemDataFromItemType, "Fishing Rods", item.Id)
            if ok and data then
                -- Check for Enchants field at various levels
                for _, path in ipairs({"Enchants","Data.Enchants","enchants"}) do
                    local val = data
                    for part in path:gmatch("[^.]+") do val = type(val)=="table" and val[part] or nil end
                    if val then log("  "..path.."="..tostring(val)) end
                end
            end
        end
    end
end)

-- ====== ALL ENCHANTS IN GAME ======
log("=== ALL ENCHANTS (require RS.Shared.Enchants) ===")
pcall(function()
    local enchants = require(RS.Shared.Enchants)
    local count = 0
    for name, data in pairs(enchants) do
        count = count + 1
        local tier = data and data.Data and data.Data.Tier or "?"
        log("  "..tostring(name).." [Tier "..tostring(tier).."]")
    end
    log("Total enchants: "..count)
end)

-- ====== ALL ENCHANT STONES ======
log("=== ALL ENCHANT STONE TYPES ===")
pcall(function()
    local stones = IU:GetEnchantStones()
    if type(stones) == "table" then
        for _, stone in ipairs(stones) do
            local name = stone and stone.Data and stone.Data.Name or tostring(stone)
            log("  "..name)
        end
    end
end)

-- ====== ALL FISHING RODS IN GAME (iterate IDs) ======
log("=== ALL FISHING RODS (game catalog) ===")
pcall(function()
    local count = 0
    for id = 1, 500 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Fishing Rods", id)
        if ok and data and data.Data and data.Data.Name then
            local enchants = ""
            if data.Data.Enchants then
                local ep = {}
                for k,v in pairs(data.Data.Enchants) do table.insert(ep, k.."("..tostring(v)..")") end
                enchants = " E:{"..table.concat(ep,",").."}"
            end
            log("  id="..id.." "..data.Data.Name..enchants)
            count = count + 1
        end
    end
    log("Total rods: "..count)
end)

-- ====== ALL BAITS ======
log("=== ALL BAITS (game catalog) ===")
pcall(function()
    local count = 0
    for id = 1, 200 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Baits", id)
        if ok and data and data.Data and data.Data.Name then
            log("  id="..id.." "..data.Data.Name)
            count = count + 1
        end
    end
    log("Total baits: "..count)
end)

save()
log("DONE")
save()
