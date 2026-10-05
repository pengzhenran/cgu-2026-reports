# 生成网站图标与分享卡片图（Windows PowerShell 5.1 / System.Drawing）
#   favicon.ico        16/32/48 三尺寸（PNG 内嵌）
#   icon-32.png        浏览器标签页
#   icon-192/512.png   Android / PWA 主屏图标
#   apple-touch-icon.png  iOS 添加到主屏
#   og-image.png       1200x630 分享卡片封面（微信 / QQ / 微博 / Twitter 都读它）
# 用法：powershell -ExecutionPolicy Bypass -File make_icons.ps1
# 改完配色或文字后重跑本脚本即可，图标是纯生成物，不需要手工修图。

param([string]$OutDir = $PSScriptRoot)

Add-Type -AssemblyName System.Drawing

$Blue      = [System.Drawing.Color]::FromArgb(31, 78, 121)     # #1f4e79 站点主色
$BlueLight = [System.Drawing.Color]::FromArgb(47, 107, 163)    # #2f6ba3 渐变用
$Sky       = [System.Drawing.Color]::FromArgb(169, 201, 232)   # #a9c9e8
$Pale      = [System.Drawing.Color]::FromArgb(207, 224, 240)   # #cfe0f0
$White     = [System.Drawing.Color]::White
$Latin     = 'Microsoft YaHei UI'                              # CGU / 2026 用
$CJK       = 'Microsoft YaHei UI'                              # 中文用

