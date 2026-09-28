# ============================================================
# Experience Orb - translation generator + validator (Build 42.20)
#
# Builds 42.20/media/lua/shared/Translate/<LANG>/{ItemName,IG_UI,ContextMenu}.json
# for every language listed in tools/translate_data.json, using the
# *official* perk names shipped with the game so the wording always
# matches the skill names the player sees in the skill panel.
#
# Conventions (verified against vanilla 42.20 and against Skill Recovery
# Journal, a widely used B42 mod):
#   * one folder per language code, codes copied from vanilla
#     (media/lua/shared/Translate/<CODE>)
#   * a key lives in the file of its group, because the engine routes a
#     lookup by key prefix into a dedicated map:
#        item names    -> ItemName.json       ("Base.XpOrb_<perk>")
#        IGUI_*        -> IG_UI.json
#        ContextMenu_* -> ContextMenu.json
#   * encoding UTF-8 WITHOUT BOM. Vanilla is UTF-8 no BOM + LF, SRJ is
#     UTF-8 no BOM + CRLF; both load fine. A BOM, UTF-16 or GBK breaks
#     the JSON loader and every key then shows up as raw text.
#   * the engine falls back to EN for keys missing in the player's
#     language, so shipping a subset of languages is safe.
#
# This script must stay ASCII-only: Windows PowerShell 5.1 reads a
# BOM-less script with the system code page and would mangle non-ASCII
# text. All translated strings live in tools/translate_data.json and are
# read explicitly as UTF-8.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\gen_translate.ps1
#   ... -VanillaRoot "G:\SteamLibrary\steamapps\common\ProjectZomboid"
# ============================================================
param(
    [string]$VanillaRoot = "",
    [string]$ModRoot = ""
)

$ErrorActionPreference = "Stop"

if ($ModRoot -eq "") {
    $ModRoot = Split-Path -Parent $PSScriptRoot
}
$translateRoot = Join-Path $ModRoot "42.20\media\lua\shared\Translate"
$dataPath = Join-Path $PSScriptRoot "translate_data.json"

if ($VanillaRoot -eq "") {
    $candidates = @(
        "G:\SteamLibrary\steamapps\common\ProjectZomboid",
        "F:\SteamLibrary\steamapps\common\ProjectZomboid",
        "D:\SteamLibrary\steamapps\common\ProjectZomboid",
        "E:\SteamLibrary\steamapps\common\ProjectZomboid",
        "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "media\lua\shared\Translate\EN\IG_UI.json")) { $VanillaRoot = $c; break }
    }
}
if ($VanillaRoot -eq "") { throw "Project Zomboid install not found - pass -VanillaRoot" }

$vanillaTranslate = Join-Path $VanillaRoot "media\lua\shared\Translate"
Write-Host "vanilla : $vanillaTranslate"
Write-Host "mod     : $translateRoot"
Write-Host "data    : $dataPath"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

