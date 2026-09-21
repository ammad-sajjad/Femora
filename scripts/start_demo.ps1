# Starts the Femora backend and a free Cloudflare quick tunnel, then prints the public address.
# In the app: long-press the header -> Server address -> paste the address. Press Enter here to stop everything.
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\start_demo.ps1   (add -Test to self-check and exit)
param([switch]$Test)
$root = Split-Path -Parent $PSScriptRoot
# The home PC keeps cloudflared on D:; other machines have it on PATH or from npm. Set CLOUDFLARED to override.
$candidates = @($env:CLOUDFLARED, 'D:\dl\tunnel\cloudflared.exe',
                (Join-Path $env:APPDATA 'npm\node_modules\cloudflared\bin\cloudflared.exe'),
                (Get-Command cloudflared.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source))
$cloudflared = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $cloudflared) { throw 'cloudflared.exe not found. Install it or set the CLOUDFLARED variable to its path.' }
$log = Join-Path $env:TEMP 'femora_tunnel.log'
try { Remove-Item -LiteralPath $log -Force -ErrorAction Stop } catch {}   # old log may not exist; short 8.3 temp paths can also fail harmlessly

$api = Start-Process -PassThru -WindowStyle Hidden -WorkingDirectory "$root\backend" `
    -FilePath "$root\backend\.venv\Scripts\uvicorn.exe" -ArgumentList 'app:app', '--host', '127.0.0.1', '--port', '8000'
$tunnel = Start-Process -PassThru -WindowStyle Hidden -FilePath $cloudflared `
    -ArgumentList 'tunnel', '--url', 'http://127.0.0.1:8000', '--no-autoupdate' -RedirectStandardError $log

try {
    $url = $null
    for ($i = 0; $i -lt 60 -and -not $url; $i++) {
        Start-Sleep 2
        if (Test-Path $log) {
            $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
            if ($m) { $url = $m.Matches[0].Value }
        }
    }
    if (-not $url) { throw 'The tunnel did not start. See ' + $log }
    Write-Host "`nFemora server address (paste into the app):`n  $url`n"
    # A brand-new tunnel name takes a few seconds to appear in DNS; wait for it here so Windows does not cache a 'not found'
    $tunnelHost = ([uri]$url).Host
    for ($i = 0; $i -lt 40; $i++) {
        try { Resolve-DnsName $tunnelHost -Server 1.1.1.1 -DnsOnly -ErrorAction Stop | Out-Null; break } catch { Start-Sleep 2 }
    }
    $ok = $false; $err = ''
    for ($i = 0; $i -lt 30 -and -not $ok; $i++) {   # the tunnel needs a few seconds before it answers
        try { $h = Invoke-RestMethod "$url/health" -TimeoutSec 5; Write-Host "Health check OK: $($h.status), models: $($h.models -join ', ')"; $ok = $true }
        catch { $err = $_.Exception.Message; Start-Sleep 2 }
    }
    if (-not $ok) { Write-Host "Health check FAILED: $err" }
    if ($Test) { return }
    Write-Host 'Server is running. Do NOT type or paste anything in this window: the address above goes into the phone app.'
    Read-Host 'Press Enter here ONLY when you want to stop the server and the tunnel'
}
finally {
    Stop-Process -Id $tunnel.Id, $api.Id -Force -ErrorAction SilentlyContinue
}
