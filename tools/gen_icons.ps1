# Experience Orb icon generator (鑷粯銆佹棤鐗堟潈)
# 鐢ㄦ硶: powershell -File gen_icons.ps1 <root1> [root2 ...]
# 姣忎釜 root 涓嬭緭鍑?WorldItems/XpOrb_<perk>.png 涓?XpOrb_<perk>.png锛?4x64锛?param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Roots)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not $Roots) { Write-Output 'usage: gen_icons.ps1 <textures-root> [...]'; exit 1 }

# 7 澶у垎绫伙細閰嶈壊 + 鎶€鑳斤紙椤哄簭鍗崇汗鏍峰簭鍙凤級
$categories = @(
    @{ color = @(232,105,55);  skills = @('Fitness','Strength') },
    @{ color = @(160,80,200);  skills = @('Aiming','Reloading') },
    @{ color = @(96,120,175);  skills = @('Axe','Blunt','SmallBlunt','LongBlade','SmallBlade','Spear','Maintenance') },
    @{ color = @(0,170,150);   skills = @('Sprinting','Lightfoot','Nimble','Sneak') },
    @{ color = @(110,180,70);  skills = @('Fishing','Trapping','PlantScavenging','Tracking','Butchering') },
    @{ color = @(216,170,50);  skills = @('Farming','Husbandry') },
    @{ color = @(55,170,225);  skills = @('Woodwork','Cooking','Doctor','Electricity','MetalWelding','Mechanics','Tailoring','FlintKnapping','Masonry','Pottery','Carving','Blacksmith','Glassmaking') }
)

# 鍑犱綍绾规牱缁樺埗
function Draw-Glyph($g, $cx, $cy, $u, $patId, $pen, $brush) {
    switch ($patId) {
        0 { }
        1 { $g.FillEllipse($brush, $cx-$u*0.9, $cy-$u*0.9, $u*1.8, $u*1.8) }
        2 { $g.DrawEllipse($pen, $cx-$u*1.5, $cy-$u*1.5, $u*3.0, $u*3.0); $g.FillEllipse($brush, $cx-$u*0.7, $cy-$u*0.7, $u*1.4, $u*1.4) }
        3 { $g.DrawLine($pen, $cx-$u*2.2, $cy, $cx+$u*2.2, $cy) }
        4 { $g.DrawLine($pen, $cx, $cy-$u*2.2, $cx, $cy+$u*2.2) }
        5 { $g.DrawLine($pen, $cx-$u*2.0, $cy-$u*2.0, $cx+$u*2.0, $cy+$u*2.0); $g.DrawLine($pen, $cx-$u*2.0, $cy+$u*2.0, $cx+$u*2.0, $cy-$u*2.0) }
        6 { $g.DrawLine($pen, $cx-$u*2.0, $cy, $cx+$u*2.0, $cy); $g.DrawLine($pen, $cx, $cy-$u*2.0, $cx, $cy+$u*2.0) }
        7 { $g.DrawLine($pen, $cx-$u*2.0, $cy-$u*1.2, $cx+$u*2.0, $cy+$u*1.2) }
        8 { $g.DrawLine($pen, $cx-$u*2.0, $cy+$u*1.2, $cx+$u*2.0, $cy-$u*1.2) }
        9 { $g.DrawEllipse($pen, $cx-$u*2.0, $cy-$u*2.0, $u*4.0, $u*4.0) }
        10 { $g.FillEllipse($brush, $cx-$u*0.9, $cy-$u*2.4, $u*1.8, $u*1.8); $g.FillEllipse($brush, $cx-$u*0.9, $cy+$u*0.6, $u*1.8, $u*1.8) }
        11 { $g.FillEllipse($brush, $cx-$u*2.4, $cy-$u*0.9, $u*1.8, $u*1.8); $g.FillEllipse($brush, $cx+$u*0.6, $cy-$u*0.9, $u*1.8, $u*1.8) }
        12 { for ($ang = 0; $ang -lt 3; $ang++) { $a = $ang * 120 * [Math]::PI / 180; $g.DrawLine($pen, $cx, $cy, $cx + [Math]::Cos($a) * $u*2.2, $cy + [Math]::Sin($a) * $u*2.2) } }
        13 { $g.DrawEllipse($pen, $cx-$u*1.3, $cy-$u*1.3, $u*2.6, $u*2.6) }
        14 { $g.DrawLine($pen, $cx-$u*2.0, $cy, $cx, $cy-$u*2.0); $g.DrawLine($pen, $cx, $cy-$u*2.0, $cx+$u*2.0, $cy); $g.DrawLine($pen, $cx+$u*2.0, $cy, $cx, $cy+$u*2.0); $g.DrawLine($pen, $cx, $cy+$u*2.0, $cx-$u*2.0, $cy) }
        15 { $g.DrawEllipse($pen, $cx-$u*1.5, $cy-$u*1.5, $u*3.0, $u*3.0); $g.DrawLine($pen, $cx-$u*2.0, $cy, $cx+$u*2.0, $cy) }
        default { $g.FillEllipse($brush, $cx-$u*0.9, $cy-$u*0.9, $u*1.8, $u*1.8) }
    }
}

$count = 0
foreach ($cat in $categories) {
    $rgb = $cat.color
    $patId = 0
    foreach ($skill in $cat.skills) {
        $S = 64
        $bmp = New-Object System.Drawing.Bitmap $S, $S
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)

        $cMain  = [System.Drawing.Color]::FromArgb(255, $rgb[0], $rgb[1], $rgb[2])
        $cDark  = [System.Drawing.Color]::FromArgb(255, [int]($rgb[0]*0.55), [int]($rgb[1]*0.55), [int]($rgb[2]*0.55))
        $cLite  = [System.Drawing.Color]::FromArgb(255, [Math]::Min(255,$rgb[0]+70), [Math]::Min(255,$rgb[1]+70), [Math]::Min(255,$rgb[2]+70))
        $cGlyph = [System.Drawing.Color]::FromArgb(230, 12, 12, 22)

        $bDark  = New-Object System.Drawing.SolidBrush $cDark
        $bMain  = New-Object System.Drawing.SolidBrush $cMain
        $bLite  = New-Object System.Drawing.SolidBrush $cLite
        $bGloss = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(140,255,255,255))
        $bGlyph = New-Object System.Drawing.SolidBrush $cGlyph
        $pGlyph = New-Object System.Drawing.Pen $cGlyph, 4.0
        $pGlyph.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pGlyph.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

        # 澶栧湀鏆楄竟 + 涓讳綋 + 涓婇儴鎻愪寒 + 楂樺厜
        $g.FillEllipse($bDark, 3, 3, 58, 58)
        $g.FillEllipse($bMain, 8, 8, 48, 48)
        $g.FillEllipse($bLite, 8, 8, 48, 18)
        # 鐞冨績绾规牱
        Draw-Glyph $g 32 36 ($S/11) $patId $pGlyph $bGlyph
        # 宸︿笂楂樺厜
        $g.FillEllipse($bGloss, 13, 12, 16, 11)

        foreach ($root in $Roots) {
            foreach ($sub in @('WorldItems', '')) {
                $dir = if ($sub) { Join-Path $root $sub } else { $root }
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                $path = Join-Path $dir ("XpOrb_" + $skill + ".png")
                $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            }
        }

        $g.Dispose(); $bmp.Dispose()
        $bDark.Dispose(); $bMain.Dispose(); $bLite.Dispose(); $bGloss.Dispose(); $bGlyph.Dispose(); $pGlyph.Dispose()
        $count++
        $patId = ($patId + 1) % 16
    }
}
Write-Output ("icons written: " + $count)

