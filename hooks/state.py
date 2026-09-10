#!/usr/bin/env python3
"""Claude Status — Fase 1: detecta estado por sessão e toca som.

Lê o JSON do hook via stdin, mantém um arquivo de estado por sessão em
~/.claude/claude-status/sessions/<session_id>.json e toca som quando o
estado muda para algo que precisa de aviso (RF3: uma vez por transição).

Mapeamento (ver docs/PRD.md e CLAUDE.md do projeto):
  UserPromptSubmit                          -> working
  PreToolUse (tool != AskUserQuestion)      -> working
  PreToolUse/PermissionRequest AskUserQuestion -> waiting_question (som Ping)
  PermissionRequest (outro tool)            -> waiting_permission (som Ping)
  Stop                                       -> done (som Glass, só se turno > 10s — RF4)
  StopFailure                                -> error (som Sosumi)
  Notification idle_prompt                   -> idle
  SessionEnd                                 -> remove a sessão
"""
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

STATUS_DIR = os.path.expanduser("~/.claude/claude-status")
SESSIONS_DIR = os.path.join(STATUS_DIR, "sessions")
DEBUG_LOG = os.path.join(STATUS_DIR, "debug.log")
DEBUG_LOG_MAX_LINES = 500
SOUNDS_DIR = "/System/Library/Sounds"

SOUND_MAP = {
    "waiting_question": "Ping.aiff",
    "waiting_permission": "Ping.aiff",
    "error": "Sosumi.aiff",
}

# "done" is the only sound the user can customize (2026-09-09, explicit
# request: "o único som que pode ser trocado é esse, todos os outros não
# podem ser alterados") — kept out of SOUND_MAP on purpose so it can never
# be looked up the same static way as the other three. VALID_SOUNDS is the
# same 14-file list confirmed by ear earlier in the project (see CLAUDE.md);
# anything else read from the config file is ignored, falling back to the
# default, rather than trusting an unexpected value.
DONE_SOUND_FILE = os.path.join(STATUS_DIR, "done_sound")
DEFAULT_DONE_SOUND = "Glass"
VALID_SOUNDS = {
    "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
    "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
}


def get_done_sound():
    try:
        with open(DONE_SOUND_FILE) as f:
            name = f.read().strip()
        if name in VALID_SOUNDS:
            return f"{name}.aiff"
    except Exception:
        pass
    return f"{DEFAULT_DONE_SOUND}.aiff"

DONE_MIN_DURATION_S = 10  # RF4: só toca "concluído" se o turno durou mais que isso


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def session_path(session_id):
    return os.path.join(SESSIONS_DIR, f"{session_id}.json")


def load_state(session_id):
    path = session_path(session_id)
    if os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_state(session_id, data):
    os.makedirs(SESSIONS_DIR, exist_ok=True)
    path = session_path(session_id)
    fd, tmp_path = tempfile.mkstemp(dir=SESSIONS_DIR, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, ensure_ascii=False)
        os.replace(tmp_path, path)  # escrita atômica (RNF6)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def remove_state(session_id):
    try:
        os.remove(session_path(session_id))
    except FileNotFoundError:
        pass


FORCE_ENABLED_FILE = os.path.join(STATUS_DIR, "force_max_volume")
FORCE_LEVEL_FILE = os.path.join(STATUS_DIR, "force_volume_level")
DEFAULT_FORCE_LEVEL = 100
SYSTEM_VOLUME_RESTORE_DELAY_S = 2  # tempo que o afplay leva pra terminar, aprox.


def get_force_max_volume_enabled():
    # Um único toggle liga/desliga tudo (redesenhado 2026-09-09 a pedido do
    # usuário — antes eram dois controles independentes, um multiplicador
    # relativo sempre ativo e um force separado, e ficou confuso qual
    # dependia de qual). Desligado é o padrão: forçar o volume do sistema é
    # invasivo, afeta qualquer áudio tocando no momento.
    try:
        with open(FORCE_ENABLED_FILE) as f:
            return f.read().strip() == "1"
    except Exception:
        return False


def get_force_volume_level():
    # Só importa quando get_force_max_volume_enabled() é True.
    try:
        with open(FORCE_LEVEL_FILE) as f:
            return max(0.0, min(100.0, float(f.read().strip())))
    except Exception:
        return DEFAULT_FORCE_LEVEL


def get_system_volume():
    try:
        out = subprocess.run(
            ["osascript", "-e", "output volume of (get volume settings)"],
            capture_output=True, text=True, timeout=2,
        )
        return out.stdout.strip()
    except Exception:
        return None


def set_system_volume(level):
    try:
        subprocess.run(["osascript", "-e", f"set volume output volume {level}"], timeout=2)
    except Exception:
        pass


