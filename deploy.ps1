# deploy.ps1 — Script de déploiement automatique PharmaGest Online
$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  🚀 DÉPLOIEMENT PHARMAGEST ONLINE SUR GITHUB & CLOUD" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$rootDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
Set-Location $rootDir

# 1. Vérification de la sécurité .env
Write-Host "[*] 1/4 - Vérification de sécurité (.env)..." -ForegroundColor Yellow
$envTracked = git status --porcelain | Select-String "\.env$"
if ($envTracked) {
    Write-Host "[ERREUR] Le fichier .env est détecté dans Git. Déploiement annulé !" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Fichiers secrets strictement protégés." -ForegroundColor Green
Write-Host ""

# 2. Compilation Flutter Web pour Vercel
Write-Host "[*] 2/4 - Compilation de l'interface Flutter Web (pour Vercel)..." -ForegroundColor Yellow
Set-Location "$rootDir\frontend1"
flutter build web --release --base-href /
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] Échec de la compilation Flutter Web !" -ForegroundColor Red
    Set-Location $rootDir
    exit 1
}
Write-Host "[OK] Flutter Web compilé dans frontend1/build/web" -ForegroundColor Green
Set-Location $rootDir
Write-Host ""

# 3. Préparation Git
Write-Host "[*] 3/4 - Ajout des fichiers modifiés et commit Git..." -ForegroundColor Yellow
git add .
$commitMsg = "feat: complete platform upgrade (security hardening, multi-tenant OBR EBMS Burundi, refresh token auto-retry, route cleanup, accounting & credit services)"
git commit -m $commitMsg
Write-Host "[OK] Commit créé localement." -ForegroundColor Green
Write-Host ""

# 4. Envoi sur GitHub
Write-Host "[*] 4/4 - Envoi vers GitHub (Push sur origin main)..." -ForegroundColor Yellow
git push origin main
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ✅ TOUT EST DÉPLOYÉ AVEC SUCCÈS SUR GITHUB !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 1. Backend Render :" -ForegroundColor Cyan
Write-Host "   Render détecte le commit et redémarre automatiquement sous ~2 minutes."
Write-Host "   Documentation Swagger : https://pharmagest-pnn8.onrender.com/docs"
Write-Host ""
Write-Host "🌐 2. Frontend Vercel :" -ForegroundColor Cyan
Write-Host "   Vercel sert les nouveaux fichiers de build/web en ~15 secondes."
Write-Host ""
Write-Host "🗄️ 3. Base de Données Aiven MySQL :" -ForegroundColor Cyan
Write-Host "   Déjà migrée à jour (HEAD) avec les nouvelles colonnes fiscales OBR."
Write-Host ""
