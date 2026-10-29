$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force -Path '.tools/tmp' | Out-Null
$env:TEMP = Join-Path (Get-Location) '.tools/tmp'
$env:TMP = $env:TEMP
if (-not (Test-Path '.venv/Scripts/python.exe')) {
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Création Python impossible.' }
}
& ./.venv/Scripts/python.exe -m pip install -r requirements.lock.txt
if ($LASTEXITCODE -ne 0) { throw 'Installation des dépendances impossible.' }
& ./.venv/Scripts/python.exe -m pip install --no-deps -e .
if ($LASTEXITCODE -ne 0) { throw 'Installation Traffic impossible.' }
Write-Host 'Environnement Traffic prêt.'
