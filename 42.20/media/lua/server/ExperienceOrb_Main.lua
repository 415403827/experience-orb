-- ============================================================
-- Experience Orb () -  (Build 42)
--
-- 
--  1. 
--     XP - //(/)XP - /VHS
--      > 0 
--  2. 
--     
--
--  Skill Recovery Journal (SRJ) 42.20.1
--   getFreeLevelsFromTraitsAndProfession =  XPBoosts +  XPBoosts
--     +  Strength/Fitness
--   recoverable = perkXP - totalXpForLevel(freeLevel) - mediaXP
--
-- 
--  a. /: Events.OnPlayerDeath
--  b. :  OnPlayerDeath -> sendClientCommand("onPlayerDeath")
--  c. Events.OnTick 
--
-- Kahlua  pcall  Java 
-- tryMethod
-- ============================================================
ExperienceOrb = ExperienceOrb or {}

-- Bump on every behaviour change: the boot banner prints it, so a server log
-- always tells which build is actually loaded.
ExperienceOrb.Version = "0.6.2"

local cfg = nil
local function config()
    if not cfg then
        cfg = ExperienceOrbConfig or {}
    end
    return cfg
end

local function dbg(...)
    local c = config()
    if c.Debug then
        print("[ExperienceOrb] " .. table.concat({...}, " "))
    end
end

-- ----------  +  ----------
local unpackFn = unpack or table.unpack
local function tryMethod(obj, name, ...)
    if obj == nil then return nil end
    local okGet, m = pcall(function() return obj[name] end)
    if not okGet or type(m) ~= "function" then return nil end
    local args = {...}
    local ok, a = pcall(function() return obj[name](obj, unpackFn(args)) end)
    if not ok then return nil end
    return a
end

--  SteamID>0 / SteamID  ""
local function playerSteamID(playerObj)
    local s = tryMethod(playerObj, "getSteamID")
    if s and tonumber(s) and tonumber(s) > 0 then
        -- the engine hands the id over as a double: format it as plain digits
        -- so it does not degrade into 7.656119814527621E16
        return string.format("%.0f", tonumber(s))
    end
    -- no steam id (singleplayer / local host): fall back to the account name
    local u = tryMethod(playerObj, "getUsername")
    if u and tostring(u) ~= "" then return tostring(u) end
    return ""
end

local function playerUserName(playerObj)
    local u = tryMethod(playerObj, "getUsername")
    if u and tostring(u) ~= "" then return tostring(u) end
    return ""
end

local handled = {}   -- 
local announced = {} --  isDead

-- /
local function eachPlayer(cb)
    local players = getOnlinePlayers()
    local count = players and players:size() or 0
    if count > 0 then
        for i = 0, count - 1 do
            local p = players:get(i)
            if p then cb(p) end
        end
        return
    end
    local numActive = 0
    local okN = pcall(function() numActive = getNumActivePlayers() end)
    if not okN or numActive <= 0 then numActive = 1 end
    for n = 0, numActive - 1 do
        local p = getSpecificPlayer(n)
        if p then cb(p) end
    end
end

-- ----------  ----------

local function round2(v)
    return math.floor((v or 0) * 100 + 0.5) / 100
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- 
local function isSkillEnabled(id)
    local c = config()
    if c.DisabledSkills and c.DisabledSkills[id] then return false end
    local found = false
    for catName, list in pairs(ExperienceOrbPerks.Categories) do
        for _, sid in ipairs(list) do
            if sid == id then
                found = true
                if not (c.EnabledSkillGroups and c.EnabledSkillGroups[catName]) then
                    return false
                end
                break
            end
        end
        if found then break end
    end
    return true
end

-- perk  <perkObj>  level  XP (shared with the client)
local function totalXpForLevel(perkObj, level)
    if ExperienceOrbMath and ExperienceOrbMath.TotalXpForLevel then
        return ExperienceOrbMath.TotalXpForLevel(perkObj, level)
    end
    return -1
end

--  SRJ// {perkId = } (shared with the client)
local function buildStartingLevels(playerObj)
    if ExperienceOrbMath and ExperienceOrbMath.StartingLevels then
        return ExperienceOrbMath.StartingLevels(playerObj) or {}
    end
    return {}
end

-- ----------  ----------

