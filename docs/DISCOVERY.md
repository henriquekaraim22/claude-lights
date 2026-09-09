# Discovery — Indicador do Claude Code na barra de menus do macOS

Data: 2026-09-09
Ambiente levantado: Claude Code 2.1.185 · macOS 26 (Darwin 25.5) · Swift 6.3 (Command Line Tools, sem Xcode) · Python 3.9.6 · Node 24 · sem SwiftBar/xbar/Hammerspoon · nenhum hook configurado hoje

---

## 1. O que você quer

Um ícone na barra de menus (menu bar, canto superior direito) que:

| Situação | Sinal visual | Sinal sonoro |
|---|---|---|
| Claude está trabalhando | ícone "ativo" (ex.: pulsando/azul) | nenhum |
| Claude terminou a resposta | ícone "concluído" (ex.: verde) por alguns segundos, depois neutro | sim |
| Claude travou esperando você (permissão ou pergunta) | ícone "atenção" (ex.: laranja) | sim, diferente do "terminou" |
| Claude deu erro (API caiu, etc.) | ícone "erro" (vermelho) | sim |

Bônus natural: funcionar com várias sessões abertas ao mesmo tempo (várias abas do app desktop), mostrando o estado mais urgente.

---

## 2. Como o Claude Code expõe esses eventos: **hooks**

