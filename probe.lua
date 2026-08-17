-- Probe: BP currency path deep search + fire test
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

-- deep dump RewardInfo.BattlepassCurrency
local ok1, RI = pcall(function() return require(RS.Shared.RewardInfo) end)
if ok1 then
    local bc = RI.BattlepassCurrency
    log("BattlepassCurrency type=" .. type(bc))
    if type(bc) == "table" then
        for k, v in pairs(bc) do
            log("  " .. tostring(k) .. "=" .. tostring(v))
        end
    elseif type(bc) == "function" then
        local ok2, val = pcall(bc)
        log("  fn result=" .. tostring(val))
    end
    -- try calling it
    local ok3, bcVal = pcall(function() return RI:BattlepassCurrency() end)
    if ok3 then log("  :BattlepassCurrency()=" .. tostring(bcVal)) end
end

-- scan PlayerData for any key with value >= 1000 (likely currency)
local ok4, PlayerData = pcall(function()
    return require(RS.Packages.Replion).Client:WaitReplion("Data")
end)
if ok4 then
    local ok5, allData = pcall(function() return PlayerData:Get() end)
    if ok5 and type(allData) == "table" then
        log("PlayerData top-level keys:")
        for k, v in pairs(allData) do
            if type(v) == "number" and v > 0 then
                log("  " .. tostring(k) .. "=" .. tostring(v))
            end
        end
    end
end

-- test fire slots 1,2,3 and see if in-game notif appears
log("=== TEST FIRE ===")
local ok6, Net = pcall(function() return require(RS.Packages.Net) end)
if ok6 then
    local re = Net:RemoteEvent("BPPurchaseRequest")
    if re then
        for _, idx in ipairs({1, 2, 3}) do
            local ok7 = pcall(function() re:FireServer(idx) end)
            log("FireServer(" .. idx .. ") ok=" .. tostring(ok7))
            task.wait(0.5)
        end
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("probe.txt", result) end
print(result)
