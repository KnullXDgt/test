-- Probe: exact copy of findEventPosition logic from test.lua
local out = {}
local function log(s) table.insert(out, s) print(s) end

local EVENT_LIST = {
    "Dark Megalodon Hunt","Glacial Serpent Hunt","Megalodon Hunt","Thunderzilla Hunt"
}

for _, eventName in ipairs(EVENT_LIST) do
    local lowerName = eventName:lower():gsub(" hunt", "")
    local found = false
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find(lowerName, 1, true) then
            log(eventName .. " => FOUND: " .. obj.Name .. " parent=" .. tostring(obj.Parent and obj.Parent.Name) .. " pos=" .. tostring(obj:GetPivot().Position))
            found = true
        end
    end
    if not found then log(eventName .. " => NOT FOUND") end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
