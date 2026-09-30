#!/bin/bash
# build.sh — Script de build Flutter Web pour Vercel
set -e
set -x

echo "=========================================="
echo " PharmaGestion — Build Flutter Web"
echo "=========================================="

# ── Fix git ownership (Vercel tourne en root) ─────────────────────────────────
git config --global --add safe.directory '*'

# ── 1. Flutter SDK — dernier stable via git clone ────────────────────────────
if [ ! -d "flutter" ]; then
  echo "[1/4] Clonage Flutter stable (latest)..."
  git clone https://github.com/flutter/flutter.git \
    --depth 1 -b stable --single-branch \
    flutter
  echo "Flutter SDK cloné."
else
  echo "[1/4] Flutter SDK déjà en cache — mise à jour..."
  git -C flutter pull --rebase --depth 1 || true
fi

export PATH="$PATH:$(pwd)/flutter/bin"

# ── 2. Configuration Flutter ──────────────────────────────────────────────────
echo "[2/4] Configuration Flutter..."
git config --global --add safe.directory "$(pwd)/flutter"
flutter config --no-analytics
flutter config --enable-web
flutter --version

ROOT_DIR="$(pwd)"

# ── 3. Dépendances ────────────────────────────────────────────────────────────
echo "[3/4] Installation des dépendances..."
cd "$ROOT_DIR/frontend1"
flutter pub get
cd "$ROOT_DIR"

# ── 4. Build Web ──────────────────────────────────────────────────────────────
echo "[4/4] Build Flutter Web (skwasm — Flutter 3.22+)..."
cd "$ROOT_DIR/frontend1"
flutter build web --release
cd "$ROOT_DIR"

echo "=========================================="
echo " Build terminé ! Output: frontend1/build/web"
echo "=========================================="
