-- Probe: battlepass structure + currency + test fire
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

-- BattlepassShop
local ok1, BS = pcall(function() return require(RS.Shared.BattlepassShop) end)
if not ok1 then log("[ERR] BattlepassShop: " .. tostring(BS)) else
    log("BattlepassShop count=" .. tostring(#BS))
    for i, v in ipairs(BS) do
        if i <= 5 then -- sample 5
            log("  [" .. i .. "] Price=" .. tostring(v.Price) .. " Type=" .. tostring(v.RewardInfo and v.RewardInfo.Type or "?") .. " Id=" .. tostring(v.RewardInfo and v.RewardInfo.Identifier or "?"))
        end
    end
end

-- RewardInfo BattlepassCurrency
local ok2, RI = pcall(function() return require(RS.Shared.RewardInfo) end)
if ok2 then
    log("BattlepassCurrency.Path=" .. tostring(RI.BattlepassCurrency and RI.BattlepassCurrency.Path or "?"))
    log("BattlepassCurrency.Prefix=" .. tostring(RI.BattlepassCurrency and RI.BattlepassCurrency.Prefix or "?"))
else
    log("[ERR] RewardInfo: " .. tostring(RI))
end

-- PlayerData GalaxyBP26
local ok3, PlayerData = pcall(function()
    return require(RS.Packages.Replion).Client:WaitReplion("Data")
end)
if ok3 then
    local ok4, bp = pcall(function() return PlayerData:Get("GalaxyBP26") end)
    if ok4 then
        log("GalaxyBP26 type=" .. type(bp))
        if type(bp) == "table" then
            local count = 0
            for k, v in pairs(bp) do count = count + 1; if count <= 5 then log("  key=" .. tostring(k) .. " val=" .. tostring(v)) end end
            log("  total keys=" .. count)
        else
            log("  value=" .. tostring(bp))
        end
    else
        log("[ERR] GalaxyBP26: " .. tostring(bp))
    end
    -- currency balance
    if ok2 and RI and RI.BattlepassCurrency and RI.BattlepassCurrency.Path then
        local bal = PlayerData:Get(RI.BattlepassCurrency.Path)
        log("BP Currency balance=" .. tostring(bal))
    end
else
    log("[ERR] PlayerData: " .. tostring(PlayerData))
end

-- Remote
local ok5, Net = pcall(function() return require(RS.Packages.Net) end)
if ok5 then
    local re = Net:RemoteEvent("BPPurchaseRequest")
    log("RE/BPPurchaseRequest found=" .. tostring(re ~= nil))
end

local result = table.concat(out, "\n")
if writefile then writefile("probe.txt", result) end
print(result)
