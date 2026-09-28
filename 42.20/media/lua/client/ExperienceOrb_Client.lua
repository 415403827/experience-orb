-- ============================================================
-- Experience Orb - client part (Build 42)
--
-- The client is the only side that reliably sees the death of its own
-- character, and it is also the side that owns the TV/VHS media
-- ledger (RadioCom is a client class).
--
-- On death the client sends the server:
--   { xp = { perkId = rawXp }, media = { perkId = mediaXp },
--     start = { perkId = freeLevel }, char = name,
--     x = , y = , z = , steam = , token = }
-- The server prefers its own live player object and uses this payload
-- only as a fallback, which covers the MP case where the server side
-- player object is already gone / replaced when the command arrives
-- ("receiveClientCommand: player is null"). The payload is captured at
-- the moment of death and re-sent a few times after the respawn; the
-- token makes the server ignore duplicates.
-- ============================================================
local deathToken = nil
local pendingPayload = nil
local pendingResends = 0
local lastReported = false

local function isLocalPlayer(playerObj)
    if not playerObj then return false end
    local me = nil
    pcall(function() me = getPlayer() end)
    if me == nil then
        pcall(function() me = getSpecificPlayer(0) end)
    end
    if me == nil then return true end
    local a, b = nil, nil
    pcall(function() a = playerObj:getPlayerNum() end)
    pcall(function() b = me:getPlayerNum() end)
    if a == nil or b == nil then return true end
    return a == b
end

local function localPlayer()
    local me = nil
    pcall(function() me = getPlayer() end)
    if me == nil then
        pcall(function() me = getSpecificPlayer(0) end)
    end
    return me
end

local function safe(call, fallback)
    local ok, v = pcall(call)
    if not ok or v == nil then return fallback end
    return v
end

local function buildPayload(playerObj)
    local payload = {}

    local steam = ""
    pcall(function() steam = tostring(playerObj:getSteamID() or "") end)
    if steam ~= "" and tonumber(steam) then steam = string.format("%.0f", tonumber(steam)) end
    payload.steam = steam

    local user = ""
    pcall(function() user = tostring(playerObj:getUsername() or "") end)
    payload.user = user

    local char = ""
    if ExperienceOrbPerks and ExperienceOrbPerks.PlayerName then
        pcall(function() char = ExperienceOrbPerks.PlayerName(playerObj) end)
    end
    if char == nil or char == "" then
        pcall(function() char = tostring(playerObj:getDescriptor():getFullName() or "") end)
    end
    if char == nil then char = "" end
    payload.char = char

    payload.x = safe(function() return math.floor(playerObj:getX()) end, 0)
    payload.y = safe(function() return math.floor(playerObj:getY()) end, 0)
    payload.z = safe(function() return math.floor(playerObj:getZ()) end, 0)

    -- raw XP of every orb perk
    local xp = {}
    local xpSys = nil
    pcall(function() xpSys = playerObj:getXp() end)
    if xpSys then
        for _, id in ipairs(ExperienceOrbPerks.AllIds) do
            local per = ExperienceOrbPerks.PerkObject(id)
            if per then
                local ok, v = pcall(function() return xpSys:getXP(per) end)
                if ok and type(v) == "number" and v > 0 then
                    xp[id] = v
                end
            end
        end
    end
    payload.xp = xp

    -- TV / VHS ledger (only the client has it)
    local media = {}
    if ExperienceOrb_MediaTable then
        local tbl = ExperienceOrb_MediaTable(playerObj)
        if tbl then
            for id, v in pairs(tbl) do
                media[tostring(id)] = v
            end
        end
    end
    payload.media = media

    -- free levels (profession / traits / passive)
    local start = {}
    if ExperienceOrbMath and ExperienceOrbMath.StartingLevels then
        local free = ExperienceOrbMath.StartingLevels(playerObj) or {}
        for id, v in pairs(free) do
            start[tostring(id)] = v
        end
    end
    payload.start = start

    return payload
end

local function sendPayload(playerObj, payload)
    if not playerObj or not payload then return end
    local ok = pcall(function()
        sendClientCommand(playerObj, "ExperienceOrb", "onPlayerDeath", payload)
    end)
    if not ok then
        pcall(function()
            sendClientCommand("ExperienceOrb", "onPlayerDeath", payload)
        end)
    end
end

-- called while the character is dying
local function reportDeath(playerObj)
    if not playerObj then return end
    if isServer() then return end
    if not isLocalPlayer(playerObj) then return end

    if pendingPayload == nil then
        local rnd = 0
        pcall(function() rnd = ZombRand(1000000) end)
        deathToken = tostring(os.time()) .. "-" .. tostring(rnd)
        pendingPayload = buildPayload(playerObj)
        pendingPayload.token = deathToken
        pendingResends = 0
    end
    if lastReported then return end
    lastReported = true
    sendPayload(playerObj, pendingPayload)
end

-- 1) the death event of this client
Events.OnPlayerDeath.Add(function(playerObj)
    reportDeath(playerObj)
end)

-- 2) poll fallback: the event is not guaranteed to fire in MP, and the
--    first command can be lost while the server replaces the dead
--    player, so the same payload is re-sent after the respawn.
local tick = 0
Events.OnTick.Add(function()
    tick = tick + 1
    if tick % 60 ~= 0 then return end
    local me = localPlayer()
    if me == nil then return end
    local dead = false
    pcall(function() dead = me:isDead() end)

    if dead then
        reportDeath(me)
        return
    end

    if pendingPayload then
        if pendingResends < 4 then
            pendingResends = pendingResends + 1
            sendPayload(me, pendingPayload)
        else
            pendingPayload = nil
            deathToken = nil
        end
    end
    lastReported = false
end)