-- ============================================================
-- Per character XP baseline (the "free" XP).
--
-- The XP a character has at the moment it spawns is not earned: it is the
-- base levels (Strength / Fitness start at level 5), trait boosts and
-- profession boosts. Everything above that was earned by playing (or by
-- absorbing a previous orb). Reading that snapshot is exact and does not
-- depend on any trait / curve maths.
--
-- It is captured when a new character shows up and cleared on death, so the
-- next character records its own baseline. Characters that existed before
-- the mod was installed fall back to the trait based calculation.
-- ============================================================
local baselineBySteam = {}

local function encodeBaseline(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
    end
    return table.concat(parts, ";")
end

local function decodeBaseline(str)
    if type(str) ~= "string" or str == "" then return nil end
    local out = {}
    local any = false
    for key, val in string.gmatch(str, "([^;=]+)=([^;]*)") do
        local n = tonumber(val)
        if n then
            out[key] = n
            any = true
        end
    end
    if not any then return nil end
    return out
end

local function snapshotAllXp(playerObj)
    local xpSys = tryMethod(playerObj, "getXp")
    if not xpSys then return nil end
    local snap = {}
    for _, id in ipairs(ExperienceOrbPerks.AllIds) do
        local perkObj = ExperienceOrbPerks.PerkObject(id)
        if perkObj then
            local ok, v = pcall(function() return xpSys:getXP(perkObj) end)
            if ok and type(v) == "number" and v > 0 then
                snap[id] = v
            end
        end
    end
    return snap
end

local function captureBaseline(playerObj)
    if not playerObj then return nil end
    local snap = snapshotAllXp(playerObj)
    if not snap then return nil end
    local steam = playerSteamID(playerObj)
    if steam ~= "" then baselineBySteam[steam] = snap end
    local md = tryMethod(playerObj, "getModData")
    if md then md.ExperienceOrbBaseline = encodeBaseline(snap) end
    local charName = tryMethod(tryMethod(playerObj, "getDescriptor"), "getFullName") or ""
    if charName == "" and ExperienceOrbPerks.PlayerName then
        charName = ExperienceOrbPerks.PlayerName(playerObj) or ""
    end
    dbg("baseline captured for " .. tostring(steam) .. " (" .. tostring(charName) .. ")")
    return snap
end

local function peekBaselineString(playerObj)
    local md = tryMethod(playerObj, "getModData")
    if not md then return nil end
    local s = md.ExperienceOrbBaseline
    if type(s) == "string" then return s end
    return nil
end

local function clearBaseline(playerObj)
    local md = tryMethod(playerObj, "getModData")
    if md then md.ExperienceOrbBaseline = nil end
    local steam = playerSteamID(playerObj)
    if steam ~= "" then baselineBySteam[steam] = nil end
end

-- baseline of the character that is dying: live object first, session cache
-- second (needed when the server side player object is already gone)
local function resolveBaseline(playerObj, steam)
    if playerObj then
        local decoded = decodeBaseline(peekBaselineString(playerObj))
        if decoded then return decoded end
    end
    steam = tostring(steam or "")
    if steam ~= "" and baselineBySteam[steam] then
        return baselineBySteam[steam]
    end
    return nil
end

--  XP /
-- ctx = { xpSys = <XpSystem or nil>, free = {perkId = level},
--         baseline = {perkId = xp} or nil,
--         payload = { xp = {}, media = {}, start = {} } or nil }
-- The live player object is authoritative; the payload only fills the
-- gaps when the server side object is already gone (MP respawn race).
local function recoverableXp(playerObj, id, perkObj, ctx)
    ctx = ctx or {}
    local c = config()

    local raw = 0
    local src = "none"
    local xpSys = ctx.xpSys
    if xpSys then
        local ok, v = pcall(function() return xpSys:getXP(perkObj) end)
        if ok and type(v) == "number" and v > 0 then
            raw = v
            src = "live"
        end
    end
    -- the snapshot was taken at the moment of death: when it holds more
    -- XP than the (possibly already respawned) live object, trust it
    if ctx.payload and ctx.payload.xp then
        local v = tonumber(ctx.payload.xp[id])
        if v and v > raw then
            raw = v
            src = "payload"
        end
    end
    if raw <= 0 then return 0 end

    local earned = raw
    local fromPayload = (src == "payload")
    local freeLevel = nil
    local freeXP = 0
    local baselineXP = nil

    if ctx.baseline then
        baselineXP = tonumber(ctx.baseline[id])
    end

    -- 0) spawn baseline: exactly the XP the character was created with
    --    (base levels, trait and profession boosts already applied)
    if c.ExcludeTraitAndProfessionXp and baselineXP and baselineXP > 0 then
        earned = earned - baselineXP
        if earned <= 0.0009 then return 0 end
    end

    -- 1) // XPSRJ 
    if c.ExcludeTraitAndProfessionXp and not (baselineXP and baselineXP > 0) then
        if fromPayload and ctx.payload and ctx.payload.start then
            freeLevel = tonumber(ctx.payload.start[id])
        end
        if not freeLevel and ctx.free then
            if ExperienceOrbMath and ExperienceOrbMath.FreeLevelFor then
                freeLevel = ExperienceOrbMath.FreeLevelFor(ctx.free, id, perkObj)
            else
                freeLevel = ctx.free[id]
            end
        end
        if freeLevel and freeLevel > 0 then
            freeXP = totalXpForLevel(perkObj, math.min(freeLevel, 10))
            if freeXP and freeXP >= 0 then
                earned = earned - freeXP
            end
        end
        if earned <= 0.0009 then return 0 end
    end

    -- 2) /VHS 
    if c.ExcludeMediaXp then
        local media = 0
        if fromPayload and ctx.payload and ctx.payload.media then
            media = tonumber(ctx.payload.media[id]) or 0
        end
        if media <= 0 then
            media = ExperienceOrb_MediaTotal(playerObj, id) or 0
        end
        earned = earned - media
    end

    if earned <= 0.0009 then return 0 end

    -- 3) 
    local ratio = clamp(tonumber(c.RecoveryRatio) or 1.0, 0.01, 1.0)
    local value = round2(earned * ratio)
    if value <= 0 then
        value = earned > 0 and 0.01 or 0
    end
    if value < 0.01 then return 0 end

    dbg("skill " .. id, "src=" .. src, "raw=" .. round2(raw)
        .. " base=" .. tostring(baselineXP or 0)
        .. " free=" .. tostring(freeLevel or 0), "freeXp=" .. tostring(freeXP)
        .. " value=" .. value)
    return value
