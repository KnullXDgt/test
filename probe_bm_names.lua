-- Probe: dump BlackMarketConfig item names via RewardInfo
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, BMC = pcall(function() return require(RS.Shared.BlackMarketConfig) end)
if not ok then log("[ERR] " .. tostring(BMC)) else
    local ok2, items = pcall(function() return BMC.GetItems() end)
    if ok2 and items then
        for _, item in ipairs(items) do
            -- dump semua field di item + RewardInfo
            local id = tostring(item.Id or "?")
            local ri = item.RewardInfo or {}
            local riname = tostring(ri.Name or ri.DisplayName or ri.ItemName or "?")
            local ritype = tostring(ri.Type or "?")
            local riid = tostring(ri.Id or "?")
            log(id .. " | RewardInfo.Name=" .. riname .. " | Type=" .. ritype .. " | Id=" .. riid)
        end
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("bm_names.txt", result) end
print(result)
