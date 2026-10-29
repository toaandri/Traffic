param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'dist' }
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$buildDirectory = Join-Path $OutputDirectory 'build'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
$env:TEMP = Join-Path $buildDirectory 'temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
$iconFile = Join-Path $projectRoot 'frontend/godot/assets/traffic.ico'
& ./.venv/Scripts/python.exe -m PyInstaller --noconfirm --onedir --windowed --name Traffic --icon $iconFile --paths backend/src --collect-all websockets --collect-all pydantic --collect-all networkx --copy-metadata eclipse-sumo --copy-metadata traci --distpath $OutputDirectory --workpath $buildDirectory --specpath $buildDirectory scripts/desktop_entry.py
if ($LASTEXITCODE -ne 0) { throw 'La compilation de Traffic a échoué.' }
$release = Join-Path $OutputDirectory 'Traffic'
New-Item -ItemType Directory -Force -Path (Join-Path $release 'runtime'),(Join-Path $release 'sumo/bin'),(Join-Path $release 'data/scenarios'),(Join-Path $release 'docs') | Out-Null
Copy-Item -LiteralPath '.tools/godot/Godot_v4.7.2-stable_win64.exe' -Destination (Join-Path $release 'runtime/GodotRuntime.exe')
Copy-Item -Path '.venv/Lib/site-packages/sumo/bin/*.dll' -Destination (Join-Path $release 'sumo/bin')
Copy-Item -LiteralPath '.venv/Lib/site-packages/sumo/bin/sumo.exe','.venv/Lib/site-packages/sumo/bin/netconvert.exe' -Destination (Join-Path $release 'sumo/bin')
Copy-Item -LiteralPath '.venv/Lib/site-packages/sumo/data' -Destination (Join-Path $release 'sumo') -Recurse
Copy-Item -Path 'data/scenarios/*.json' -Destination (Join-Path $release 'data/scenarios')
Copy-Item -Path 'docs/*.md' -Destination (Join-Path $release 'docs')
Copy-Item -LiteralPath 'docs/licenses' -Destination (Join-Path $release 'docs') -Recurse -Force
Copy-Item -LiteralPath 'docs/screenshots' -Destination (Join-Path $release 'docs') -Recurse -Force
Copy-Item -LiteralPath 'docs/media' -Destination (Join-Path $release 'docs') -Recurse -Force
Copy-Item -LiteralPath 'README.md','CONTRIBUTING.md','requirements.lock.txt' -Destination $release
$env:APPDATA = Join-Path $buildDirectory 'godot-profile'
$env:LOCALAPPDATA = $env:APPDATA
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path frontend/godot --export-pack 'Windows Desktop' (Join-Path $release 'runtime/traffic.pck')
if ($LASTEXITCODE -ne 0) { throw "L'export de l'interface a échoué." }
Write-Host ('Application portable : ' + (Join-Path $release 'Traffic.exe'))
