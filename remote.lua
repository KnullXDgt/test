-- remote.lua: net mapper + OnClientEvent logger (filtered to local player)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("remote_log.txt", table.concat(out, "\n")) end end

local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local labelToRemote = {}
local children = net:GetChildren()
for i = 1, #children - 1 do
    local a, b = children[i], children[i+1]
    if a and b then
        local la = a.Name:lower()
        if (la:sub(1,3)=="rf/" or la:sub(1,3)=="re/") and #b.Name == 67 then
            labelToRemote[a.Name] = b
        end
    end
end

local mapped = 0
for _ in pairs(labelToRemote) do mapped = mapped + 1 end
log("Mapped " .. mapped .. " remotes | Filtering for: " .. LP.Name)
save()

local function isForMe(args)
    if #args == 0 then return true end
    local ok, isPlayer = pcall(function()
        return typeof(args[1]) == "Instance" and args[1]:IsA("Player")
    end)
    if ok and isPlayer then return args[1] == LP end
    return true
end

local function dumpArgs(args)
    local parts = {}
    for i, v in ipairs(args) do
        local s = "?"
        pcall(function()
            if typeof(v) == "Instance" then s = v.ClassName..":"..v.Name
            else s = tostring(v) end
        end)
        table.insert(parts, "["..i.."]="..s)
    end
    return table.concat(parts, " ")
end

local conns = {}
for label, remote in pairs(labelToRemote) do
    pcall(function()
        if remote:IsA("RemoteEvent") then
            local conn = remote.OnClientEvent:Connect(function(...)
                local args = {...}
                if not isForMe(args) then return end
                log("[CE] " .. label .. " | " .. dumpArgs(args))
                save()
            end)
            table.insert(conns, conn)
        end
    end)
end

log("Listening on " .. #conns .. " events")
save()

local t = 0
local function tick()
    t = t + 5; save()
    if t < 300 then task.delay(5, tick) end
end
task.delay(5, tick)
