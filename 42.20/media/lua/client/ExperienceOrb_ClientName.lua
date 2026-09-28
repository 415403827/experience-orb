-- ============================================================
-- Experience Orb - client side owner annotation (Build 42)
--
-- The orb keeps its translated item name (Translate/<LANG>/ItemName.json),
-- so every player reads the skill name in their own language. The character
-- name is added locally, on the client, using the pattern from
-- Translate/<LANG>/IG_UI.json, for example:
--
--     EN  "Strength XP Orb (Shimakaze)"
--     DE  "Staerke-Erfahrungskugel (Shimakaze)"
--
-- Doing it on the client (and not on the server with item:setName) is what
-- keeps the name localized: a name written by the server would be frozen in
-- the server's language for every player.
-- ============================================================

local ORB_PREFIX = "Base.XpOrb_"

local function isOrbItem(item)
    if item == nil then return false end
    local ok, ft = pcall(function() return item:getFullType() end)
    if not ok or type(ft) ~= "string" then return false end
    return string.sub(ft, 1, #ORB_PREFIX) == ORB_PREFIX
end

-- returns true when the item name was (re)written
function ExperienceOrb_ApplyOwnerName(item)
    if not item then return false end
    if not ExperienceOrbPerks then return false end

    local charName = ""
    pcall(function() charName = ExperienceOrbPerks.OrbCharName(item) end)

    local base = ""
    pcall(function() base = ExperienceOrbPerks.OrbBaseName(item) end)
    if base == nil or base == "" then return false end

    -- Build the label from the clean base name + the owner, and write it only
    -- when it differs: the server already named the orb at generation time (in
    -- the server's language), so this pass mainly "upgrades" that name to the
    -- local language. Comparing before writing keeps it idempotent - the owner
    -- part can never be appended twice.
    local label = base
    pcall(function() label = ExperienceOrbPerks.OrbLabel(item, base, charName) end)
    if label == nil or label == "" then return false end

    local current = nil
    pcall(function() current = item:getDisplayName() end)
    if current == label then return false end

    local ok = pcall(function()
        item:setName(label)
        item:setCustomName(true)
    end)
    return ok
end

-- keep the orbs the player carries labelled (the loot window and the context
-- menu are handled on demand, see ExperienceOrb_ClientUse.lua)
local tick = 0
Events.OnTick.Add(function()
    tick = tick + 1
    if tick % 60 ~= 0 then return end
    local player = nil
    pcall(function() player = getPlayer() end)
    if player == nil then
        pcall(function() player = getSpecificPlayer(0) end)
    end
    if player == nil then return end
    local inv = nil
    pcall(function() inv = player:getInventory() end)
    if inv == nil then return end
    local items = nil
    pcall(function() items = inv:getItems() end)
    if items == nil then return end
    local n = 0
    pcall(function() n = items:size() end)
    for i = 0, n - 1 do
        local it = nil
        pcall(function() it = items:get(i) end)
        if it and isOrbItem(it) then
            ExperienceOrb_ApplyOwnerName(it)
        end
    end
end)