end

-- ----------  ----------

local spawnOffsets = {
    { 0.30, 0.30 }, { 0.65, 0.35 }, { 0.40, 0.70 }, { 0.75, 0.75 },
    { 0.20, 0.60 }, { 0.60, 0.20 }, { 0.35, 0.10 }, { 0.10, 0.40 },
}

local function squareOk(sq)
    if not sq then return false end
    local solid = tryMethod(sq, "isSolid")
    if solid then return false end
    local veh = tryMethod(sq, "isVehicleCollision")
    if veh then return false end
    return true
end

--  <= config 
local function collectDropSquares(centerSq, radius)
    local out = {}
    if centerSq then out[#out + 1] = centerSq end
    local cell = getCell()
    if not cell then return out end
    radius = radius or 1
    for dx = -radius, radius do
        for dy = -radius, radius do
            if dx ~= 0 or dy ~= 0 then
                local x = math.floor(tryMethod(centerSq, "getX") or 0) + dx
                local y = math.floor(tryMethod(centerSq, "getY") or 0) + dy
                local z = math.floor(tryMethod(centerSq, "getZ") or 0)
                local sq = cell:getGridSquare(x, y, z)
                if squareOk(sq) then
                    out[#out + 1] = sq
                end
            end
        end
    end
    return out
end

-- 
-- The death payload carries everything the drop needs, because in MP
-- the server side player object can already be null / respawned when
-- the death command arrives.
local seenTokens = {}
local seenTokenCount = 0
local function tokenSeen(token)
    if not token then return false end
    token = tostring(token)
    if seenTokens[token] then return true end
    seenTokens[token] = true
    seenTokenCount = seenTokenCount + 1
    if seenTokenCount > 400 then
        seenTokens = {}
        seenTokenCount = 0
    end
    return false
end

local function payloadSquare(payload)
    if not payload then return nil end
    local x, y, z = tonumber(payload.x), tonumber(payload.y), tonumber(payload.z)
    if not x or not y then return nil end
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
end

local function processDeath(playerObj, force, payload)
    if payload and payload.token and tokenSeen(payload.token) then
        dbg("death payload already handled")
        return
    end
    if not playerObj and not payload then return end
    if playerObj and handled[playerObj] then return end
    if playerObj and not force and not payload and not tryMethod(playerObj, "isDead") then
        announced[playerObj] = true
        return
    end
    if playerObj then
        handled[playerObj] = true
        announced[playerObj] = nil
    end

    local c = config()
    local ownerSteam = playerSteamID(playerObj)
    if (ownerSteam == nil or ownerSteam == "") and payload then
        ownerSteam = tostring(payload.steam or "")
    end

    local ownerUser = playerUserName(playerObj)
    if ownerUser == "" and payload then
        ownerUser = tostring(payload.user or "")
    end

    -- Label written on the orb: the ACCOUNT NAME (username), so orbs can be
    -- told apart in multiplayer - "Fitness XP Orb (Shimakaze)".
    -- The character name is only a fallback: a dedicated server descriptor has
    -- no forename / surname.
    local charName = ownerUser
    if charName == "" and payload and payload.user then
        charName = tostring(payload.user)
    end
    if charName == "" and ExperienceOrbPerks.PlayerName then
        charName = ExperienceOrbPerks.PlayerName(playerObj) or ""
    end
    if charName == "" and payload and payload.char then
        charName = tostring(payload.char)
    end
    if charName == nil then charName = "" end

    -- live data wins, payload fills the gaps
    local ctx = { payload = payload }
    ctx.baseline = resolveBaseline(playerObj, ownerSteam)
    if playerObj then
        ctx.xpSys = tryMethod(playerObj, "getXp")
        ctx.free = buildStartingLevels(playerObj)
    end
    dbg("baseline: " .. (ctx.baseline and encodeBaseline(ctx.baseline) or "none (trait fallback)"))

    -- this character is dying: its baseline is consumed, the respawned
    -- character has to record its own
    if playerObj then
        clearBaseline(playerObj)
    elseif ownerSteam and tostring(ownerSteam) ~= "" and baselineBySteam[tostring(ownerSteam)] == ctx.baseline then
        baselineBySteam[tostring(ownerSteam)] = nil
    end

    -- 
    local drops = {}
    for _, id in ipairs(ExperienceOrbPerks.AllIds) do
        if isSkillEnabled(id) then
            local perkObj = ExperienceOrbPerks.PerkObject(id)
            if perkObj then
                local value = recoverableXp(playerObj, id, perkObj, ctx)
                if value and value > 0 then
                    drops[#drops + 1] = { id = id, value = value }
                end
            end
        end
    end

    dbg("died: " .. tostring(ownerSteam)
        .. " source=" .. (playerObj and "live" or "payload")
        .. " drops=" .. #drops)

    -- 
    if playerObj then ExperienceOrb_MediaClear(playerObj) end

    if c.Debug and ctx.free then
        local parts = {}
        for k, v in pairs(ctx.free) do
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
        dbg("freeLevels: " .. table.concat(parts, " "))
    end

    if #drops == 0 then
        dbg("no XP to recover for " .. tostring(ownerSteam))
        return
    end

    -- 
    local sq = tryMethod(playerObj, "getSquare")
    if not sq then sq = payloadSquare(payload) end
    if not sq then
        local x = tryMethod(playerObj, "getX") or (payload and tonumber(payload.x)) or 0
        local y = tryMethod(playerObj, "getY") or (payload and tonumber(payload.y)) or 0
        local z = tryMethod(playerObj, "getZ") or (payload and tonumber(payload.z)) or 0
        local cell = getCell()
        if cell then
            sq = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
        end
    end
    if not sq then
        dbg("no drop square for " .. tostring(ownerSteam))
        return
    end
    local squares = collectDropSquares(sq, tonumber(c.DropSpreadRadius) or 1)
    if #squares == 0 then
        squares = { sq }
    end

    local ownerStr = tostring(ownerSteam or "")
    local charStr = charName and tostring(charName) or ""
    local spawned = 0
    for i, d in ipairs(drops) do
        local dropSq = squares[((i - 1) % #squares) + 1]
        local off = spawnOffsets[((i - 1) % #spawnOffsets) + 1]
        local itemType = ExperienceOrbPerks.ItemTypeFor(d.id)
        local item = tryMethod(dropSq, "AddWorldInventoryItem", itemType, off[1], off[2], 0)
        if item then
            -- capacity of this skill: the XP of level 10 (the engine stops
            -- collecting above it), the orb is filled to that scale
            local cap = totalXpForLevel(ExperienceOrbPerks.PerkObject(d.id), 10)
            if not cap or cap <= 0 then cap = d.value end
            local stored = d.value
            if stored > cap then stored = cap end

            local md = tryMethod(item, "getModData")
            if md then
                md.xp = stored
                md.cap = cap
                md.owner = ownerStr
                md.ownerSteam = ownerStr
                md.ownerUser = ownerUser
                md.char = charStr
                md.perk = d.id
            end
            -- gauge = content / capacity; floored to one use so the engine never
            -- sees the orb as empty (an empty drainable gets the "(Empty)" name
            -- suffix and is deleted as soon as it is moved)
            local frac = 1.0
            if cap and cap > 0 then frac = stored / cap end
            if frac > 1 then frac = 1 end
            local minFrac = 0.001
            local ud = tryMethod(item, "getUseDelta")
            if ud and tonumber(ud) and tonumber(ud) > 0 then minFrac = tonumber(ud) end
            if frac < minFrac then frac = minFrac end
            pcall(function() item:setUsedDelta(frac) end)
            pcall(function() item:setCurrentUsesFloat(frac) end)
            -- Name the orb ONCE, here at generation time: "<skill orb> (<owner>)".
            -- The base text comes from the server's translation, so it is written
            -- in the SERVER's language; a client that runs
            -- ExperienceOrb_ClientName.lua re-derives the same label in its own
            -- language and overwrites it. That pass is idempotent (it compares
            -- before writing), so the owner part is never appended twice.
            if charStr ~= "" then
                local base = tryMethod(item, "getDisplayName")
                if base == nil or base == "" then base = itemType end
                local label = base
                if ExperienceOrbPerks.OwnerLabel then
                    label = ExperienceOrbPerks.OwnerLabel(base, charStr)
                end
                tryMethod(item, "setName", label)
                tryMethod(item, "setCustomName", true)
            end
            tryMethod(item, "SynchSpawn")
            spawned = spawned + 1
            dbg("drop " .. itemType .. " xp=" .. tostring(stored) .. "/" .. tostring(cap)
                .. " owner=" .. charStr .. " steam=" .. ownerStr)
        else
            dbg("FAILED to spawn " .. itemType)
        end
    end
    print("[ExperienceOrb] " .. spawned .. " orbs dropped for " .. tostring(ownerSteam)
        .. " (" .. charStr .. ")")
end

-- ----------  ----------

local function findItemByID(inv, itemID)
    local direct = tryMethod(inv, "getItemWithID", itemID)
    if direct then return direct end
    local items = tryMethod(inv, "getItems")
    if items then
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and tryMethod(it, "getID") == itemID then
                return it
            end
        end
    end
    return nil
end

-- Send the absorb result to the client so the halo text is written in the
-- PLAYER's language (a message composed here would use the server language).
local function notifyOrbResult(playerObj, kind, perkId, gained, remaining, cap)
    if not playerObj then return end
    pcall(function()
        sendServerCommand(playerObj, "ExperienceOrb", "orbResult", {
            kind = kind,
            perk = perkId,
            gained = gained or 0,
            left = remaining or 0,
            cap = cap or 0,
        })
    end)
end

local function applyOrb(playerObj, item, perkId)
    if not playerObj or not item then return end
    local inv = tryMethod(playerObj, "getInventory")
    if not inv then return end

    local md = tryMethod(item, "getModData")
    local value = md and tonumber(md.xp) or 0
    if not (value > 0) then return end
    if not isSkillEnabled(perkId) then return end

    local c = config()

    --  SteamID 
    -- / SteamID or by account name (the steam id is a double in the engine and
    -- still has to match orbs written by an older version of the mod)
    if not c.AllowAnyoneToAbsorb then
        local ownerSteam = md and tostring(md.ownerSteam or md.owner or "") or ""
        local ownerUser = md and tostring(md.ownerUser or "") or ""
        local curSteam = playerSteamID(playerObj)
        local curUser = playerUserName(playerObj)
        local okOwner = false
        if ExperienceOrbPerks.SameOwner then
            okOwner = ExperienceOrbPerks.SameOwner(ownerSteam, curSteam)
        else
            okOwner = (ownerSteam ~= "" and ownerSteam == curSteam)
        end
        if not okOwner and ownerUser ~= "" and curUser ~= "" then
            okOwner = (string.lower(ownerUser) == string.lower(curUser))
        end
        -- an orb without any owner information stays usable
        local hasOwnerInfo = (ownerSteam ~= "" or ownerUser ~= "")
        if hasOwnerInfo and not okOwner then
            dbg("orb " .. perkId .. " owned by " .. ownerSteam .. "/" .. ownerUser
                .. " skipped for " .. curSteam .. "/" .. curUser)
            return
        end
    end

    local perkObj = ExperienceOrbPerks.PerkObject(perkId)
    if not perkObj then return end

    -- ---------- capacity: an orb holds at most the XP of level 10 ----------
    -- The engine stops collecting XP at level 10 (totalXpForLevel(10): 32775 for
    -- a normal skill, 487500 for Strength / Fitness), so anything a player would
    -- absorb above that cap would be thrown away. The orb is a container: only
    -- what fits is absorbed, the rest stays inside for the next life / config.
    local cap = totalXpForLevel(perkObj, 10)
    if not cap or cap <= 0 then cap = tonumber(md and md.cap) or 0 end
    if cap <= 0 then cap = value end
    if value > cap then value = cap end

    local raw = 0
    if ExperienceOrbMath and ExperienceOrbMath.RawXp then
        raw = ExperienceOrbMath.RawXp(playerObj, perkObj) or 0
    end
    local room = cap - raw
    if room < 0 then room = 0 end

    if room <= 0.0009 then
        dbg("orb " .. perkId .. " refused: raw=" .. round2(raw) .. " cap=" .. round2(cap))
        notifyOrbResult(playerObj, "capped", perkId, 0, value, cap)
        return
    end

    local grant = value
    if grant > room then grant = room end
    local remaining = value - grant
    if remaining < 0.0009 then remaining = 0 end

    -- 
    -- addXpNoMultiplier ignores the sandbox XP multiplier, so absorbing an
    -- orb always grants exactly the XP stored in the orb (never more).
    local usedNoMultiplier = false
    local okGrant = pcall(function()
        if addXpNoMultiplier then
            usedNoMultiplier = true
            addXpNoMultiplier(playerObj, perkObj, grant)
        else
            addXp(playerObj, perkObj, grant)
        end
    end)
    if not okGrant then return end

    if remaining <= 0 then
        pcall(function()
            inv:Remove(item)
            sendRemoveItemFromContainer(inv, item)
        end)
        dbg("use " .. perkId .. " xp=" .. tostring(grant)
            .. " noMultiplier=" .. tostring(usedNoMultiplier) .. " orb emptied")
        notifyOrbResult(playerObj, "full", perkId, grant, 0, cap)
    else
        -- Keep the orb with what is left: store the remaining XP and, for orbs
        -- created by this version, update the vanilla "uses" gauge
        -- (usedDelta = remaining fraction, 1.0 = full).
        --
        -- Orbs written by an earlier version of the mod are deliberately left
        -- alone: the engine restores their item class from the ItemType id in
        -- the save file, so they stay plain items and simply ignore the gauge
        -- calls below (all of them are pcall guarded). Their XP, owner and perk
        -- live in ModData and keep working, and the client shows the remaining
        -- amount in the name. They will be cleaned up in a later release.
        -- keep the orb with what is left: md.xp is the content, md.cap the
        -- capacity (level 10 XP), the vanilla gauge shows content / capacity.
        --
        -- The engine treats a drainable as EMPTY when its uses reach 0 - it then
        -- appends "(Empty)" to the name and DELETES the item when it is moved.
        -- So the fraction is floored to one use: an orb that still holds XP can
        -- never become empty, however small its share of the capacity is.
        local md2 = tryMethod(item, "getModData")
        if md2 then
            md2.xp = remaining
            if md2.cap == nil then md2.cap = cap end
            if md2.perk == nil then md2.perk = perkId end
        end
        local frac = 1.0
        if cap and cap > 0 then frac = remaining / cap end
        local minFrac = 0.001
        local ud = tryMethod(item, "getUseDelta")
        if ud and tonumber(ud) and tonumber(ud) > 0 then minFrac = tonumber(ud) end
        if frac > 1 then frac = 1 end
        if frac < minFrac then frac = minFrac end
        pcall(function() item:setUsedDelta(frac) end)
        pcall(function() item:setCurrentUsesFloat(frac) end)
        pcall(function() item:syncItemFields() end)

        dbg("use " .. perkId .. " xp=" .. tostring(grant)
            .. " noMultiplier=" .. tostring(usedNoMultiplier)
            .. " left=" .. tostring(round2(remaining)))
        notifyOrbResult(playerObj, "partial", perkId, grant, remaining, cap)
    end
end

local function handleUseOrb(playerObj, args)
    if not playerObj then return end
    local itemID = args and args.itemID
    if itemID == nil then return end
    local inv = tryMethod(playerObj, "getInventory")
    if not inv then return end
    local item = findItemByID(inv, itemID)
    if not item then return end

    local ft = tryMethod(item, "getFullType")
    if ft == nil then return end
    for _, id in ipairs(ExperienceOrbPerks.AllIds) do
        if ft == ExperienceOrbPerks.FullTypeFor(id) then
            applyOrb(playerObj, item, id)
            return
        end
    end
end

local tickCount = 0
local function tickScan()
    tickCount = tickCount + 1
    if tickCount % 30 == 0 then
        local onlineNow = {}
        eachPlayer(function(p)
            onlineNow[p] = true
            if tryMethod(p, "isDead") then
                processDeath(p)
            elseif handled[p] then
                -- death already processed, waiting for the replacement
            else
                -- alive again (respawned): allow the next death to drop and
                -- record the spawn baseline of this character (only while the
                -- character is brand new, otherwise the already earned XP
                -- would silently become part of the free baseline)
                handled[p] = nil
                announced[p] = nil
                local hours = tryMethod(p, "getHoursSurvived")
                if (hours == nil or hours <= 0.1) and not peekBaselineString(p) then
                    captureBaseline(p)
                end
            end
        end)
        for obj in pairs(ExperienceOrbMedia) do
            if handled[obj] or not onlineNow[obj] then
                ExperienceOrb_MediaClear(obj)
            end
        end
        for obj, _ in pairs(announced) do
            if not handled[obj] then
                if not onlineNow[obj] then
                    processDeath(obj, true)
                elseif tryMethod(obj, "isDead") then
                    processDeath(obj)
                end
            else
                announced[obj] = nil
            end
        end
    end
end

-- ----------  ----------

-- ============================================================
-- Events
-- ============================================================

-- the only reliable moment to record the free (not earned) XP of a
-- character: right when it is created, with base levels, traits and
-- profession boosts already applied
Events.OnCreatePlayer.Add(function(playerIndex, playerObj)
    if playerObj and not peekBaselineString(playerObj) then
        captureBaseline(playerObj)
    end
end)

function ExperienceOrb.OnPlayerDeath(playerObj)
    if not playerObj then return end
    if isClient() and not isServer() then return end
    processDeath(playerObj, true)
end

-- The client reports its own death (and, in MP, also supplies the XP
-- snapshot). player may be nil here, the payload is enough.
function ExperienceOrb.OnClientCommand(module, command, player, args)
    if module ~= "ExperienceOrb" then return end
    if command == "onPlayerDeath" then
        processDeath(player, true, args)
    elseif command == "useOrb" and player then
        handleUseOrb(player, args)
    end
end

function ExperienceOrb.OnTick()
    tickScan()
end

Events.OnPlayerDeath.Add(ExperienceOrb.OnPlayerDeath)
Events.OnClientCommand.Add(ExperienceOrb.OnClientCommand)
Events.OnTick.Add(ExperienceOrb.OnTick)

-- 
Events.OnGameBoot.Add(function()
    local c = config()
    print("[ExperienceOrb] v" .. tostring(ExperienceOrb.Version) .. " loaded. ratio="
        .. tostring(c.RecoveryRatio)
        .. " excludeMedia=" .. tostring(c.ExcludeMediaXp)
        .. " excludeTrait=" .. tostring(c.ExcludeTraitAndProfessionXp)
        .. " debug=" .. tostring(c.Debug))
    if c.Debug and ExperienceOrbMath and ExperienceOrbMath.DumpCurve then
        ExperienceOrbMath.DumpCurve(ExperienceOrbPerks.AllIds, ExperienceOrbPerks.PerkObject, print)
    end
end)
