#!/bin/bash
# Claude Status — Fase 1
# Wrapper fino: repassa o stdin do hook para state.py, que faz a detecção
# de estado e toca o som. Mantido em .sh separado porque é o comando já
# registrado em ~/.claude/settings.json (não precisa mexer lá de novo).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$DIR/state.py"
