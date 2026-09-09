#!/bin/bash
# Claude Status — instalador
# Copia os scripts de hook para ~/.claude/claude-status/, faz backup do
# settings.json e mescla o bloco de hooks sem apagar nada que já exista.
# Idempotente: rodar de novo só redeploya os scripts e não duplica hooks.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_DIR="$HOME/.claude/claude-status"
SETTINGS="$HOME/.claude/settings.json"
TS="$(date +"%Y%m%d-%H%M%S")"

mkdir -p "$STATUS_DIR"
cp "$PROJECT_DIR/hooks/hook.sh" "$STATUS_DIR/hook.sh"
cp "$PROJECT_DIR/hooks/state.py" "$STATUS_DIR/state.py"
chmod +x "$STATUS_DIR/hook.sh" "$STATUS_DIR/state.py"
echo "scripts copiados para $STATUS_DIR/ (hook.sh + state.py)"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.backup-$TS"
  echo "backup criado: $SETTINGS.backup-$TS"
else
  echo '{}' > "$SETTINGS"
fi

python3 - "$SETTINGS" <<'PY'
import json, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    settings = json.load(f)

HOOK_CMD = "$HOME/.claude/claude-status/hook.sh"

def entry(matcher=None):
    h = {"type": "command", "command": HOOK_CMD, "async": True}
    block = {"hooks": [h]}
    if matcher is not None:
        block["matcher"] = matcher
    return block

# Eventos usados pelo state.py (detecção de estado + som), conforme docs/PRD.md e CLAUDE.md.
EVENTS = {
    "SessionStart": [entry()],
    "UserPromptSubmit": [entry()],
    "PreToolUse": [entry(matcher="")],
    "PostToolUse": [entry(matcher="")],
    "PermissionRequest": [entry()],
    "Notification": [entry(matcher="")],
    "Stop": [entry()],
    "StopFailure": [entry()],
    "SubagentStop": [entry()],
    "SessionEnd": [entry()],
}

hooks = settings.setdefault("hooks", {})
added = []
skipped = []

for event, blocks in EVENTS.items():
    existing = hooks.get(event, [])
    already_has_our_hook = any(
        h.get("command") == HOOK_CMD
        for block in existing
        for h in block.get("hooks", [])
    )
    if already_has_our_hook:
        skipped.append(event)
        continue
    hooks[event] = existing + blocks
    added.append(event)

with open(path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("eventos adicionados:", ", ".join(added) if added else "nenhum")
print("eventos já presentes (pulados):", ", ".join(skipped) if skipped else "nenhum")
PY

echo "settings.json atualizado: $SETTINGS"
echo
echo "Para reverter: cp $SETTINGS.backup-$TS $SETTINGS"
