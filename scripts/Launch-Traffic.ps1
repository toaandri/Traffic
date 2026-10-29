$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$python = Join-Path $projectRoot '.venv/Scripts/pythonw.exe'
Start-Process -FilePath $python -WorkingDirectory $projectRoot -ArgumentList @('-m', 'traffic.desktop') -WindowStyle Hidden
