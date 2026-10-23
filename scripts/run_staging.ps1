# Script pour démarrer le backend en environnement de Staging
param (
    [string]$EnvFile = "backend/.env.staging",
    [int]$Port = 8000,
    [int]$Workers = 2
)

if (-Not (Test-Path $EnvFile)) {
    if (Test-Path "backend/.env.staging.example") {
        Write-Warning "Fichier $EnvFile introuvable. Copie depuis backend/.env.staging.example..."
        Copy-Item "backend/.env.staging.example" $EnvFile
    } else {
        Write-Error "Fichier d'environnement $EnvFile introuvable."
        exit 1
    }
}

$env:DOTENV_PATH = (Resolve-Path $EnvFile).Path
$env:ENVIRONMENT = "staging"

Write-Host "Démarrage du backend PharmaGestion en mode STAGING sur le port $Port..." -ForegroundColor Cyan
Set-Location backend
python -m uvicorn render_main:app --host 0.0.0.0 --port $Port --workers $Workers
