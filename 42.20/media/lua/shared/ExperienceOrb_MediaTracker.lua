-- ============================================================
-- Experience Orb - media (TV / VHS) XP ledger (Build 42)
--
-- In B42 TV and VHS use the same XP channel, so both are excluded
-- together.
--
-- The vanilla client file shared/RadioCom/ISRadioInteractions.lua
--   Events.OnDeviceText -> checkPlayer -> doSkill -> addXp(...)
-- grants 50 * codes XP per line. We wrap checkPlayer and remember
-- how much XP each perk gained through that path.
--
-- Ledger layout: ExperienceOrbMedia[playerObj][perkId] = xp
-- (perk id strings keep the table serializable for the death
--  snapshot that the client sends to the server.)
-- ============================================================
ExperienceOrbMedia = ExperienceOrbMedia or {}

-- XP of every orb perk, keyed by perk id
local function snapshotXp(playerObj)
    local xpSys = nil
    if ExperienceOrbMath then xpSys = ExperienceOrbMath.Call(playerObj, "getXp") end
    if not xpSys then
        local ok = pcall(function() xpSys = playerObj:getXp() end)
        if not ok then return nil end
    end
    if not xpSys then return nil end
    local t = {}
    for _, id in ipairs(ExperienceOrbPerks.AllIds) do
        local per = ExperienceOrbPerks.PerkObject(id)
        if per then
            local ok, val = pcall(function() return xpSys:getXP(per) end)
            if ok and type(val) == "number" then
                t[id] = val
            end
        end
    end
    return t
end

local function ledgerFor(playerObj)
    local ledger = ExperienceOrbMedia[playerObj]
    if not ledger then
        ledger = {}
        ExperienceOrbMedia[playerObj] = ledger
    end
    return ledger
end

-- wrap the vanilla media interaction handler
local function wrapMediaInteractions()
    local radio = ISRadioInteractions
    if not radio then return end
    local inst = nil
    if radio.getInstance then inst = radio.getInstance() end
    if not inst or inst.__ExperienceOrbWrapped then return end
    local orig = inst.checkPlayer
    if type(orig) ~= "function" then return end

    inst.__ExperienceOrbWrapped = true
    inst.checkPlayer = function(playerObj, guid, codes, x, y, z, line)
        local before = nil
        local dead = false
        pcall(function() dead = playerObj:isDead() end)
        if playerObj and not dead then
            before = snapshotXp(playerObj)
        end
        local res = orig(playerObj, guid, codes, x, y, z, line)
        if before then
            local after = snapshotXp(playerObj)
            if after then
                local ledger = ledgerFor(playerObj)
                for id, old in pairs(before) do
                    local now = after[id]
                    if type(now) == "number" then
                        local d = now - old
                        if d > 0.0009 then
                            ledger[id] = (ledger[id] or 0) + d
                        end
                    end
                end
            end
        end
        return res
    end
end

-- media XP of one perk (0 when unknown)
function ExperienceOrb_MediaTotal(playerObj, perkId)
    local ledger = ExperienceOrbMedia[playerObj]
    if not ledger then return 0 end
    return ledger[perkId] or 0
end

-- copy of the whole ledger (perk id -> xp), used for the death snapshot
function ExperienceOrb_MediaTable(playerObj)
    local ledger = ExperienceOrbMedia[playerObj]
    if not ledger then return nil end
    local out = {}
    local any = false
    for id, v in pairs(ledger) do
        out[id] = v
        any = true
    end
    if not any then return nil end
    return out
end

function ExperienceOrb_MediaClear(playerObj)
    ExperienceOrbMedia[playerObj] = nil
end

Events.OnGameBoot.Add(function()
    wrapMediaInteractions()
end)
