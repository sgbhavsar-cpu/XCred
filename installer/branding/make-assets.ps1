$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$dir = $PSScriptRoot
$srcPath = Join-Path $dir 'logo-raw.png'
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

# ── Auto-trim transparent padding around the logo ────────────────────────────
function Get-OpaqueBounds([System.Drawing.Bitmap]$bmp) {
    $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
    $data = $bmp.LockBits((New-Object System.Drawing.Rectangle 0,0,$bmp.Width,$bmp.Height), [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        $row = $y * $data.Stride
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            $alpha = $bytes[$row + $x * 4 + 3]
            if ($alpha -gt 10) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    return New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
}

$bounds = Get-OpaqueBounds $src
Write-Host "Trimmed bounds: $bounds"
$trimmed = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($trimmed)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0,0,$bounds.Width,$bounds.Height), $bounds, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$trimmed.Save((Join-Path $dir 'logo-trimmed.png'), [System.Drawing.Imaging.ImageFormat]::Png)

function New-SquareLogo([System.Drawing.Bitmap]$logo, [int]$size, [int]$paddingPct = 12) {
    $canvas = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gr = [System.Drawing.Graphics]::FromImage($canvas)
    $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gr.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gr.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gr.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $pad = [int]($size * $paddingPct / 100.0)
    $avail = $size - 2 * $pad
    $scale = [Math]::Min($avail / $logo.Width, $avail / $logo.Height)
    $w = [int]($logo.Width * $scale)
    $h = [int]($logo.Height * $scale)
    $x = [int](($size - $w) / 2)
    $y = [int](($size - $h) / 2)
    $gr.DrawImage($logo, $x, $y, $w, $h)
    $gr.Dispose()
    return $canvas
}

# ── Build a multi-resolution .ico (PNG-format entries, valid since Vista) ────
function New-IcoFile([System.Drawing.Bitmap]$logo, [string]$outPath, [int[]]$sizes) {
    $pngBlobs = @()
    foreach ($sz in $sizes) {
        $img = New-SquareLogo $logo $sz 10
        $ms = New-Object System.IO.MemoryStream
        $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBlobs += ,($ms.ToArray())
        $img.Dispose()
    }

    $fs = New-Object System.IO.FileStream $outPath, ([System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter $fs

    # ICONDIR
    $bw.Write([UInt16]0)      # reserved
    $bw.Write([UInt16]1)      # type = icon
    $bw.Write([UInt16]$sizes.Count)

    $headerSize = 6
    $dirEntrySize = 16
    $offset = $headerSize + $dirEntrySize * $sizes.Count

    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $sz = $sizes[$i]
        $dim = if ($sz -ge 256) { 0 } else { $sz }   # 0 means 256 in ICO format
        $bw.Write([byte]$dim)          # width
        $bw.Write([byte]$dim)          # height
        $bw.Write([byte]0)             # color palette
        $bw.Write([byte]0)             # reserved
        $bw.Write([UInt16]1)           # color planes
        $bw.Write([UInt16]32)          # bits per pixel
        $bw.Write([UInt32]$pngBlobs[$i].Length)
        $bw.Write([UInt32]$offset)
        $offset += $pngBlobs[$i].Length
    }
    foreach ($blob in $pngBlobs) { $bw.Write($blob) }

    $bw.Flush(); $bw.Close(); $fs.Close()
}

$logo = [System.Drawing.Bitmap]::FromFile((Join-Path $dir 'logo-trimmed.png'))
New-IcoFile $logo (Join-Path $dir 'xcred.ico') @(16,24,32,48,64,128,256)
Write-Host "Wrote xcred.ico"

# ── Wizard banner images (BMP, as required by Inno Setup) ───────────────────
function New-BannerBmp([System.Drawing.Bitmap]$logo, [int]$w, [int]$h, [string]$outPath) {
    $canvas = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $gr = [System.Drawing.Graphics]::FromImage($canvas)
    $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gr.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gr.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $gr.Clear([System.Drawing.Color]::White)

    $pad = [int]($w * 0.16)
    $avail = $w - 2 * $pad
    $scale = $avail / $logo.Width
    $lw = [int]($logo.Width * $scale)
    $lh = [int]($logo.Height * $scale)
    $x = [int](($w - $lw) / 2)
    $y = [int](($h - $lh) / 2)
    $gr.DrawImage($logo, $x, $y, $lw, $lh)
    $gr.Dispose()
    $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $canvas.Dispose()
}

New-BannerBmp $logo 164 314 (Join-Path $dir 'WizardImage.bmp')
New-BannerBmp $logo 55 58 (Join-Path $dir 'WizardSmallImage.bmp')
Write-Host "Wrote WizardImage.bmp and WizardSmallImage.bmp"

$logo.Dispose()
$src.Dispose()
$trimmed.Dispose()