function New-RoundedPath([int]$w, [int]$h, [int]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc(0, 0, $d, $d, 180, 90)
  $p.AddArc($w - $d, 0, $d, $d, 270, 90)
  $p.AddArc($w - $d, $h - $d, $d, $d, 0, 90)
  $p.AddArc(0, $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Get-FittedFont($g, [string]$text, [string]$family, $style, [int]$startPx, [int]$maxW) {
  $px = $startPx
  while ($px -gt 8) {
    $f = New-Object System.Drawing.Font($family, $px, $style, [System.Drawing.GraphicsUnit]::Pixel)
    if ($g.MeasureString($text, $f).Width -le $maxW) { return $f }
    $f.Dispose()
    $px -= 2
  }
  return New-Object System.Drawing.Font($family, 8, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

function New-IconBitmap([int]$size, [bool]$withYear) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.Clear([System.Drawing.Color]::Transparent)

  # 圆角方块底（留 8% 内边距，这样当 maskable 图标被裁成圆形也不会切到字）
  $pad = [int]($size * 0.08)
  $side = $size - 2 * $pad
  $radius = [int]($side * 0.22)
  $path = New-RoundedPath $side $side $radius
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate($pad, $pad)
  $path.Transform($m)
  $gradRect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($gradRect, $Blue, $BlueLight, 55.0)
  $g.FillPath($bg, $path)

  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  # 主体文字 CGU
  $cguPx = if ($withYear) { [int]($size * 0.34) } else { [int]($size * 0.40) }
  $cguFont = Get-FittedFont $g 'CGU' $Latin ([System.Drawing.FontStyle]::Bold) $cguPx ([int]($side * 0.80))
  $whiteBrush = New-Object System.Drawing.SolidBrush($White)
  $cguY = if ($withYear) { [int]($size * 0.40) } else { [int]($size * 0.50) }
  $r1 = New-Object System.Drawing.RectangleF(0, ($cguY - $size * 0.25), $size, ($size * 0.5))
  $g.DrawString('CGU', $cguFont, $whiteBrush, $r1, $sf)

  if ($withYear) {
    # 分隔线 + 年份
    $lineW = [int]($side * 0.42)
    $linePen = New-Object System.Drawing.Pen($Sky, [float]([Math]::Max(1.5, $size * 0.012)))
    $ly = [float]($size * 0.615)
    $g.DrawLine($linePen, [float](($size - $lineW) / 2), $ly, [float](($size + $lineW) / 2), $ly)
    $yearFont = New-Object System.Drawing.Font($Latin, [int]($size * 0.135), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $skyBrush = New-Object System.Drawing.SolidBrush($Sky)
    $r2 = New-Object System.Drawing.RectangleF(0, ($ly + $size * 0.01), $size, ($size * 0.25))
    $g.DrawString('2026', $yearFont, $skyBrush, $r2, $sf)
    $yearFont.Dispose(); $skyBrush.Dispose(); $linePen.Dispose()
  }

  $cguFont.Dispose(); $whiteBrush.Dispose(); $bg.Dispose(); $path.Dispose(); $m.Dispose()
  $g.Dispose()
  return $bmp
}

function Save-Png($bmp, [string]$path) {
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# ---- 分享卡片封面 1200x630 -------------------------------------------------
# 注意：关键文字都放在中间 630px 宽的区域内，这样微信把图裁成正方形也不会切掉标题。
function New-OgImage([int]$w = 1200, [int]$h = 630) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $Blue, $BlueLight, 20.0)
  $g.FillRectangle($bg, $rect)

  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  $safeW = 1000   # 正文最大宽度（居中，正方形裁切也安全）
  $cx = $w / 2

  $whiteBrush = New-Object System.Drawing.SolidBrush($White)
  $paleBrush  = New-Object System.Drawing.SolidBrush($Pale)
  $skyBrush   = New-Object System.Drawing.SolidBrush($Sky)

  $t1 = '2026 年中国地球科学联合学术年会'
  $f1 = Get-FittedFont $g $t1 $CJK ([System.Drawing.FontStyle]::Regular) 44 $safeW
  $g.DrawString($t1, $f1, $paleBrush, (New-Object System.Drawing.RectangleF(0, 110, $w, 70)), $sf)

  $t2 = '报告查询'
  $f2 = Get-FittedFont $g $t2 $CJK ([System.Drawing.FontStyle]::Bold) 96 600
  $g.DrawString($t2, $f2, $whiteBrush, (New-Object System.Drawing.RectangleF(0, 190, $w, 130)), $sf)

  $t3 = '3244 条分会场专题报告 · 149 个专题'
  $f3 = Get-FittedFont $g $t3 $CJK ([System.Drawing.FontStyle]::Regular) 40 $safeW
  $g.DrawString($t3, $f3, $skyBrush, (New-Object System.Drawing.RectangleF(0, 330, $w, 60)), $sf)

  # 分隔线
  $pen = New-Object System.Drawing.Pen($Sky, 3)
  $g.DrawLine($pen, [float]($cx - 120), 420, [float]($cx + 120), 420)

  $t4 = '按报告人姓名 / 报告题目 / 专题名即时检索'
  $f4 = Get-FittedFont $g $t4 $CJK ([System.Drawing.FontStyle]::Regular) 38 $safeW
  $g.DrawString($t4, $f4, $paleBrush, (New-Object System.Drawing.RectangleF(0, 440, $w, 60)), $sf)

  $t5 = '10月18–21日 · 杭州国际博览中心'
  $f5 = Get-FittedFont $g $t5 $CJK ([System.Drawing.FontStyle]::Regular) 30 700
  $g.DrawString($t5, $f5, $skyBrush, (New-Object System.Drawing.RectangleF(0, 520, $w, 50)), $sf)

  foreach ($x in @($f1, $f2, $f3, $f4, $f5, $whiteBrush, $paleBrush, $skyBrush, $pen, $bg)) { $x.Dispose() }
  $g.Dispose()
  return $bmp
}

# ---- ICO 封装（内嵌 PNG，Vista 以后都支持）---------------------------------
function Write-Ico([string]$path, [string[]]$pngPaths) {
  $items = @()
  foreach ($p in $pngPaths) {
    $img = [System.Drawing.Image]::FromFile($p)
    $items += [pscustomobject]@{ W = $img.Width; H = $img.Height; Bytes = [System.IO.File]::ReadAllBytes($p) }
    $img.Dispose()
  }
  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$items.Count)
  $offset = 6 + 16 * $items.Count
  foreach ($it in $items) {
    $bw.Write([byte]$(if ($it.W -ge 256) { 0 } else { $it.W }))
    $bw.Write([byte]$(if ($it.H -ge 256) { 0 } else { $it.H }))
    $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$it.Bytes.Length)
    $bw.Write([uint32]$offset)
    $offset += $it.Bytes.Length
  }
  foreach ($it in $items) { $bw.Write($it.Bytes) }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
  $bw.Dispose(); $ms.Dispose()
}

# ---- 生成 ------------------------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('cgu-icons-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

$pairs = @(
  @{ size = 32;  name = 'icon-32.png';          year = $false },
  @{ size = 192; name = 'icon-192.png';         year = $true  },
  @{ size = 512; name = 'icon-512.png';         year = $true  },
  @{ size = 180; name = 'apple-touch-icon.png'; year = $true  }
)
foreach ($p in $pairs) {
  $bmp = New-IconBitmap $p.size $p.year
  Save-Png $bmp (Join-Path $OutDir $p.name)
  $bmp.Dispose()
  Write-Host ("  {0,-22} {1}x{1}" -f $p.name, $p.size)
}

foreach ($s in @(16, 32, 48)) {
  $bmp = New-IconBitmap $s ($s -ge 48)
  Save-Png $bmp (Join-Path $tmp "$s.png")
  $bmp.Dispose()
}
Write-Ico (Join-Path $OutDir 'favicon.ico') @(
  (Join-Path $tmp '16.png'), (Join-Path $tmp '32.png'), (Join-Path $tmp '48.png')
)
Write-Host ("  {0,-22} 16/32/48" -f 'favicon.ico')

$og = New-OgImage 1200 630
Save-Png $og (Join-Path $OutDir 'og-image.png')
$og.Dispose()
Write-Host ("  {0,-22} 1200x630" -f 'og-image.png')

Remove-Item -Recurse -Force $tmp
Write-Host "完成，输出目录：$OutDir"
