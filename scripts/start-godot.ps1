$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Get-ChildItem -LiteralPath (Join-Path $projectRoot '.tools/godot') -Filter '*win64.exe' | Select-Object -First 1
if (-not $engine) { throw 'Godot portable introuvable dans .tools/godot.' }
Start-Process -FilePath $engine.FullName -ArgumentList @('--path', ('"' + (Join-Path $projectRoot 'frontend/godot') + '"')) -WindowStyle Hidden
