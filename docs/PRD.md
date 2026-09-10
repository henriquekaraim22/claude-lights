# PRD — Claude Lights (indicador do Claude Code na barra de menus do macOS)

> Nome do projeto mudou de "Claude Status" para "Claude Lights" em 2026-09-09.

Versão 0.1 · 2026-09-09 · Autor: Henrique Karaim · Status: rascunho para validação

---

## 1. Problema

Quando o Claude Code executa uma tarefa longa, o usuário troca de janela (Figma, navegador, Slack) e perde o momento em que o Claude:
- termina a tarefa e fica ocioso esperando o próximo comando;
- para no meio pedindo permissão para rodar uma ferramenta;
- faz uma pergunta com opções e fica bloqueado até a resposta;
- falha por erro de API.

Hoje não há sinal fora da janela do Claude. O resultado é tempo morto: o Claude fica parado minutos esperando enquanto o usuário acha que ele ainda está trabalhando. Com várias sessões abertas ao mesmo tempo, o problema multiplica.

## 2. Objetivo

Dar ao usuário consciência periférica do estado do Claude Code sem precisar olhar para a janela dele: um ícone sempre visível na barra de menus do macOS e um som distinto para cada evento que exige ação.

**Resultado esperado:** tempo entre "Claude ficou esperando" e "usuário voltou" cai de minutos para segundos.

## 3. Não objetivos (v1)

- Não controla o Claude (não responde perguntas, não aprova permissões pelo widget).
- Não mostra o conteúdo da resposta nem da pergunta; só o estado.
- Não cobre sessões na nuvem (Claude Code web), que não executam hooks locais.
- Não é multiusuário nem multi-máquina.
- Não substitui as notificações nativas do sistema; pode complementá-las depois.

## 4. Usuário

Henrique, designer/PM que usa o Claude Code diariamente no app desktop (aba Code), às vezes com 2 a 4 sessões em paralelo, alternando com Figma e navegador. Quer saber "posso voltar?" sem trocar de janela.

## 5. Histórias de usuário

1. Como usuário, quero ver na barra de menus que o Claude está trabalhando, para não interromper à toa.
2. Como usuário, quero ouvir um som quando o Claude termina, para voltar na hora.
3. Como usuário, quero ouvir um som diferente quando o Claude precisa de mim (permissão ou pergunta), porque isso é mais urgente que "terminou".
4. Como usuário, quero ouvir um som de erro quando o turno falha, para não achar que ele está trabalhando.
5. Como usuário com várias sessões, quero que o ícone mostre o estado mais urgente e que o menu liste cada sessão com o nome do projeto.
6. Como usuário em reunião, quero silenciar os sons por um período sem desligar o widget.
7. Como usuário, quero que o widget abra sozinho no login e nunca apareça no Dock.

## 6. Requisitos funcionais

### 6.1 Estados e sinais

| Estado | Gatilho (hook do Claude Code) | Ícone | Texto na barra (inglês) | Cor do sparkle | Som | Duração |
|---|---|---|---|---|---|---|
| `idle` | sessão aberta sem atividade; `Notification/idle_prompt` | sparkle | **nenhum** — só ícone | cinza, 30% opacidade | não | até novo evento |
| `working` | `UserPromptSubmit`, `PreToolUse` (`tool_name` ≠ `AskUserQuestion`) | sparkle | "Working…" | branco | não | até `Stop`, `StopFailure` ou pergunta/permissão |
| `waiting_question` | `PreToolUse`/`PermissionRequest` com `tool_name == "AskUserQuestion"` | sparkle | "Waiting for reply" | amarelo | **Ping** | até próximo evento da sessão |
| `waiting_permission` | `PermissionRequest` com qualquer outro `tool_name` | sparkle | "Waiting for permission" | amarelo | **Ping** | até próximo evento da sessão |
| `done` | `Stop` (não `SubagentStop`) | sparkle | "Done" | branco | **Glass** | 8 s, depois `idle` |
| `error` | `StopFailure` | sparkle | "Error" | vermelho (**confirmado** pelo usuário 2026-09-09) | **Sosumi** | até próximo evento da sessão |

> **Sons escolhidos por audição direta em 2026-09-09** (não por lista traduzida — ver CLAUDE.md para o retrospecto de como isso quase deu errado): pergunta e permissão tocam o mesmo som, `Ping`, de propósito — o usuário decidiu que não precisa diferenciar por som, só por texto/ícone no menu.

