#!/usr/bin/env bash
# Baut build/SpaetiFreunde-<version>.zip mit dem Ordner SpaetiFreunde/.
# Nutzung: scripts/build.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-dev}"
OUT="build"
PKG="$OUT/SpaetiFreunde"

rm -rf "$OUT"
mkdir -p "$PKG"

# Nur Addon-Dateien ins Paket (keine tools/, docs/, .github/, scripts/)
cp SpaetiFreunde.toc LICENSE README.md CHANGELOG.md "$PKG/"
for dir in Core Locale Modules UI Media; do
    [ -d "$dir" ] && cp -r "$dir" "$PKG/"
done

# Version in die TOC schreiben
sed -i "s/@project-version@/$VERSION/" "$PKG/SpaetiFreunde.toc"

(cd "$OUT" && zip -qr "SpaetiFreunde-$VERSION.zip" SpaetiFreunde)
echo "Gebaut: $OUT/SpaetiFreunde-$VERSION.zip"
