-- ============================================================
-- Experience Orb - configuration file (Build 42.20)
--
-- The value below is applied by the server.
-- After editing this file, restart the server (or reload the save).
--
-- NOTE: keep this file ASCII-only. Non-ASCII bytes crash the
--       LuaJ lexer on some dedicated servers.
-- ============================================================
ExperienceOrbConfig = {

    -- Ratio of the recoverable XP that is placed into the orbs.
    -- Range 0.01 ~ 1.0  (1% ~ 100%). Values outside are clamped.
    RecoveryRatio = 1.0,

    -- true  = XP gained from TV / VHS (the media channel) is NOT placed
    --         into orbs. In B42 both share the same channel, so they are
    --         excluded together.
    -- false = media XP is counted as normal XP.
    ExcludeMediaXp = true,

    -- true  = levels granted by traits / profession (and the passive
    --         levels of Fitness / Strength at spawn) are NOT placed into
    --         orbs. Only XP actually earned by the player counts.
    ExcludeTraitAndProfessionXp = true,

    -- Who may absorb (right click -> use) an orb:
    -- false = only the new character of the dead player (same account)
    -- true  = any player may absorb any orb
    AllowAnyoneToAbsorb = false,

    -- Skill group switches:
    -- craft = crafting/survival, combat = weapons,
    -- movement = movement, physical = fitness/strength
    EnabledSkillGroups = {
        craft = true,
        combat = true,
        movement = true,
        physical = true,
    },

    -- Extra per-skill blacklist, keyed by the skill id,
    -- for example "Strength" or "Fitness".
    DisabledSkills = {
        -- Strength = true,
        -- Fitness = true,
    },

    -- When a character dies, the orbs drop on the ground within this
    -- radius (in squares) around the corpse.
    DropSpreadRadius = 1,

    -- Debug output (detailed log lines on the server console).
    Debug = true,
}