> **Revisão de design 2026-09-09 (mudança grande, substitui a versão com 5 ícones diferentes):** o usuário simplificou para **um único ícone**, o sparkle real em [`assets/spark.svg`](../assets/spark.svg), que nunca muda de forma — só de cor. Só `idle` fica com o ícone sozinho, sem texto — deve ocupar o mínimo de espaço e não competir com os ícones de sistema (padrão visto na própria barra do usuário: wifi/volume/bluetooth são monocromáticos e quietos). Todos os outros estados mostram sparkle + texto ao lado, na mesma cor. Texto e cor aparecem juntos, nunca só um dos dois.
>
> **UI do produto em inglês** (decisão 2026-09-09): os textos da barra e do menu são em inglês; a documentação do projeto (este PRD, o discovery, o CLAUDE.md) continua em português.
>
> **Fechado 2026-09-09** (substitui a versão anterior, que ainda tinha 2 pontos em aberto): `working` mostra a palavra "Working…", não os três pontos usados antes. **Sem rodízio nem contagem multi-sessão na barra** — o usuário decidiu que a barra mostra só o estado de prioridade mais alta entre todas as sessões, ponto, nunca alternando e nunca citando qual sessão é. Nome de projeto/sessão só aparece dentro do menu, nunca na barra. RF2 abaixo atualizado de acordo.

> **Atualizado 2026-09-09, confirmado com dados reais (Fase 0):** não existe um evento próprio para "pergunta". `AskUserQuestion` passa pelo mesmo mecanismo de permissão de qualquer ferramenta — a `Notification` que chega diz literalmente *"Claude needs your permission to use AskUserQuestion"*, com `notification_type: "permission_prompt"`, igual a qualquer outra. A única forma de diferenciar pergunta de permissão comum é olhar o campo `tool_name` dentro de `PreToolUse` ou `PermissionRequest` — a própria `Notification` não carrega `tool_name`, só `message` (texto livre) e `notification_type`, então **não dá para confiar só na `Notification`** para separar os dois estados; ela serve como reforço/fallback, não como fonte primária. Isso também mudou o RF3 abaixo: o hook do app precisa manter uma tabela local de `tool_name` mais recente por sessão para interpretar corretamente a `Notification` quando ela chegar sozinha (ex.: depois de 6 s sem resposta).

Regras:
- **RF1** Cada sessão (`session_id`) tem seu próprio estado.
- **RF2** O ícone (e o texto ao lado, quando houver) mostram só o estado de prioridade mais alta entre todas as sessões (`error > waiting_* > working > done > idle`). **Sem rodízio, sem contagem, sem nome de sessão na barra** (decisão final 2026-09-09) — com 2+ sessões empatadas no topo, mostra o mesmo texto que mostraria com uma só. Detalhe de qual sessão é qual só aparece no menu (RF14).
- **RF3** Som toca uma vez por transição de estado, nunca em repetição periódica.
- **RF4** Som de `done` só toca se o turno durou mais de 10 s (evita ruído em respostas curtas). Valor configurável.
- **RF5** `waiting_*` deve tocar mesmo que o turno seja curto.
- **RF6** Sessão sem atualização há mais de 30 min é considerada encerrada e sai da lista.
- **RF7** `SessionEnd` remove a sessão imediatamente.
- **RF8** Eventos com `agent_id` (subagentes) contam como `working` da sessão pai e não tocam som. *(Confirmado 2026-09-09: `SubagentStop` chega com o mesmo `session_id` do pai — não precisa de chave extra para agrupar — mas não deve nunca ser tratado como `done`; só o `Stop` puro da sessão principal fecha o turno.)*

### 6.2 Menu (clique no ícone)

Revisado em 2026-09-09 com mockup (estrutura inspirada no menu do Granola que o usuário mostrou: linhas de conteúdo agrupadas, divisor, meta-info discreta, divisor, sair). Textos em inglês (UI do produto), sem ícone líder em nenhuma linha — só texto.

- Cabeçalho discreto "Sessions" acima da lista.
- Lista de sessões ativas: nome do projeto, estado, tempo desde a última atualização, última ferramenta usada quando em `working`.
- Cabeçalho discreto "Settings".
- Toggle "Open at login" — `Toggle` nativo do SwiftUI (mudou 2026-09-09, era checkmark num clique de linha).
- Toggle "Force max volume" com explicação de uma linha embaixo (ver 6.3).
- Rodapé discreto "Claude Lights v0.1" (nome do projeto + versão, mesmo estilo do cabeçalho "Sessions").
- Item "Quit".

