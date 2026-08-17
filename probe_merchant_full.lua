-- Probe: dump Merchant.Items dengan MarketItemData lookup
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

-- Load MarketItemData (sama persis seperti controller)
local ok1, MID = pcall(function() return require(RS.Shared.MarketItemData) end)
if not ok1 then log("[ERR] MarketItemData: " .. tostring(MID)) else
    log("MarketItemData count=" .. tostring(#MID))
    -- build map id->data
    local midMap = {}
    for _, v in ipairs(MID) do
        midMap[v.Id] = v
    end

    -- get Merchant replion
    local ok2, Replion = pcall(function() return require(RS.Packages.Replion) end)
    if not ok2 then log("[ERR] Replion: " .. tostring(Replion)) else
        local ok3, mr = pcall(function() return Replion.Client:WaitReplion("Merchant") end)
        if not ok3 then log("[ERR] Merchant replion: " .. tostring(mr)) else
            local ok4, items = pcall(function() return mr:GetExpect("Items") end)
            if ok4 and items then
                log("Merchant.Items count=" .. tostring(#items))
                local ok5, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
                for i, itemId in ipairs(items) do
                    log("--- Item[" .. i .. "] id=" .. tostring(itemId) .. " ---")
                    local md = midMap[itemId]
                    if md then
                        log("  MarketItemData.Type=" .. tostring(md.Type))
                        log("  MarketItemData.Identifier=" .. tostring(md.Identifier))
                        log("  MarketItemData.Price=" .. tostring(md.Price))
                        log("  MarketItemData.Currency=" .. tostring(md.Currency))
                        -- resolve name via ItemUtility
                        if ok5 and IU then
                            local ok6, data = pcall(function()
                                return IU.GetItemDataFromItemType(md.Type, md.Identifier)
                            end)
                            if ok6 and data and data.Data then
                                log("  Name=" .. tostring(data.Data.Name or "?"))
                            else
                                log("  Name=[ERR]")
                            end
                        end
                    else
                        log("  [ERR] No MarketItemData for id=" .. tostring(itemId))
                    end
                end
            else
                log("[ERR] Items: " .. tostring(items))
            end
        end
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("merchant_full.txt", result) end
print(result)
