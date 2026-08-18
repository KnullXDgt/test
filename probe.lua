-- Probe: merchant items - check MarketItemData fields
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local out = {}
local function log(s) table.insert(out, s) print(s) end

local function dump(t, depth)
    if type(t) ~= "table" or depth > 2 then return tostring(t) end
    local parts = {}
    for k,v in pairs(t) do
        table.insert(parts, tostring(k) .. "=" .. dump(v, depth+1))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- Wait for game
task.wait(3)

local ok, Replion = pcall(function()
    return require(RS.Packages.Replion)
end)
if not ok then log("Replion fail: " .. tostring(Replion)) return end

local mr = Replion.Client:WaitReplion("MarketItems")
if not mr then log("MarketItems Replion not found") return end

local ok2, MID = pcall(function() return require(RS.Shared.MarketItemData) end)
local ok3, IU = pcall(function() return require(RS.Shared.ItemUtility) end)

log("MID loaded=" .. tostring(ok2) .. " IU loaded=" .. tostring(ok3))

local midMap = {}
if ok2 and MID then
    for _, v in ipairs(MID) do midMap[v.Id] = v end
end

local itemIds = {}
pcall(function() itemIds = mr:GetExpect("Items") or {} end)
log("Total merchant item IDs: " .. tostring(#itemIds))

for i, itemId in ipairs(itemIds) do
    local md = midMap[itemId]
    if md then
        log("[" .. i .. "] id=" .. tostring(itemId)
            .. " Type=" .. tostring(md.Type)
            .. " Identifier=" .. tostring(md.Identifier)
            .. " Price=" .. tostring(md.Price)
            .. " Currency=" .. tostring(md.Currency)
            .. " RobuxPrice=" .. tostring(md.RobuxPrice))
    else
        log("[" .. i .. "] id=" .. tostring(itemId) .. " (no MarketItemData)")
    end
end

if writefile then
    writefile("probe.txt", table.concat(out, "\n"))
    log("Written to probe.txt")
end