O Claude Code tem um sistema de hooks configurado em `~/.claude/settings.json`. Cada hook é um comando shell que o Claude Code executa quando um evento acontece, recebendo um JSON no stdin. Fatos verificados na doc oficial (https://code.claude.com/docs/en/hooks):

- **Hooks em `~/.claude/settings.json` disparam em todos os clientes locais**: terminal, app desktop (aba Code), VS Code, JetBrains. Só não valem para sessões na nuvem (web). Ou seja: um único indicador cobre tudo que você usa.
- Existe a opção `"async": true`, então o hook não trava o Claude enquanto roda.
- Todo hook recebe `session_id`, `cwd`, `hook_event_name`, e (quando é subagente) `agent_id` / `agent_type`.

### Mapeamento evento → estado do widget

| Evento do hook | Quando dispara | Estado do widget |
|---|---|---|
| `UserPromptSubmit` | você enviou um prompt, antes do Claude começar | **trabalhando** |
| `PreToolUse` (qualquer tool) | Claude vai rodar uma ferramenta | **trabalhando** (mostra o nome da tool) |
| `PreToolUse` com matcher `AskUserQuestion` | Claude vai te fazer uma pergunta com opções | **esperando você — pergunta** 🔔 |
| `PermissionRequest` | apareceu o diálogo de permissão de uma tool | **esperando você — permissão** 🔔 |
| `Notification` / `permission_prompt` | permissão pendente há ~6 s sem resposta | reforço do estado acima (fallback) |
| `Notification` / `elicitation_dialog` | um servidor MCP abriu um formulário pra você | **esperando você** 🔔 |
| `Stop` | Claude terminou a resposta do turno | **concluído** 🔔 → volta a neutro depois de N s |
| `StopFailure` | o turno falhou (erro de API, etc.) | **erro** 🔔 |
| `Notification` / `idle_prompt` | Claude terminou há ~60 s e você não digitou | neutro/ocioso |
| `SessionStart` / `SessionEnd` | sessão abriu / fechou (`reason`: clear, resume, logout, prompt_input_exit, other) | registra / remove a sessão |

Observações importantes:
- `Stop` **não** dispara quando você interrompe com Esc/Ctrl+C. Se quiser cobrir esse caso, `idle_prompt` (60 s) ou um timeout próprio no app resolve.
- Não existe `notification_type` específico para "Claude fez uma pergunta". A pergunta é a tool `AskUserQuestion`, por isso o caminho é `PreToolUse` com matcher nela. **Isso precisa ser confirmado na Fase 0** (abaixo) rodando um hook "espião".
- Eventos de subagentes chegam com `agent_id` preenchido. Para o widget, basta tratá-los como "trabalhando" ou ignorá-los.
- Já existe uma opção nativa mais simples: `preferredNotifChannel` (`terminal_bell` ou notificação do sistema) e o próprio hook `Notification`. Ela não cobre "trabalhando" nem barra de menus, mas serve de fallback rápido.

---

## 3. Arquitetura proposta

```
 Claude Code (qualquer cliente)
   │  hooks (async) executam um script pequeno
   ▼
 ~/.claude/claude-status/hook.sh
   │  1) escreve ~/.claude/claude-status/sessions/<session_id>.json  (estado da sessão)
   │  2) toca som via `afplay` quando o estado é "concluído", "esperando" ou "erro"
   ▼
 App da barra de menus
   observa a pasta (FSEvents / DispatchSource) ou faz polling a cada 500 ms
   agrega todas as sessões → estado mais urgente vira o ícone
   menu dropdown lista cada sessão (pasta do projeto, estado, há quanto tempo)
```

Por que arquivo em vez de socket/HTTP:
- Se o app não estiver aberto, nenhum evento se perde; ao abrir ele lê o estado atual.
- Hook fica trivial (shell puro), sem dependência do app.
- O som pode ficar no hook, então mesmo sem o app rodando você já tem o aviso sonoro.

Alternativa válida: hook `type: "http"` fazendo POST em `localhost:PORT` do app. Mais "elegante", mas quebra quando o app não está rodando. Dá para evoluir para isso depois.

### Esquema do arquivo de estado (`sessions/<session_id>.json`)

```json
{
  "session_id": "abc123",
  "cwd": "/Users/henriquekaraim/Documents/Projetos Claude/Design System",
  "state": "working | waiting_question | waiting_permission | done | error | idle",
  "detail": "Bash: npm test",
  "updated_at": "2026-09-09T18:42:10Z"
}
```

### Lógica de agregação no app

Prioridade: `error` > `waiting_*` > `working` > `done` > `idle`.
Sessão sem atualização há mais de X min (ex.: 30) é descartada como "morta" (o `SessionEnd` nem sempre chega, ex.: fechar a janela do app).

### Sons (já existem no sistema, sem baixar nada)

`/System/Library/Sounds/`: Glass (pergunta), Ping (permissão), Hero (concluído), Basso (erro). Toca com `afplay /System/Library/Sounds/Hero.aiff`.

---

## 4. Opções de tecnologia para o app da barra de menus

| Opção | Esforço | Prós | Contras |
|---|---|---|---|
| **A. Swift nativo (SwiftUI `MenuBarExtra`, via SwiftPM)** — recomendada | médio (1–2 dias) | Swift 6.3 já instalado, sem precisar de Xcode; app leve, ícone animado, menu customizado, roda no login; resultado é um `.app` de verdade | precisa aprender/ajustar um pouco de AppKit/SwiftUI; empacotar como `.app` (LSUIElement) e assinar ad-hoc |
| B. SwiftBar/xbar plugin (shell script) | baixo (1–2 h) | instala via `brew install swiftbar`; plugin é um script que imprime o texto/emoji do ícone a cada 1 s | visual limitado (texto/emoji), depende de app de terceiro, sem animação de verdade |
| C. Python + `rumps` | baixo/médio | rápido de prototipar | Python 3.9 do sistema é velho; precisa `pyobjc`; empacotar (py2app) é chato |
| D. Electron/Tauri (Node) | alto | UI livre em HTML | pesado demais para um ícone; Tauri exige Rust |
| E. Hammerspoon (Lua) | baixo | menubar + sons + watchers de arquivo prontos | mais uma ferramenta pra instalar; visual limitado |

**Recomendação:** começar pela Fase 0 e 1 (só hooks, zero app) porque já entrega 70 % do valor (sons). Depois ir para A (Swift nativo). Se quiser ver algo na barra em 1 hora, B (SwiftBar) é o atalho e o hook é exatamente o mesmo, então nada se perde.

---

## 5. Plano por fases

### Fase 0 — Espião (30 min) — *entender antes de construir*
Configurar um único hook em **todos** os eventos relevantes que só faz `cat >> ~/.claude/claude-status/events.log`. Usar o Claude Code normalmente por algumas horas e conferir:
- `AskUserQuestion` realmente aparece em `PreToolUse`?
- `PermissionRequest` chega antes do `Notification/permission_prompt`?
- Como se comportam várias abas do app desktop (session_id distintos?).
- O que chega quando você interrompe com Esc.

### Fase 1 — Só som (1 h)
Hooks `Stop`, `StopFailure`, `PermissionRequest`, `PreToolUse[AskUserQuestion]` e `Notification` chamando `afplay` (async). Sem app nenhum. Já resolve "avisar quando termina / quando trava".

Exemplo de `~/.claude/settings.json` (trecho):

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh working" }] }],
    "PreToolUse": [
      { "matcher": "AskUserQuestion", "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh waiting_question" }] },
      { "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh working" }] }
    ],
    "PermissionRequest": [{ "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh waiting_permission" }] }],
    "Notification": [{ "matcher": "permission_prompt|elicitation_dialog", "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh waiting_permission" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh done" }] }],
    "StopFailure": [{ "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh error" }] }],
    "SessionEnd": [{ "hooks": [{ "type": "command", "async": true,
        "command": "~/.claude/claude-status/hook.sh ended" }] }]
  }
}
```

`hook.sh` lê o JSON do stdin (com `jq` ou `python3 -c`), extrai `session_id`, `cwd`, `tool_name`, grava o arquivo da sessão de forma atômica (escreve em `.tmp` e faz `mv`) e toca o som conforme o estado.

### Fase 2 — Ícone na barra (1–2 dias, Swift)
- Pacote SwiftPM com um executável SwiftUI usando `MenuBarExtra`.
- `NSApplication` com `setActivationPolicy(.accessory)` (sem ícone no Dock).
- `DispatchSource.makeFileSystemObjectSource` na pasta `sessions/` (ou `Timer` de 500 ms) → recarrega JSONs → calcula estado agregado → troca o `Image(systemName:)` (SF Symbols: `brain`, `hourglass`, `checkmark.circle`, `exclamationmark.triangle`) e a cor.
- Dropdown: lista de sessões (nome da pasta do `cwd`, estado, tempo), botão "Silenciar 1 h", "Abrir log", "Sair".
- Empacotar como `.app` (Info.plist com `LSUIElement = true`), assinar ad-hoc (`codesign -s -`), adicionar em Ajustes → Itens de Login.

### Fase 3 — Refinos
- Animação do ícone enquanto "trabalhando" (trocar frames a cada 300 ms).
- "Possivelmente travado": trabalhando há mais de N min sem nenhum `PostToolUse` → estado amarelo.
- Clicar na sessão foca a janela do app desktop (`open -a Claude`).
- Notificação nativa (`UNUserNotificationCenter`) além do som.
- Mover o som do hook para o app (evita som duplicado se um dia houver dois mecanismos).

---

## 6. Riscos e pontos em aberto

1. **Detecção de pergunta** depende de `PreToolUse` com matcher `AskUserQuestion`. Confirmar na Fase 0.
2. **Interrupção manual** (Esc) não gera `Stop`; o ícone ficaria em "trabalhando" até o `idle_prompt` (60 s) ou timeout próprio.
3. **Sessões fantasmas**: fechar a janela do desktop app pode não emitir `SessionEnd`. Mitigação: expirar sessões sem update há X min.
4. **Volume de eventos**: `PreToolUse` dispara dezenas de vezes por turno. Hook precisa ser barato (shell puro, sem Node) e `async`.
5. **Som repetido**: `Stop` também dispara em turnos curtos (ex.: você respondeu a uma pergunta e ele terminou em 2 s). Pode valer um debounce ("só toca se o turno durou mais de 10 s").
6. **Sem Xcode**: compilar SwiftUI via `swift build` funciona com Command Line Tools, mas não há Interface Builder nem Instruments. Para este app não faz falta.
7. **Subagentes/times**: eventos com `agent_id` podem chegar em rajada; tratar como "trabalhando" da sessão pai.

---

## 6.1 Projeto correlato: c9watch (checado em 2026-09-09)

https://github.com/minchenlee/c9watch — dashboard de monitoramento de sessões Claude Code/Codex/Cursor Agent. MIT, 128 estrelas, ativo (último commit em 2026-09-08). Confirma que a demanda é real, mas resolve um problema diferente do nosso:

| | c9watch | Claude Lights |
|---|---|---|
| Fonte do sinal | varredura de processo a cada 2s + parsing de JSONL em `~/.claude/projects/` | hooks do Claude Code, push instantâneo |
| Estados | 3: working / needs attention / idle | 6, com pergunta separada de permissão, `done` e `error` distintos |
| Som distinto por estado | não — só notificação nativa genérica quando precisa de atenção | sim (motivo original do pedido) |
| Stack / instalação | Tauri + Rust + Svelte; precisa Rust, Node 18+, Tauri CLI para compilar | Swift puro, só Command Line Tools |
| Escopo | dashboard completo: histórico de conversa, custo por dia/projeto/modelo, CLI JSON, acesso remoto via QR | indicador ambiente minimalista |

**Conclusão**: não substitui o plano — a varredura por processo é menos confiável que hook (depende do formato interno do JSONL, até 2s de atraso) e não tem som diferenciado por estado, que é o pedido original. Duas ideias dele valem incorporar depois, fora de escopo do v1: notificação nativa do macOS como complemento do som (não substituto), e um CLI com saída JSON para automação/scripting.

---

## 7. Próximo passo sugerido

Rodar a **Fase 0** hoje: criar `~/.claude/claude-status/hook.sh` no modo espião, adicionar os hooks no `settings.json`, usar o Claude normalmente e depois ler `events.log`. Com o log em mãos, a Fase 1 (sons) sai em menos de uma hora e a Fase 2 (Swift) já começa com o modelo de dados validado.

Referências:
- Hooks (referência): https://code.claude.com/docs/en/hooks
- Hooks (guia): https://code.claude.com/docs/en/hooks-guide
- Notificações de terminal / `preferredNotifChannel`: https://code.claude.com/docs/en/terminal-config
- SwiftUI `MenuBarExtra`: https://developer.apple.com/documentation/swiftui/menubarextra
- SwiftBar: https://github.com/swiftbar/SwiftBar