> **Removido 2026-09-09 a pedido do usuário** ("não acho que é necessário"): resumo de uso e custo do dia, "Mute for 1 hour" e "Open event log" saíram do menu. O código correspondente (`UsageStore`, `UsageCalculator`, `Pricing`, `MuteManager`) foi deletado do projeto, não deixado morto — se algum dia voltar a fazer sentido, reconstruir do zero com os dados reais confirmados no histórico deste documento (seção de riscos/achados) em vez de reaproveitar o código antigo sem reconferir.

### 6.3 Sons

- Usar os sons nativos em `/System/Library/Sounds/` na v1; nenhum download.
- Se o app não estiver aberto, o hook ainda toca o som (o som mora no script do hook na v1).

**Forçar volume máximo (redesenhado 2026-09-09), seção "Settings" do menu, junto com "Open at login":**
- **RF14** `afplay -v` é um multiplicador **relativo** ao volume atual do sistema, não um valor absoluto — confirmado testando de verdade (baixar o volume do Mac e comparar `-v` alto vs baixo; `man afplay`/`afplay -h` não documentam nada em contrário). Não existe garantia de "sempre audível" só com isso — só forçar o volume real do sistema garante.
- **RF15** **Um único toggle "Force max volume"**, desligado por padrão (é invasivo, precisa ser opt-in explícito, não default). A versão anterior tinha dois controles independentes (um multiplicador sempre ativo + um force sempre-100% separado) — o usuário achou confuso ("tenho que ativar o max e depois configurar a intensidade?") e pediu o modelo aninhado que ficou: um liga/desliga, e um valor que só existe e só importa quando ligado.
- **RF16** Quando ligado, um slider "Force volume to" (50%-100%, default 100%) aparece logo abaixo, só nesse estado. O hook sobe o volume real do sistema pra esse valor (`osascript set volume output volume <nível>`) por ~2s antes de tocar o som e devolve ao valor anterior depois — afeta qualquer áudio tocando nesse instante (chamada, música), não só o alerta. Copy no menu deixa isso explícito.
- **Testado de ponta a ponta com medição real 2026-09-09**: volume do sistema baixado pra 15, `force_max_volume=1` e nível 90, som disparado via hook — volume real leu 90 durante o som e voltou pra 15 sozinho alguns segundos depois. Bateu exatamente com o esperado.

**Som de "Done" configurável (adicionado 2026-09-10):**
- **RF17** Só o som de `done` pode ser trocado pelo usuário. `waiting_question`/`waiting_permission` (Ping) e `error` (Sosumi) continuam fixos, sem UI nenhuma pra eles — decisão explícita do usuário.
- **RF18** Seletor customizado (não um `Picker`/menu nativo do SwiftUI — esse não dispara hover nas opções, é controlado pelo NSMenu do sistema): linha "Done sound" que expande numa lista das 14 opções reais. Hover em qualquer opção toca ela na hora (via `NSSound`, preview da UI, não o `afplay` do hook); clique seleciona e recolhe a lista.
- **RF19** Persistido em `~/.claude/claude-status/done_sound` (nome sem extensão); `state.py` valida contra a lista de 14 antes de usar, cai no padrão `Glass` se o arquivo não existir ou tiver algo inválido.

### 6.4 Instalação

- Script `install.sh` que: cria `~/.claude/claude-status/`, copia o `hook.sh`, mergeia o bloco `hooks` em `~/.claude/settings.json` sem sobrescrever o que já existe, e faz backup do arquivo original.
- Script `uninstall.sh` que reverte.
- App distribuído como `.app` assinado ad-hoc, arrastado para `/Applications`.

## 7. Requisitos não funcionais

- **RNF1** O hook não pode atrasar o Claude: sempre `"async": true`, tempo de execução < 50 ms, sem Node/Python (shell + `jq` ou só shell).
- **RNF2** O app usa < 30 MB de memória e ~0 % de CPU quando ocioso (observação de arquivo por evento, não polling agressivo; se polling, ≥ 500 ms).
- **RNF3** Funciona no app desktop, terminal e VS Code sem configuração adicional (hooks vivem em `~/.claude/settings.json`).
- **RNF4** Não requer Xcode completo para compilar (Command Line Tools + SwiftPM).
- **RNF5** Sem rede. Tudo local.
- **RNF6** Escrita do arquivo de estado é atômica para o app nunca ler JSON pela metade.

## 8. Solução técnica (resumo; detalhes em DISCOVERY.md)

```
Claude Code ──hooks async──▶ ~/.claude/claude-status/hook.sh
                                 ├─ grava sessions/<session_id>.json
                                 └─ afplay <som>  (quando o estado exige)
App SwiftUI (MenuBarExtra) ──observa sessions/──▶ agrega ──▶ ícone + menu
                             │
                             └─ ao abrir o menu (sob demanda, não contínuo):
                                lê transcript_path da sessão atual +
                                varre ~/.claude/projects/**/*.jsonl (hoje/semana)
                                → soma usage → aplica tabela de preço → US$ estimado
```

