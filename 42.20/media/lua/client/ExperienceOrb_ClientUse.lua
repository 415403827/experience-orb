-- ============================================================
-- Experience Orb () -  (B42)
--
--  Skill Recovery Journal 42.20.1 
--   Events.OnFillInventoryObjectContextMenu(playerID, context, items)
--    playerID getSpecificPlayer(playerID) 
--    ISInventoryPane.getActualItems(items) 
--    context:addOptionOnTop(label, item, onSelect, player) 
--  useOrb 
-- ============================================================
require "ISUI/ISInventoryPaneContextMenu"

local ORB_PREFIX = "Base.XpOrb_"

local function isOrbItem(item)
    if item == nil then return false end
    local okGet, m = pcall(function() return item.getFullType end)
    if not okGet or type(m) ~= "function" then return false end
    local ok, ft = pcall(function() return item:getFullType() end)
    if not ok then return false end
    if type(ft) ~= "string" then return false end
    return string.sub(ft, 1, #ORB_PREFIX) == ORB_PREFIX
end

local function onAbsorb(item, player)
    if not player or not item then return end
    local okID, itemID = pcall(function() return item:getID() end)
    if not okID or itemID == nil then return end
    pcall(function()
        sendClientCommand(player, "ExperienceOrb", "useOrb", { itemID = itemID })
    end)
end

local function doContextMenu(playerID, context, items)
    if context == nil then return end
    if items == nil then return end

    local actualItems = nil
    local okAI = pcall(function()
        actualItems = ISInventoryPane.getActualItems(items)
    end)
    if not okAI or actualItems == nil then actualItems = items end

    local player = nil
    local okP = pcall(function() player = getSpecificPlayer(playerID) end)
    if not okP or player == nil then return end

    for _, item in ipairs(actualItems) do
        if isOrbItem(item) then
            -- add the character name to the item itself: done on the client so
            -- the label follows this player's language (see ClientName.lua)
            if ExperienceOrb_ApplyOwnerName then
                pcall(function() ExperienceOrb_ApplyOwnerName(item) end)
            end
            local label = "Absorb XP Orb"
            local okT = pcall(function() label = getTextOrNull("ContextMenu_ExperienceOrb_Use") or "Absorb XP Orb" end)
            if not okT or label == nil or label == "" then label = "Absorb XP Orb" end
            -- show whose orb it is in the menu as well (multiplayer)
            local charName = ""
            if ExperienceOrbPerks and ExperienceOrbPerks.OrbCharName then
                pcall(function() charName = ExperienceOrbPerks.OrbCharName(item) end)
            end
            if charName == nil then charName = "" end
            if charName ~= "" and ExperienceOrbPerks.OwnerLabel then
                pcall(function() label = ExperienceOrbPerks.OwnerLabel(label, charName) end)
            end
            pcall(function()
                context:addOptionOnTop(label, item, onAbsorb, player)
            end)
            break
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(doContextMenu)

-- ============================================================
-- Absorb feedback (halo text).
-- The server only sends the numbers, the text is built here so it appears in
-- the player's own language.
--   kind "full"    -> the orb is emptied
--   kind "partial" -> only what fits up to level 10 was absorbed
--   kind "capped"  -> the skill is already at level 10, the orb stays untouched
-- ============================================================
local function localText(key, fallback, a, b)
    local txt = nil
    pcall(function()
        if a ~= nil then txt = getText(key, a, b) else txt = getText(key) end
    end)
    if type(txt) ~= "string" or txt == "" or string.find(txt, key, 1, true) then
        txt = fallback
        if a ~= nil then
            txt = string.gsub(txt, "%%1", tostring(a))
            if b ~= nil then txt = string.gsub(txt, "%%2", tostring(b)) end
        end
    end
    return txt
end

local function roundNum(v)
    v = tonumber(v) or 0
    return tostring(math.floor(v + 0.5))
end

local function onServerCommand(module, command, args)
    if module ~= "ExperienceOrb" then return end
    if command ~= "orbResult" then return end
    args = args or {}
    local kind = tostring(args.kind or "")
    local msg = nil
    if kind == "partial" then
        msg = localText("IGUI_ExperienceOrb_Partial", "Absorbed %1 XP - %2 XP left in the orb",
            roundNum(args.gained), roundNum(args.left))
    elseif kind == "capped" then
        msg = localText("IGUI_ExperienceOrb_Capped", "Already level 10 - %1 XP stays in the orb",
            roundNum(args.left))
    else
        msg = localText("IGUI_ExperienceOrb_Gained", "Absorbed %1 XP", roundNum(args.gained))
    end
    pcall(function()
        local player = nil
        pcall(function() player = getPlayer() end)
        if player == nil then
            pcall(function() player = getSpecificPlayer(0) end)
        end
        if player and HaloTextHelper and HaloTextHelper.addGoodText then
            HaloTextHelper.addGoodText(player, msg)
        end
    end)
end

Events.OnServerCommand.Add(onServerCommand)
