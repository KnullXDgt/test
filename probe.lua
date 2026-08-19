-- Probe: find thunderzilla + full EVENT_LIST exact vs partial
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function getPath(obj)
    local parts = {}
    local cur = obj
    while cur and cur ~= workspace do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, " / ")
end

local EVENT_LIST = {
    "Dark Megalodon Hunt","Glacial Serpent Hunt","Megalodon Hunt","Thunderzilla Hunt"
}

log("=== THUNDERZILLA SEARCH (any match) ===")
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Model") and obj.Name:lower():find("thunderzilla", 1, true) then
        log("FOUND: " .. obj.Name .. " @ path: " .. getPath(obj))
    end
end

log("=== GLACIAL SEARCH ===")
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Model") and obj.Name:lower():find("glacial", 1, true) then
        log("FOUND: " .. obj.Name .. " @ path: " .. getPath(obj))
    end
end

log("=== EXACT MATCH all EVENT_LIST ===")
for _, eventName in ipairs(EVENT_LIST) do
    local found = false
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower() == eventName:lower() then
            log("EXACT: " .. eventName .. " => pos=" .. tostring(obj:GetPivot().Position))
            found = true
        end
    end
    if not found then log("NO EXACT: " .. eventName) end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
