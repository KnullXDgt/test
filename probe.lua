-- Probe: catch thunderzilla including non-Model + late load
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

-- Scan all descendants, any class
local function scanAll(label)
    log("=== SCAN: " .. label .. " ===")
    for _, obj in ipairs(workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if name:find("thunder", 1, true) or name:find("glacial", 1, true) then
            log(obj.ClassName .. " | " .. obj.Name .. " | parent=" .. tostring(obj.Parent and obj.Parent.Name))
        end
    end
end

scanAll("immediate")

-- Listen for new descendants for 10 seconds
log("=== WATCHING DescendantAdded (10s) ===")
local watchConn
watchConn = workspace.DescendantAdded:Connect(function(obj)
    local name = obj.Name:lower()
    if name:find("thunder", 1, true) or name:find("glacial", 1, true) then
        log("ADDED: " .. obj.ClassName .. " | " .. obj.Name .. " | parent=" .. tostring(obj.Parent and obj.Parent.Name))
        save()
    end
end)

task.delay(10, function()
    if watchConn then watchConn:Disconnect() end
    scanAll("after 10s")
    save()
    log("DONE")
    save()
end)
