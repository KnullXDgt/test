-- remote.lua: map all remotes + log OnClientEvent fires
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("remote_log.txt", table.concat(out, "\n")) end end

-- Build hash -> label map
local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local hashToLabel = {}
local labelToRemote = {}
local children = net:GetChildren()
for i = 1, #children - 1 do
    local a, b = children[i], children[i+1]
    if a and b then
        local la, lb = a.Name:lower(), b.Name:lower()
        -- pattern: label (RF/RE prefix) followed by hash (67 chars)
        if (la:sub(1,3)=="rf/" or la:sub(1,3)=="re/") and #b.Name == 67 then
            hashToLabel[b.Name] = a.Name
            labelToRemote[a.Name] = b
        elseif (lb:sub(1,3)=="rf/" or lb:sub(1,3)=="re/") and #a.Name == 67 then
            hashToLabel[a.Name] = b.Name
            labelToRemote[b.Name] = a
        end
    end
end

local mapped = 0
for _ in pairs(hashToLabel) do mapped = mapped + 1 end
log("Mapped " .. mapped .. " remotes")
save()

-- Connect OnClientEvent to ALL remotes
local conns = {}
for label, remote in pairs(labelToRemote) do
    pcall(function()
        if remote:IsA("RemoteEvent") then
            local conn = remote.OnClientEvent:Connect(function(...)
                local args = {...}
                local parts = {}
                for i, v in ipairs(args) do
                    table.insert(parts, "[" .. i .. "]=" .. tostring(v))
                end
                local msg = "[CE] " .. label .. " | " .. table.concat(parts, " ")
                log(msg)
                save()
            end)
            table.insert(conns, conn)
        elseif remote:IsA("RemoteFunction") then
            -- RF: wrap OnClientInvoke
            remote.OnClientInvoke = function(...)
                local args = {...}
                local parts = {}
                for i, v in ipairs(args) do
                    table.insert(parts, "[" .. i .. "]=" .. tostring(v))
                end
                log("[CI] " .. label .. " | " .. table.concat(parts, " "))
                save()
                return nil
            end
        end
    end)
end

log("Listening on " .. #conns .. " events. Watching for enchant/transcend...")
save()

-- Auto-save every 10s for 3 min
local elapsed = 0
local function tick()
    elapsed = elapsed + 10
    save()
    if elapsed < 180 then task.delay(10, tick) end
end
task.delay(10, tick)
