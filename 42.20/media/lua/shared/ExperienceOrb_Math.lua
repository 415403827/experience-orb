-- ============================================================
-- Experience Orb - shared XP math (Build 42.20)
--
-- Loaded on both the server and the client:
--   * server: authoritative drop calculation
--   * client: death snapshot that is sent together with the death
--     command, so a drop is still possible when the server side
--     player object is already gone (null) at that moment.
--
-- Every engine call is pcall guarded: a missing engine method must
-- never break the mod, it only returns nil.
-- ============================================================
ExperienceOrbMath = ExperienceOrbMath or {}

local unpackFn = unpack or table.unpack

local function call(obj, name, ...)
    if obj == nil then return nil end
    local args = {...}
    local ok, res = pcall(function() return obj[name](obj, unpackFn(args)) end)
    if not ok then return nil end
    return res
end

ExperienceOrbMath.Call = call

-- Engine data: passive perks (Strength / Fitness) start at level 5, i.e.
-- 37,500 XP on their own curve. Traits and professions only shift that base
-- (Strong = +4, Weak = -5, Fire Officer = Fitness +3 ...).
ExperienceOrbMath.PassiveBaseLevel = 5

-- ---------- total XP required to reach a level ----------
local xpTotalCache = {}

function ExperienceOrbMath.TotalXpForLevel(perkObj, level)
    if not perkObj or not level or level <= 0 then return 0 end
    local key = tostring(perkObj) .. "|" .. tostring(level)
    local hit = xpTotalCache[key]
    if hit ~= nil then return hit end
    local v = -1
    local ok = pcall(function()
        local p = PerkFactory.getPerk(perkObj) or perkObj
        local t = p:getTotalXpForLevel(level)
        if type(t) == "number" then v = t end
    end)
    if not ok then v = -1 end
    xpTotalCache[key] = v
    return v
end

-- ---------- starting (free) levels per perk id ----------
-- Levels that were never earned by playing: profession boosts,
-- trait boosts and the passive levels of Fitness / Strength.
-- The XP of those levels must not be turned into orbs.
function ExperienceOrbMath.StartingLevels(playerObj)
    local free = {}
    if not playerObj then return free end

    local desc = call(playerObj, "getDescriptor")
    if desc then
        local profID = call(desc, "getCharacterProfession")
        if profID then
            local okp, profDef = pcall(function()
                return CharacterProfessionDefinition.getCharacterProfessionDefinition(profID)
            end)
            if okp and profDef then
                local okb, xpBoost = pcall(function()
                    local tb = profDef:getXpBoosts()
                    return tb and transformIntoKahluaTable(tb) or nil
                end)
                if okb and xpBoost then
                    for perk, lvl in pairs(xpBoost) do
                        free[tostring(perk)] = tonumber(tostring(lvl)) or 0
                    end
                end
            end
        end
    end

    local traits = call(playerObj, "getCharacterTraits")
    if traits then
        local known = call(traits, "getKnownTraits")
        if known then
            local n = call(known, "size") or 0
            for i = 0, n - 1 do
                local kin = call(known, "get", i)
                if kin then
                    local okd, tdef = pcall(function()
                        return CharacterTraitDefinition.getCharacterTraitDefinition(kin)
                    end)
                    if okd and tdef then
                        local okb2, tb = pcall(function()
                            local b = tdef:getXpBoosts()
                            return b and transformIntoKahluaTable(b) or nil
                        end)
                        if okb2 and tb then
                            for perk, lvl in pairs(tb) do
                                local p = tostring(perk)
                                free[p] = (free[p] or 0) + (tonumber(tostring(lvl)) or 0)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Passive perks (Strength / Fitness) start at BASE level 5 and every
    -- trait / profession XPBoost is only a bonus on top of that base
    -- (engine curves: totalXpForLevel(5) = 37500, (9) = 337500;
    --  data: Strong = XPBoosts Strength=4 -> level 9, Weak = -5 -> level 0).
    --
    -- The free level is therefore "5 + bonus" and NOT the current level:
    -- a player who raised Strength to 10 by playing must keep the XP of the
    -- levels he earned above the free part.
    local okMax, maxIdx = pcall(function() return Perks.getMaxIndex() end)
    if okMax and maxIdx then
        for i = 1, maxIdx - 1 do
            local okE, pe = pcall(function() return Perks.fromIndex(i) end)
            if okE and pe then
                local okF, perk = pcall(function() return PerkFactory.getPerk(pe) end)
                if okF and perk then
                    local okPass, isPass = pcall(function() return perk:isPassiv() end)
                    local parentType = nil
                    pcall(function() parentType = tostring(perk:getParent():getType()) end)
                    if okPass and isPass and parentType and parentType ~= "None" then
                        local pid = call(perk, "getId")
                        local boost = ExperienceOrbMath.FreeLevelFor(free, pid, perk) or 0
                        local level = ExperienceOrbMath.PassiveBaseLevel + boost
                        if level < 0 then level = 0 end
                        if level > 10 then level = 10 end
                        -- the free level can never be above the level the
                        -- character actually has: the trait / profession data
                        -- may over report (profession granted traits), and the
                        -- spawn baseline is the authoritative value anyway
                        local cur = call(playerObj, "getPerkLevel", perk)
                        if cur and cur > 0 and level > cur then level = cur end
                        local keys = {}
                        if pid then keys[#keys + 1] = tostring(pid) end
                        keys[#keys + 1] = tostring(perk)
                        for _, k in ipairs(keys) do
                            if k ~= "" and k ~= "nil" then
                                free[k] = level
                            end
                        end
                    end
                end
            end
        end
    end

    return free
end

-- Look a perk up in a free level map, trying every key form we may have
-- stored (perk id string, perk name, raw object tostring).
-- Negative boosts are returned as well (Weak = Strength -5).
function ExperienceOrbMath.FreeLevelFor(free, id, perkObj)
    if not free then return nil end
    local keys = { tostring(id) }
    if perkObj then
        local pid = call(perkObj, "getId")
        if pid then keys[#keys + 1] = tostring(pid) end
        keys[#keys + 1] = tostring(perkObj)
    end
    for _, k in ipairs(keys) do
        local v = tonumber(free[k])
        if v ~= nil then return v end
    end
    return nil
end

-- Diagnostic dump of the engine XP curve (used with Debug = true)
function ExperienceOrbMath.DumpCurve(perkIds, perkLookup, printFn)
    if not printFn then return end
    for _, id in ipairs(perkIds or {}) do
        local perkObj = perkLookup and perkLookup(id) or nil
        if perkObj then
            local parts = {}
            for n = 1, 10 do
                parts[#parts + 1] = n .. "=" .. tostring(ExperienceOrbMath.TotalXpForLevel(perkObj, n))
            end
            printFn("[ExperienceOrb] curve " .. id .. " totalXpForLevel: " .. table.concat(parts, " "))
        end
    end
end

-- ---------- raw XP of one perk (live object) ----------
function ExperienceOrbMath.RawXp(playerObj, perkObj)
    if not playerObj or not perkObj then return 0 end
    local xpSys = call(playerObj, "getXp")
    if not xpSys then return 0 end
    local v = nil
    local ok = pcall(function() v = xpSys:getXP(perkObj) end)
    if not ok or type(v) ~= "number" or v <= 0 then return 0 end
    return v
end