Esquema do arquivo de sessão:

```json
{ "session_id": "...", "cwd": "/caminho/do/projeto",
  "state": "working|waiting_question|waiting_permission|done|error|idle",
  "detail": "Bash: npm test", "turn_started_at": "ISO-8601", "updated_at": "ISO-8601" }
```

## 9. Fases de entrega

| Fase | Entrega | Critério de pronto | Estimativa |
|---|---|---|---|
| 0 — Espião | hook que só loga todos os eventos em `events.log` | log de um dia de uso confirma: `AskUserQuestion` em `PreToolUse`, `PermissionRequest` antes do `permission_prompt`, `session_id` distintos por aba | 30 min + 1 dia de uso |
| 1 — Sons | `hook.sh` completo + `install.sh`; sem app | ouvir Glass ao terminar, Ping ao travar, Sosumi em erro, em sessão real | 1 h |
| 2 — Barra | app Swift com ícone por estado, menu de sessões, silenciar, sair | ícone reflete estado em < 1 s após o evento, com 2+ sessões abertas | 1–2 dias |
| 3 — Refinos | animação em `working`, "possivelmente travado" (working > N min sem `PostToolUse`), notificação nativa, abrir no login, clique foca o app | uso por uma semana sem falso positivo irritante | contínuo |

## 10. Métricas de sucesso

- Tempo entre evento `waiting_*`/`Stop` e o próximo `UserPromptSubmit` da mesma sessão (medível pelo próprio log). Meta: mediana < 30 s em sessões em que o usuário estava em outra janela.
- Zero sons falsos por dia (som tocando com o Claude ainda trabalhando).
- Widget ativo em 100 % dos dias de uso após a Fase 2 (se o usuário desligar, falhou).

## 11. Riscos e perguntas abertas

| # | Risco / pergunta | Mitigação |
|---|---|---|
| 1 | ~~`AskUserQuestion` pode não passar por `PreToolUse` como as outras tools~~ | **Resolvido 2026-09-09**: passa por `PreToolUse` e por `PermissionRequest`, com `tool_name: "AskUserQuestion"`. Não gera `Notification` própria — usa `permission_prompt` igual a qualquer tool, então a `Notification` sozinha não diferencia pergunta de permissão comum (ver nota na seção 6.1) |
| 1b | `PermissionRequest` pode nunca disparar em `permission_mode: "auto"` | **Parcialmente resolvido**: disparou para `AskUserQuestion` mesmo em modo `auto` (10 Bash + 13 Edit no mesmo período não dispararam nada — só a pergunta). Falta confirmar o comportamento em modo `default`/`ask` |
| 2 | Interrupção manual (Esc) não gera `Stop`; ícone fica em `working` | timeout próprio (ex.: 3 min sem evento → `idle`) e `idle_prompt` |
| 3 | Fechar janela do desktop app pode não emitir `SessionEnd` | **Parcialmente confirmado 2026-09-09**: `SessionEnd` disparou em 2 sessões reais, mas sempre com `reason: "other"` — o campo não diferencia o motivo do fechamento na prática observada. Manter a expiração de 30 min (RF6) como rede de segurança, já que não dá para confiar 100% no evento chegar |
| 4 | Volume de `PreToolUse` em turnos longos | hook barato e async (RNF1) |
| 5 | Som duplo se o app também tocar | v1: som só no hook; v2 decide onde mora |
| 6 | Sem Xcode: sem Interface Builder/Instruments | não necessário para MenuBarExtra |
| 7 | Estado `done` + Claude começa outro turno em 1 s (usuário digitou rápido) | `UserPromptSubmit` sobrescreve para `working` e cancela o timer de 8 s |
| 8 | Qual ícone/estilo visual? SF Symbols ou ícone próprio? | v1: SF Symbols; ícone próprio na Fase 3 se fizer sentido |

## 12. Fora de escopo, mas anotado para depois

- Responder pergunta / aprovar permissão direto pelo menu.
- Mostrar preview da pergunta no menu.
- ~~Histórico de turnos e duração (dashboard de uso)~~ — **entrou no escopo em 2026-09-09** como resumo de uso/custo (ver 6.2b), mas só um resumo agregado por sessão/dia/semana, não um navegador de histórico de conversas completo (isso continua fora, como o c9watch tem).
- Suporte a Linux/Windows.
- Integração com Focus modes do macOS.