def play_sound(name):
    sound_path = os.path.join(SOUNDS_DIR, name)
    previous_system_volume = None

    if get_force_max_volume_enabled():
        # Confirmado testando de verdade em 2026-09-09: afplay -v é relativo
        # ao volume atual do sistema, não um valor absoluto, então não dá
        # pra garantir audível só com isso. Forçar o volume real do sistema
        # (e devolver depois) é a única forma de garantir de verdade.
        previous_system_volume = get_system_volume()
        set_system_volume(get_force_volume_level())

    try:
        subprocess.Popen(
            ["afplay", sound_path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass

    if previous_system_volume:
        try:
            subprocess.Popen(
                ["bash", "-c", f"sleep {SYSTEM_VOLUME_RESTORE_DELAY_S} && osascript -e 'set volume output volume {previous_system_volume}'"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass


def log_debug(line):
    try:
        os.makedirs(STATUS_DIR, exist_ok=True)
        with open(DEBUG_LOG, "a") as f:
            f.write(line + "\n")
        with open(DEBUG_LOG) as f:
            lines = f.readlines()
        if len(lines) > DEBUG_LOG_MAX_LINES:
            with open(DEBUG_LOG, "w") as f:
                f.writelines(lines[-DEBUG_LOG_MAX_LINES:])
    except Exception:
        pass


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except Exception:
        return

    event = data.get("hook_event_name")
    session_id = data.get("session_id")
    if not session_id:
        return

    if event == "PostToolUse":
        return  # não usado no Fase 1 — sai rápido

    ts = now_iso()

    if event == "SessionEnd":
        remove_state(session_id)
        log_debug(f"{ts} {session_id[:8]} SessionEnd -> removido")
        return

    prev = load_state(session_id)
    prev_state = prev.get("state")
    cwd = data.get("cwd", prev.get("cwd", ""))
    transcript_path = data.get("transcript_path", prev.get("transcript_path", ""))
    turn_started_at = prev.get("turn_started_at")
    detail = prev.get("detail", "")
    new_state = prev_state
    sound_to_play = None

    if event == "SessionStart":
        new_state = "idle"
        detail = ""

    elif event == "UserPromptSubmit":
        new_state = "working"
        detail = "prompt sent"
        turn_started_at = ts

    elif event == "PreToolUse":
        tool = data.get("tool_name", "")
        if tool == "AskUserQuestion":
            new_state = "waiting_question"
        else:
            new_state = "working"
        detail = tool

    elif event == "PermissionRequest":
        tool = data.get("tool_name", "")
        new_state = "waiting_question" if tool == "AskUserQuestion" else "waiting_permission"
        detail = tool

    elif event == "Notification":
        ntype = data.get("notification_type", "")
        if ntype == "idle_prompt":
            new_state = "idle"
            detail = ""
        elif ntype in ("permission_prompt", "elicitation_dialog", "elicitation_url_dialog"):
            if prev_state not in ("waiting_question", "waiting_permission"):
                new_state = "waiting_permission"
                detail = data.get("message", "")
        else:
            return  # auth_success, quota_* etc. — ignorado no Fase 1

    elif event == "Stop":
        duration_s = None
        if turn_started_at:
            try:
                duration_s = (datetime.now(timezone.utc) - parse_iso(turn_started_at)).total_seconds()
            except Exception:
                duration_s = None
        new_state = "done"
        detail = ""
        if prev_state != "done" and (duration_s is None or duration_s >= DONE_MIN_DURATION_S):
            sound_to_play = "done"

    elif event == "StopFailure":
        new_state = "error"
        detail = "turn failed"
        if prev_state != "error":
            sound_to_play = "error"

    elif event == "SubagentStop":
        return  # RF8: não conta como done nem toca som

    else:
        return

    # RF5: waiting_* toca mesmo em turno curto, uma vez por transição (RF3)
    if new_state in ("waiting_question", "waiting_permission") and prev_state != new_state:
        sound_to_play = new_state

    if sound_to_play == "done":
        play_sound(get_done_sound())
    elif sound_to_play:
        play_sound(SOUND_MAP[sound_to_play])

    save_state(session_id, {
        "session_id": session_id,
        "cwd": cwd,
        "transcript_path": transcript_path,
        "state": new_state,
        "detail": detail,
        "turn_started_at": turn_started_at,
        "updated_at": ts,
    })

    suffix = f" [som:{sound_to_play}]" if sound_to_play else ""
    log_debug(f"{ts} {session_id[:8]} {event} -> {new_state}{suffix}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_debug(f"{now_iso()} ERRO: {e}")
