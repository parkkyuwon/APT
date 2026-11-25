param(
    [string]$Source = (Join-Path $PSScriptRoot '../assets/branding/app-icon-master.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceImage = [Drawing.Image]::FromFile([IO.Path]::GetFullPath($Source))

function Save-Icon([string]$Destination, [int]$Size) {
    $bitmap = New-Object Drawing.Bitmap($Size, $Size, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $attributes = New-Object Drawing.Imaging.ImageAttributes
    try {
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $rect = New-Object Drawing.Rectangle(0, 0, $Size, $Size)
        $graphics.DrawImage($sourceImage, $rect, 0, 0, $sourceImage.Width, $sourceImage.Height,
            [Drawing.GraphicsUnit]::Pixel, $attributes)
        $bitmap.Save($Destination, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output "$Size x $Size : $Destination"
    } finally {
        $attributes.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    if ($sourceImage.Width -ne $sourceImage.Height -or $sourceImage.Width -lt 1024) {
        throw 'Icon master must be square and at least 1024 pixels wide.'
    }
    Save-Icon (Join-Path $projectRoot 'assets/branding/play-store-icon-512.png') 512
    $androidSizes = @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}
    foreach ($density in $androidSizes.Keys) {
        Save-Icon (Join-Path $projectRoot "android/app/src/main/res/mipmap-$density/ic_launcher.png") $androidSizes[$density]
    }
    $iosDirectory = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $catalog = Get-Content (Join-Path $iosDirectory 'Contents.json') -Raw | ConvertFrom-Json
    foreach ($entry in ($catalog.images | Sort-Object filename -Unique)) {
        if ([IO.Path]::GetFileName($entry.filename) -ne $entry.filename) {
            throw 'Icon catalog filenames must not contain directories.'
        }
        $points = [double]::Parse($entry.size.Split('x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [int]$entry.scale.TrimEnd('x')
        Save-Icon (Join-Path $iosDirectory $entry.filename) ([int]($points * $scale))
    }
} finally {
    $sourceImage.Dispose()
}
