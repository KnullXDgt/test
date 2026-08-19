-- Probe: scan ALL instances for EVENT_LIST keywords (any class, any location)
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local EVENT_LIST = {
    "Dark Megalodon Hunt","Glacial Serpent Hunt","Megalodon Hunt","Thunderzilla Hunt",
    "Admin - Leviathan Awakening","Admin - Bloodmoon","Admin - Frostmoon","Admin - Meteor Rain"
}
local keywords = {}
for _, e in ipairs(EVENT_LIST) do
    -- extract last word as keyword
    local kw = e:lower():match("(%a+)%s*$") or e:lower()
    keywords[kw] = e
end

log("Keywords: " .. table.concat((function() local t={} for k in pairs(keywords) do table.insert(t,k) end return t end)(), ", "))

-- Deep scan workspace + ReplicatedStorage + ServerStorage
local roots = {workspace}
pcall(function() table.insert(roots, game:GetService("ReplicatedStorage")) end)
pcall(function() table.insert(roots, game:GetService("ServerStorage")) end)

for _, root in ipairs(roots) do
    for _, obj in ipairs(root:GetDescendants()) do
        local lower = obj.Name:lower()
        for kw, eventName in pairs(keywords) do
            if lower:find(kw, 1, true) then
                log("[" .. eventName .. "] " .. obj.ClassName .. ":" .. obj.Name .. " @ " .. root.Name .. "/" .. tostring(obj.Parent and obj.Parent.Name))
                break
            end
        end
    end
end

save()
