param(
    [Parameter(Mandatory=$true)]
    [string]$path,
    [Parameter(Mandatory=$true)]
    [double]$vol
)

try {
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([Uri]::new("file:///$($path -replace '\\','/')"))
    $player.Volume = $vol
    Start-Sleep -Milliseconds 150
    $player.Play()
    $timeout = 50
    while ($timeout -gt 0 -and $player.Position.TotalMilliseconds -eq 0) {
        Start-Sleep -Milliseconds 100
        $timeout--
    }
    if ($player.NaturalDuration.HasTimeSpan) {
        $remaining = $player.NaturalDuration.TimeSpan.TotalMilliseconds - $player.Position.TotalMilliseconds
        if ($remaining -gt 0 -and $remaining -lt 5000) {
            Start-Sleep -Milliseconds ([int]$remaining + 100)
        }
    } else {
        Start-Sleep -Seconds 2
    }
    $player.Close()
} catch {
    if ($path -match "\.wav$") {
        try {
            $sp = New-Object System.Media.SoundPlayer $path
            $sp.Play()
            Start-Sleep -Seconds 2
            $sp.Dispose()
        } catch {}
    }
}
