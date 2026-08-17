-- Probe: cek remote PurchaseBait, PurchaseFishingRod, BPPurchaseRequest
local RS = game:GetService("ReplicatedStorage")
local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local out = {}
local function log(s) table.insert(out, s) end

local function GetServerRemote(targetName)
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            log("FOUND: " .. targetName .. " -> next[" .. (i+1) .. "]=" .. tostring(allRemotes[i+1] and allRemotes[i+1].Name or "nil") .. " class=" .. tostring(allRemotes[i+1] and allRemotes[i+1].ClassName or "nil"))
            return allRemotes[i+1]
        end
    end
    log("NOT FOUND: " .. targetName)
    return nil
end

GetServerRemote("RF/PurchaseBait")
GetServerRemote("RE/EquipBait")
GetServerRemote("RF/PurchaseFishingRod")
GetServerRemote("RE/EquipItem")
GetServerRemote("RE/BPPurchaseRequest")
GetServerRemote("RF/PurchaseMarketItem")
GetServerRemote("RF/PurchaseBlackMarketItem")

local result = table.concat(out, "\n")
if writefile then writefile("remote_check.txt", result) end
print(result)
