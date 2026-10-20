# Minimum self-check for dsh-douyin-toolkit.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\selfcheck.ps1
$ErrorActionPreference = 'Stop'

$plugin = Split-Path -Parent $PSScriptRoot
$py = Join-Path $plugin '.venv\Scripts\python.exe'

if (-not (Test-Path $py)) {
    Write-Host "FAIL: Python venv not found at $py" -ForegroundColor Red
    Write-Host "Run: python -m venv .venv; .venv\Scripts\python.exe -m pip install -r python\requirements.txt"
    exit 1
}

# dy-cli and Playwright must see a dedicated home/temp inside the package dir.
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
$env:USERPROFILE = Join-Path $plugin 'data\home'
$env:HOME = $env:USERPROFILE
$env:TMP = Join-Path $plugin 'data\tmp'
$env:TEMP = $env:TMP
New-Item -ItemType Directory -Force -Path $env:TMP | Out-Null

$edge = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

Write-Host '== environment ==' -ForegroundColor Cyan
Write-Host "python: $py"
Write-Host "edge:   $(if ($edge) { $edge } else { 'NOT FOUND' })"

Write-Host '== bridge status ==' -ForegroundColor Cyan
& $py (Join-Path $plugin 'python\douyin_bridge.py') status

Write-Host '== douyin hot (3 entries, real request) ==' -ForegroundColor Cyan
& $py -m dy_cli.main trending --count 3 --json-output
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: dy-cli trending exited $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host 'OK' -ForegroundColor Green