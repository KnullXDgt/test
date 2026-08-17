-- Probe: cek Data.Id actual dari catalog rod+bait
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
if not ok then log("[ERR] " .. tostring(IU)) else
    -- Rod sample: Starter=22, Luck Rod=182
    log("=== RODS ===")
    for _, numId in ipairs({22, 182, 154, 37}) do
        local ok2, data = pcall(function() return IU.GetItemDataFromItemType("Fishing Rods", numId) end)
        if ok2 and data then
            log("numId=" .. numId .. " Data.Id=" .. tostring(data.Data and data.Data.Id or "?") .. " Name=" .. tostring(data.Data and data.Data.Name or "?"))
        end
    end
    -- Bait sample: Topwater=49, Luck=29
    log("=== BAITS ===")
    for _, numId in ipairs({49, 29, 71, 15}) do
        local ok2, data = pcall(function() return IU.GetItemDataFromItemType("Baits", numId) end)
        if ok2 and data then
            log("numId=" .. numId .. " Data.Id=" .. tostring(data.Data and data.Data.Id or "?") .. " Name=" .. tostring(data.Data and data.Data.Name or "?"))
        end
    end
    -- BP: cek BattlepassCurrency path
    log("=== BP CURRENCY ===")
    local ok3, BPC = pcall(function() return require(RS.Shared.BattlepassConfig or RS.Modules.BattlepassConfig) end)
    if ok3 and BPC then
        log("BattlepassCurrency=" .. tostring(BPC.BattlepassCurrency and BPC.BattlepassCurrency.Path or "?"))
        log("DataKey=" .. tostring(BPC.DataKey or "GalaxyBP26"))
    else
        log("BattlepassConfig err: " .. tostring(BPC))
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("dataid_probe.txt", result) end
print(result)
