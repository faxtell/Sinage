param(
    [int]$PollIntervalSec = 5,
    [int]$BaseDisplaySec = 180,
    [string]$ViewerUrl = "https://kotoho7.github.io/scratch-realtime-earthquake-viewer-page/"
)

$ErrorActionPreference = "Stop"

$historyApi = "https://api.p2pquake.net/v2/history?codes=551&limit=1"
$edgeProfileDir = Join-Path $env:TEMP "quake-overlay-profile"

if (-not (Test-Path $edgeProfileDir)) {
    New-Item -ItemType Directory -Path $edgeProfileDir | Out-Null
}

$lastEventId = ""
$hideAt = [DateTime]::MinValue
$edgeShown = $false

function Get-LatestQuake {
    param([string]$ApiUrl)

    $response = Invoke-RestMethod -Uri $ApiUrl -Method Get -TimeoutSec 10
    if ($null -eq $response -or $response.Count -eq 0) {
        return $null
    }

    return $response[0]
}

function Is-JapanEvent {
    param($quake)

    # P2P地震情報は国内イベント中心だが、念のため place を確認
    if ($null -eq $quake.earthquake -or $null -eq $quake.earthquake.hypocenter) {
        return $false
    }

    $place = [string]$quake.earthquake.hypocenter.name
    if ([string]::IsNullOrWhiteSpace($place)) {
        return $false
    }

    # 「遠地」や「海外」などを除外
    if ($place -match "海外|遠地") {
        return $false
    }

    return $true
}

function Is-Shindo2OrMore {
    param($quake)

    if ($null -eq $quake.earthquake -or $null -eq $quake.earthquake.maxScale) {
        return $false
    }

    # P2PのmaxScaleは 10=震度1, 20=震度2, ...
    return ([int]$quake.earthquake.maxScale -ge 20)
}

function Show-Overlay {
    param(
        [string]$Url,
        [string]$ProfileDir
    )

    $args = @(
        "--user-data-dir=$ProfileDir",
        "--kiosk",
        $Url,
        "--edge-kiosk-type=fullscreen",
        "--no-first-run",
        "--disable-features=msEdgeSidebarV2"
    )

    Start-Process -FilePath "msedge.exe" -ArgumentList $args | Out-Null
}

function Hide-Overlay {
    param([string]$ProfileDir)

    $escaped = [Regex]::Escape("--user-data-dir=$ProfileDir")
    $targets = Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
        Where-Object { $_.CommandLine -match $escaped }

    foreach ($p in $targets) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "監視開始: 日本国内で震度2以上を検知したらオーバーレイ表示します。"
Write-Host "停止するには Ctrl + C"

while ($true) {
    try {
        $quake = Get-LatestQuake -ApiUrl $historyApi

        if ($null -ne $quake) {
            $eventId = [string]$quake.id
            if ($eventId -ne $lastEventId) {
                $lastEventId = $eventId

                if ((Is-JapanEvent -quake $quake) -and (Is-Shindo2OrMore -quake $quake)) {
                    $hideAt = (Get-Date).AddSeconds($BaseDisplaySec)

                    if (-not $edgeShown) {
                        Show-Overlay -Url $ViewerUrl -ProfileDir $edgeProfileDir
                        $edgeShown = $true
                        Write-Host "[$(Get-Date -Format 'u')] 震度2以上を検知: オーバーレイ表示"
                    }
                    else {
                        Write-Host "[$(Get-Date -Format 'u')] 連続地震を検知: 表示時間を延長"
                    }
                }
            }
        }

        if ($edgeShown -and (Get-Date) -ge $hideAt) {
            Hide-Overlay -ProfileDir $edgeProfileDir
            $edgeShown = $false
            Write-Host "[$(Get-Date -Format 'u')] 一定時間経過: オーバーレイ非表示"
        }
    }
    catch {
        Write-Warning "監視ループでエラー: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $PollIntervalSec
}
