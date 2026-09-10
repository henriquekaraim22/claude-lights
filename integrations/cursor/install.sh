#!/bin/bash
# Claude Lights — instalador do hook espião do Cursor (discovery only).
# Mescla no ~/.cursor/hooks.json sem apagar hooks que já existam lá — mesmo
# cuidado do install.sh principal (do Claude Code), formato de config
# diferente porque é de outra ferramenta.
#
# Só use isto numa máquina que realmente tem Cursor. Depois de instalar, use
# o Cursor normalmente por um tempo (inclusive algo que normalmente pediria
# aprovação, tipo rodar um comando de shell) e leia
# ~/.claude/claude-status/cursor-events.log antes de escrever qualquer
# lógica de estado de verdade.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_DIR="$HOME/.cursor"
HOOKS_CONFIG="$CURSOR_DIR/hooks.json"
SPY_DEST="$CURSOR_DIR/claude-lights-spy.py"
TS="$(date +"%Y%m%d-%H%M%S")"

mkdir -p "$CURSOR_DIR"
cp "$PROJECT_DIR/spy.py" "$SPY_DEST"
chmod +x "$SPY_DEST"
echo "espião copiado para $SPY_DEST"

if [ -f "$HOOKS_CONFIG" ]; then
  cp "$HOOKS_CONFIG" "$HOOKS_CONFIG.backup-$TS"
  echo "backup criado: $HOOKS_CONFIG.backup-$TS"
else
  echo '{"version": 1, "hooks": {}}' > "$HOOKS_CONFIG"
fi

python3 - "$HOOKS_CONFIG" "$SPY_DEST" <<'PY'
import json, sys

path, spy_path = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    config = json.load(f)

COMMAND = f"python3 {spy_path}"

# Eventos suficientes pra detectar estado (ver integrations/cursor/spy.py
# pras razões de deixar os mais pesados/ruidosos de fora: afterAgentThought,
# beforeReadFile, etc. — payloads grandes e disparo muito frequente, sem
# ajudar a decidir estado).
EVENTS = [
    "sessionStart", "sessionEnd", "beforeSubmitPrompt",
    "preToolUse", "postToolUse", "postToolUseFailure",
    "subagentStart", "subagentStop", "stop",
]

def entry():
    return {"command": COMMAND, "type": "command", "timeout": 3, "failClosed": False}

config.setdefault("version", 1)
hooks = config.setdefault("hooks", {})
added, skipped = [], []

for event in EVENTS:
    existing = hooks.get(event, [])
    already_present = any(h.get("command") == COMMAND for h in existing)
    if already_present:
        skipped.append(event)
        continue
    hooks[event] = existing + [entry()]
    added.append(event)

with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("eventos adicionados:", ", ".join(added) if added else "nenhum")
print("eventos já presentes (pulados):", ", ".join(skipped) if skipped else "nenhum")
PY

echo "$HOOKS_CONFIG atualizado"
echo
echo "Log vai aparecer em: $HOME/.claude/claude-status/cursor-events.log"
echo "Para reverter: cp $HOOKS_CONFIG.backup-$TS $HOOKS_CONFIG"
