-- Probe: test PurchaseMarketItem return value
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local function GetRemote(name)
    local c = net:GetChildren()
    for i, v in ipairs(c) do
        if v.Name == name then return c[i+1] end
    end
end

local rf = GetRemote("RF/PurchaseMarketItem")
log("RF found=" .. tostring(rf ~= nil))
if rf then
    -- test invoke item id=7 (Shiny Totem)
    local ok, result = pcall(function() return rf:InvokeServer(7) end)
    log("ok=" .. tostring(ok))
    log("result type=" .. type(result))
    log("result value=" .. tostring(result))
    if type(result) == "table" then
        for k,v in pairs(result) do log("  " .. tostring(k) .. "=" .. tostring(v)) end
    end
end

local r = table.concat(out, "\n")
if writefile then writefile("probe.txt", r) end
print(r)
