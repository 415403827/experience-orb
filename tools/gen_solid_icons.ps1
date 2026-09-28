# Experience Orb - 纯色球图标（仅区分大类）
# 用法: powershell -File gen_solid_icons.ps1 <media-root> [<media-root> ...]
# 每个 media-root 下输出 textures/、textures/WorldItems/、inventory/ 三处的
#   XpOrb_<perk>.png 与 Item_XpOrb_<perk>.png（64x64，透明底，按分类配色）
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Roots)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not $Roots) { Write-Output 'usage: gen_solid_icons.ps1 <media-root> [...]'; exit 1 }

$categories = @(
    @{ color = @(232,105,55);  skills = @('Fitness','Strength') },
    @{ color = @(160,80,200);  skills = @('Aiming','Reloading') },
    @{ color = @(96,120,175);  skills = @('Axe','Blunt','SmallBlunt','LongBlade','SmallBlade','Spear','Maintenance') },
    @{ color = @(0,170,150);   skills = @('Sprinting','Lightfoot','Nimble','Sneak') },
    @{ color = @(110,180,70);  skills = @('Fishing','Trapping','PlantScavenging','Tracking','Butchering') },
    @{ color = @(216,170,50);  skills = @('Farming','Husbandry') },
    @{ color = @(55,170,225);  skills = @('Woodwork','Cooking','Doctor','Electricity','MetalWelding','Mechanics','Tailoring','FlintKnapping','Masonry','Pottery','Carving','Blacksmith','Glassmaking') }
)

function New-SolidOrb($path, $rgb) {
    $S = 64
    $bmp = New-Object System.Drawing.Bitmap $S, $S
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $cMain = [System.Drawing.Color]::FromArgb(255, $rgb[0], $rgb[1], $rgb[2])
    $cDark = [System.Drawing.Color]::FromArgb(255, [int]($rgb[0]*0.55), [int]($rgb[1]*0.55), [int]($rgb[2]*0.55))
    $cLite = [System.Drawing.Color]::FromArgb(255, [Math]::Min(255,$rgb[0]+60), [Math]::Min(255,$rgb[1]+60), [Math]::Min(255,$rgb[2]+60))
    $cGloss = [System.Drawing.Color]::FromArgb(150, 255, 255, 255)

    $bDark  = New-Object System.Drawing.SolidBrush $cDark
    $bMain  = New-Object System.Drawing.SolidBrush $cMain
    $bLite  = New-Object System.Drawing.SolidBrush $cLite
    $bGloss = New-Object System.Drawing.SolidBrush $cGloss

    # 暗边 -> 主体 -> 上部提亮 -> 高光
    $g.FillEllipse($bDark, 3, 3, 58, 58)
    $g.FillEllipse($bMain, 8, 8, 48, 48)
    $g.FillEllipse($bLite,  8, 8, 48, 20)
    $g.FillEllipse($bGloss, 12, 11, 17, 12)

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose(); $bmp.Dispose()
    $bDark.Dispose(); $bMain.Dispose(); $bLite.Dispose(); $bGloss.Dispose()
}

$count = 0
foreach ($root in $Roots) {
    foreach ($cat in $categories) {
        foreach ($skill in $cat.skills) {
            foreach ($sub in @('textures','textures\WorldItems','inventory')) {
                $d = $root + '\' + $sub
                New-Item -ItemType Directory -Path $d -Force | Out-Null
                $name = 'XpOrb_' + $skill + '.png'
                New-SolidOrb (Join-Path $d $name) $cat.color
                New-SolidOrb (Join-Path $d ('Item_' + $name)) $cat.color
            }
            $count++
        }
    }
}
Write-Output ("solid-orb icons written: " + $count + " per root, x3 dirs x2 names")
