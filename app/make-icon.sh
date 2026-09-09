#!/bin/bash
# Claude Lights — gera ClaudeLights.icns a partir de assets/icon-source.png
# (320x320, desenhado no Figma pelo usuário — 2026-09-09). Sizes acima de
# 320 são upscale (checado visualmente: o design é todo em gradiente suave,
# sem linhas duras, então segura bem ampliado). Chamado por package.sh.

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$APP_DIR/../assets/icon-source.png"
ICONSET="$APP_DIR/.build/ClaudeLights.iconset"
ICNS_OUT="$APP_DIR/.build/ClaudeLights.icns"

if [ ! -f "$SOURCE" ]; then
  echo "aviso: $SOURCE não existe, pulando geração de ícone" >&2
  exit 0
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

python3 - "$SOURCE" "$ICONSET" <<'PY'
import sys
from PIL import Image

source_path, iconset_dir = sys.argv[1], sys.argv[2]
img = Image.open(source_path).convert("RGBA")

# Nomes e tamanhos exatos que o iconutil espera dentro de um .iconset.
sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for name, size in sizes:
    resized = img.resize((size, size), Image.LANCZOS)
    resized.save(f"{iconset_dir}/{name}")

print(f"gerados {len(sizes)} tamanhos em {iconset_dir}")
PY

iconutil -c icns "$ICONSET" -o "$ICNS_OUT"
rm -rf "$ICONSET"
echo "ícone gerado: $ICNS_OUT"
