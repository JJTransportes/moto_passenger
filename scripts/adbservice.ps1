# adbservice — prepara o celular físico para acessar o backend no Docker do PC
# Uso: ./scripts/adbservice.ps1        (só configura o reverse)
#      ./scripts/adbservice.ps1 -Run   (configura e roda o app)
param([switch]$Run)

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { throw "adb.exe nao encontrado em $adb" }

Write-Host "Configurando adb reverse tcp:8080 -> backend Docker..." -ForegroundColor Cyan
& $adb reverse tcp:8080 tcp:8080 | Out-Null
& $adb reverse --list

if ($Run) {
    Write-Host "Iniciando flutter run..." -ForegroundColor Cyan
    flutter run
}