function Read-Utf8([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function ConvertTo-JsonLiteral([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append([char]34)
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq [char]34) { [void]$sb.Append('\"') }
        elseif ($ch -eq [char]92) { [void]$sb.Append('\\') }
        elseif ($code -eq 10) { [void]$sb.Append('\n') }
        elseif ($code -eq 13) { [void]$sb.Append('\r') }
        elseif ($code -eq 9) { [void]$sb.Append('\t') }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append([char]34)
    return $sb.ToString()
}

function Write-JsonFile([string]$path, $pairs) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # OrderedDictionary entries (PSObject.Properties would return the
    # dictionary's own members: Count, Keys, Values, ...)
    $entries = @()
    if ($pairs -is [System.Collections.IDictionary]) {
        foreach ($k in $pairs.Keys) {
            $entries += [pscustomobject]@{ K = [string]$k; V = [string]$pairs[$k] }
        }
    } else {
        foreach ($p in $pairs.PSObject.Properties) {
            $entries += [pscustomobject]@{ K = [string]$p.Name; V = [string]$p.Value }
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("{`n")
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $comma = if ($i -lt $entries.Count - 1) { "," } else { "" }
        $line = "    " + (ConvertTo-JsonLiteral $entries[$i].K) + ": " + (ConvertTo-JsonLiteral $entries[$i].V) + $comma
        [void]$sb.Append($line + "`n")
    }
    [void]$sb.Append("}`n")
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8NoBom)
}

# ---------- load data ----------
$data = (Read-Utf8 $dataPath) | ConvertFrom-Json
$perkIds = @($data.perks.PSObject.Properties | ForEach-Object { $_.Name })
$langCodes = @($data.languages.PSObject.Properties | ForEach-Object { $_.Name })

function Get-OfficialPerkNames([string]$lang) {
    # official perk names for one language, per key falling back to EN
    $names = @{}
    foreach ($src in @($lang, "EN")) {
        if ($names.Count -eq $perkIds.Count) { break }
        $raw = Read-Utf8 (Join-Path $vanillaTranslate "$src\IG_UI.json")
        if (-not $raw) { continue }
        foreach ($id in $perkIds) {
            if ($names.ContainsKey($id)) { continue }
            $key = [string]$data.perks.$id
            $m = [regex]::Match($raw, '"IGUI_perks_' + [regex]::Escape($key) + '"\s*:\s*"((?:[^"\\]|\\.)*)"')
            if ($m.Success) { $names[$id] = $m.Groups[1].Value }
        }
    }
    return $names
}

# ---------- generate ----------
$report = @()
foreach ($lang in $langCodes) {
    $cfg = $data.languages.$lang
    $names = Get-OfficialPerkNames $lang

    $itemNames = [ordered]@{}
    $fallback = @()
    foreach ($id in $perkIds) {
        if ($names.ContainsKey($id)) {
            $perkName = $names[$id]
        } else {
            $perkName = [string]$data.perks.$id
            $fallback += $id
        }
        $itemNames["Base.XpOrb_$id"] = $cfg.item.Replace("%1", $perkName)
    }
    $igui = [ordered]@{
        "IGUI_ExperienceOrb_OwnerName" = $cfg.owner
        "IGUI_ExperienceOrb_Capacity"  = $cfg.capacity
        "IGUI_ExperienceOrb_Gained"    = $cfg.gained
        "IGUI_ExperienceOrb_Partial"   = $cfg.partial
        "IGUI_ExperienceOrb_Capped"    = $cfg.capped
    }
    $menu = [ordered]@{ "ContextMenu_ExperienceOrb_Use" = $cfg.use }

    $dir = Join-Path $translateRoot $lang
    Write-JsonFile (Join-Path $dir "ItemName.json") $itemNames
    Write-JsonFile (Join-Path $dir "IG_UI.json") $igui
    Write-JsonFile (Join-Path $dir "ContextMenu.json") $menu

    $report += [pscustomobject]@{
        Lang     = $lang
        Keys     = $itemNames.Count
        Fallback = if ($fallback.Count -gt 0) { ($fallback -join ",") } else { "-" }
        Woodwork = $itemNames["Base.XpOrb_Woodwork"]
        Strength = $itemNames["Base.XpOrb_Strength"]
    }
}

Write-Host ""
Write-Host "=== generated ==="
$report | Format-Table -AutoSize | Out-String -Width 220 | Write-Host

# ---------- validate ----------
$problems = @()
foreach ($lang in $langCodes) {
    $dir = Join-Path $translateRoot $lang
    foreach ($file in @("ItemName.json", "IG_UI.json", "ContextMenu.json")) {
        $p = Join-Path $dir $file
        if (-not (Test-Path $p)) { $problems += "MISSING $lang/$file"; continue }
        $bytes = [System.IO.File]::ReadAllBytes($p)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $problems += "UTF-8 BOM present in $lang/$file"
        }
        try { [void]$utf8Strict.GetString($bytes) } catch { $problems += "not valid UTF-8: $lang/$file" }
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($text -match "[\x00-\x08\x0B\x0C\x0E-\x1F]") { $problems += "control character in $lang/$file" }
        try {
            $obj = $text | ConvertFrom-Json
            $count = @($obj.PSObject.Properties).Count
            if ($file -eq "ItemName.json" -and $count -ne $perkIds.Count) {
                $problems += "expected $($perkIds.Count) keys, found $count in $lang/$file"
            }
        } catch {
            $problems += "invalid JSON $lang/$file : $($_.Exception.Message)"
        }
    }
}

Write-Host "=== validation ==="
if ($problems.Count -eq 0) {
    Write-Host ("  OK - {0} languages x 3 files, UTF-8 without BOM, all keys present" -f $langCodes.Count)
} else {
    $problems | ForEach-Object { Write-Host ("  PROBLEM: " + $_) }
    exit 1
}
Write-Host "  ItemName.json     -> Base.XpOrb_* ($($perkIds.Count) keys)"
Write-Host "  IG_UI.json        -> IGUI_ExperienceOrb_OwnerName / _Capacity / _Gained / _Partial / _Capped"
Write-Host "  ContextMenu.json  -> ContextMenu_ExperienceOrb_Use"
