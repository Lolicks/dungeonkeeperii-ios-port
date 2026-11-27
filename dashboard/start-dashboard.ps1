param([int]$Port = 8080)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $PSScriptRoot 'backend'
$venv = Join-Path $root '.venv'

if (-not (Test-Path (Join-Path $venv 'Scripts\python.exe'))) {
    Write-Host "Creating virtual environment..."
    python -m venv $venv
}
$py = Join-Path $venv 'Scripts\python.exe'
& $py -m pip install --quiet -r (Join-Path $backend 'requirements.txt')

Write-Host "Starting Dungeon Keeper II iOS Port Control Center on http://localhost:$Port"
$env:CONTROL_CENTER_PORT = "$Port"
& $py (Join-Path $backend 'app.py')
