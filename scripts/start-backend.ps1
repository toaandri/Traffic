param([string]$Scenario = 'data/scenarios/grid.json')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
& ./.venv/Scripts/python.exe -m traffic.cli serve --scenario $Scenario
