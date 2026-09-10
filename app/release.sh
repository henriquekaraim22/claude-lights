#!/bin/bash
# Claude Lights — processo de release.
# Uso: ./release.sh 0.2.0
#
# Faz tudo que dá pra automatizar sem o `gh` CLI (não instalado nesta
# máquina, nem Homebrew pra instalar): bump de versão, build, tag, push, e
# abre a página do GitHub já preenchida pra criar a release. O único passo
# manual que sobra é arrastar o .dmg pra lá e clicar em "Publish release" —
# GitHub Releases não tem API sem token, e não vamos guardar token aqui.

set -euo pipefail

REPO_URL_BASE="https://github.com/henriquekaraim22/claude-lights"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$APP_DIR/.." && pwd)"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "uso: ./release.sh <versão>   (ex.: ./release.sh 0.2.0)" >&2
  exit 1
fi

cd "$REPO_DIR"

if [ -n "$(git status --short)" ]; then
  echo "há mudanças não commitadas. Commite (ou descarte) antes de lançar uma release:" >&2
  git status --short >&2
  exit 1
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "a tag v$VERSION já existe. Escolha outra versão." >&2
  exit 1
fi

echo "$VERSION" > "$APP_DIR/VERSION"
git add "$APP_DIR/VERSION"
git commit -m "Bump version to $VERSION"

echo
echo "compilando e empacotando v$VERSION..."
"$APP_DIR/package.sh" release
"$APP_DIR/make-icon.sh" >/dev/null
"$APP_DIR/make-dmg.sh"

echo
echo "criando e enviando a tag v$VERSION..."
git tag "v$VERSION"
git push
git push origin "v$VERSION"

DMG="$APP_DIR/.build/ClaudeLights.dmg"
RELEASE_URL="$REPO_URL_BASE/releases/new?tag=v$VERSION&title=Claude+Lights+v$VERSION"

echo
echo "tudo pronto até onde dá sem o gh CLI. Faltam só 2 cliques:"
echo "1. Abrindo a página da release (já com a tag e o título preenchidos)..."
echo "2. Arraste este arquivo nela e clique em 'Publish release':"
echo "   $DMG"
open "$RELEASE_URL"
