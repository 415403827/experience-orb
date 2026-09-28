-- ============================================================
-- Experience Orb () - shared perk catalog (B42)
-- perk id  Perks.<id> 
-- ============================================================
ExperienceOrbPerks = ExperienceOrbPerks or {}

-- craft /, combat , movement , physical 
ExperienceOrbPerks.Categories = {
    craft = {
        "Woodwork", "Cooking", "Farming", "Doctor", "Electricity",
        "MetalWelding", "Mechanics", "Tailoring", "Fishing", "Trapping",
        "PlantScavenging", "FlintKnapping", "Masonry", "Pottery", "Carving",
        "Husbandry", "Tracking", "Blacksmith", "Butchering", "Glassmaking",
    },
    combat = {
        "Aiming", "Reloading", "LongBlade", "Maintenance",
        "Axe", "Blunt", "Spear", "SmallBlade", "SmallBlunt",
    },
    movement = {
        "Sprinting", "Lightfoot", "Nimble", "Sneak",
    },
    physical = {
        "Fitness", "Strength",
    },
}

--  perk idXpOrb_<id>
do
    local all = {}
    for _, list in pairs(ExperienceOrbPerks.Categories) do
        for _, id in ipairs(list) do
            all[#all + 1] = id
        end
    end
    ExperienceOrbPerks.AllIds = all
end

-- perk id -> 
function ExperienceOrbPerks.ItemTypeFor(id)
    return "XpOrb_" .. id
end

-- perk id -> Perks.<id>  id  nil
ExperienceOrbPerks.PerkCache = ExperienceOrbPerks.PerkCache or {}
function ExperienceOrbPerks.PerkObject(id)
    if ExperienceOrbPerks.PerkCache[id] == nil then
        local per = nil
        -- Perks is a Java table: reading an unknown key is wrapped in
        -- pcall so a missing perk can never abort the caller.
        pcall(function() per = Perks[id] end)
        ExperienceOrbPerks.PerkCache[id] = per or false
    end
    local per = ExperienceOrbPerks.PerkCache[id]
    return per and per or nil
end

-- perk id ->  "Base.XpOrb_<id>"
function ExperienceOrbPerks.FullTypeFor(id)
    return "Base." .. ExperienceOrbPerks.ItemTypeFor(id)
end

-- "Strength XP Orb (Shimakaze)" - the pattern comes from the translation
-- key IGUI_ExperienceOrb_OwnerName (file Translate/<LANG>/IG_UI.json), so the
-- label follows the language of whoever builds it.
-- It is built on the CLIENT, so every player sees the owner name in their own
-- language and the item name itself stays translated for all players.
function ExperienceOrbPerks.OwnerLabel(baseName, charName)
    baseName = tostring(baseName or "")
    charName = tostring(charName or "")
    if charName == "" or charName == "nil" then return baseName end
    local txt = nil
    pcall(function()
        txt = getText("IGUI_ExperienceOrb_OwnerName", baseName, charName)
    end)
    if type(txt) ~= "string" or txt == "" or string.find(txt, "IGUI_ExperienceOrb_OwnerName", 1, true) then
        txt = baseName .. " (" .. charName .. ")"
    end
    return txt
end

-- Localized display name of an orb item ("Strength XP Orb" / the CN text from
-- Translate/<LANG>/ItemName.json).
--
-- IMPORTANT: never read it from the item that is being labelled: its own display
-- name may already carry our "(owner)" suffix, and wrapping that again would
-- stack the suffix on every pass ("... (Shimakaze)(Shimakaze)").
-- The base name therefore comes from a brand new instance of the same type
-- (instanceItem is a vanilla helper) and is cached per full type - it can only
-- change when the game language changes, which needs a restart anyway.
local orbBaseNameCache = {}

function ExperienceOrbPerks.OrbBaseName(item)
    if not item then return "" end
    local ft = nil
    pcall(function() ft = item:getFullType() end)
    if type(ft) ~= "string" or ft == "" then return "" end

    local cached = orbBaseNameCache[ft]
    if cached then return cached end

    local name = nil
    -- 1) display name of a fresh instance of the same item type
    pcall(function()
        if instanceItem then
            local fresh = instanceItem(ft)
            if fresh then
                local d = fresh:getDisplayName()
                if type(d) == "string" and d ~= "" and d ~= ft then name = d end
            end
        end
    end)
    -- 2) translation table (if this key resolves in this build)
    if not name then
        pcall(function()
            local t = getText(ft)
            if type(t) == "string" and t ~= "" and t ~= ft then name = t end
        end)
    end
    -- 3) last resort: the raw full type - deliberately NOT the live item name
    if not name then name = ft end

    orbBaseNameCache[ft] = name
    return name
end

-- Full label of an orb: "<skill orb> (<owner>)", for example
-- "Fitness XP Orb (Shimakaze)" - the owner part is the ACCOUNT NAME, added by
-- the client in its own language (see ExperienceOrb_ClientName.lua).
-- The remaining content / capacity is deliberately NOT part of the name.
function ExperienceOrbPerks.OrbLabel(item, baseName, charName)
    baseName = tostring(baseName or "")
    local label = baseName
    charName = tostring(charName or "")
    if charName ~= "" and charName ~= "nil" then
        label = ExperienceOrbPerks.OwnerLabel(label, charName)
    end
    return label
end

-- character name stored on an orb (ModData), "" when unknown
function ExperienceOrbPerks.OrbCharName(item)
    if not item then return "" end
    local md = nil
    pcall(function() md = item:getModData() end)
    if not md then return "" end
    local c = md.char
    if c == nil then c = md.charName end
    if c == nil then return "" end
    return tostring(c)
end

-- Best available human readable name of a player.
-- In multiplayer the server side descriptor has no forename / surname, so the
-- account name (getUsername) is used as a fallback.
function ExperienceOrbPerks.PlayerName(playerObj)
    if not playerObj then return "" end
    local name = ""
    pcall(function()
        local d = playerObj:getDescriptor()
        if d then
            local full = d:getFullName()
            if full and tostring(full) ~= "" then
                name = tostring(full)
            else
                local fo = tostring(d:getForename() or "")
                local su = tostring(d:getSurname() or "")
                local joined = fo .. " " .. su
                if (joined:gsub("%s", "")) ~= "" then name = joined end
            end
        end
    end)
    if name == "" then
        pcall(function()
            local u = playerObj:getUsername()
            if u and tostring(u) ~= "" then name = tostring(u) end
        end)
    end
    if name == nil then name = "" end
    return name
end

-- Steam id as an exact digit string (the engine hands it over as a double,
-- which would print as 7.656119814527621E16) plus the account name.
function ExperienceOrbPerks.PlayerIdentity(playerObj)
    local out = { steam = "", user = "" }
    if not playerObj then return out end
    pcall(function()
        local s = playerObj:getSteamID()
        if s and tonumber(s) and tonumber(s) > 0 then
            out.steam = string.format("%.0f", tonumber(s))
        end
    end)
    pcall(function()
        local u = playerObj:getUsername()
        if u and tostring(u) ~= "" then out.user = tostring(u) end
    end)
    return out
end

-- two owner keys match? (numeric compare, so ids stored by an older version of
-- the mod - printed as 7.656119814527621E16 - still match)
function ExperienceOrbPerks.SameOwner(a, b)
    a = tostring(a or "")
    b = tostring(b or "")
    if a == "" or b == "" then return false end
    if a == b then return true end
    local na, nb = tonumber(a), tonumber(b)
    if na and nb and na == nb then return true end
    return false
end
