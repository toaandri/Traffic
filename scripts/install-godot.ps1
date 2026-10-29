$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $projectRoot '.tools/godot'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$archive = Join-Path $destination 'godot.zip'
$url = 'https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7.2'
Invoke-WebRequest -Uri $url -OutFile $archive
$expectedHash = '731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Archive différente de la version vérifiée : extraction annulée.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
# Mode autonome : données de l’éditeur conservées dans le projet.
New-Item -ItemType File -Force -Path (Join-Path $destination '_sc_') | Out-Null
Write-Host 'Godot 4.7.2 portable prêt.'
