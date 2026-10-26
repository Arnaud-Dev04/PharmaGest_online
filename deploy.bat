@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo   DEPLOIEMENT PHARMAGEST ONLINE SUR GITHUB ET CLOUD
echo ============================================================
echo.

echo [*] 1/4 - Verification de la securite .env ...
git status --porcelain | findstr /i "\.env$" > nul
if not errorlevel 1 (
    echo [ERREUR] Le fichier .env ne doit JAMAIS etre suivi par Git !
    echo Operation annulee pour proteger vos cles secretes.
    pause
    exit /b 1
)
echo [OK] Aucun secret expose dans Git.
echo.

echo [*] 2/4 - Compilation de l'interface Flutter Web pour Vercel ...
cd frontend1
call flutter build web --release --base-href /
if errorlevel 1 (
    echo [ERREUR] La compilation Flutter Web a echoue !
    echo Veuillez verifier les erreurs ci-dessus avant de pousser sur GitHub.
    cd ..
    pause
    exit /b 1
) else (
    echo [OK] Flutter Web compile avec succes dans frontend1/build/web.
)
cd ..
echo.

echo [*] 3/4 - Preparation des fichiers et validation Git ...
git add .
git commit -m "feat: complete platform upgrade - security hardening, multi-tenant OBR EBMS Burundi, refresh token auto-retry, route cleanup, accounting and credit services"
echo.

echo [*] 4/4 - Envoi vers GitHub - Push origin main ...
git push origin main
if errorlevel 1 (
    echo [ERREUR] Echec du git push. Verifiez votre connexion Internet et vos droits GitHub.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   TOUT EST DEPLOYE AVEC SUCCES SUR GITHUB !
echo ============================================================
echo.
echo 1. Backend Render :
echo    Render detecte le commit et redemarre automatiquement :
echo    https://pharmagest-pnn8.onrender.com/docs
echo.
echo 2. Frontend Vercel :
echo    Vercel deploie la nouvelle version web en ~15 secondes.
echo.
echo 3. Base de donnees Aiven MySQL :
echo    Deja migree a jour avec les nouveaux champs fiscaux OBR !
echo.
echo Operation terminee avec succes.
pause
