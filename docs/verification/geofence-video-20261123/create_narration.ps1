$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$videoDir = $PSScriptRoot
$scenes = Get-Content -Raw -Encoding UTF8 (Join-Path $videoDir 'scenes.json') | ConvertFrom-Json
foreach ($scene in $scenes) {
    $speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $speaker.SelectVoice('Microsoft Heami Desktop')
    $speaker.Rate = 1
    $speaker.SetOutputToWaveFile((Join-Path $videoDir ($scene.id + '.wav')))
    $speaker.Speak($scene.narration)
    $speaker.Dispose()
}
Write-Output 'Korean narration generated.'
