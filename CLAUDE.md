# Claude Lights — memória do projeto

> Nome do projeto mudou de "Claude Status" para **Claude Lights** em 2026-09-09. Pasta continua `Widget claude code` (não renomeada, para não quebrar caminhos de scripts/hooks). Referências antigas a "Claude Status" em datas anteriores neste arquivo são históricas, não precisam ser reescritas.

## O que é
Indicador do Claude Code na barra de menus do macOS. Mostra se o Claude está trabalhando, terminou, travou esperando o usuário (permissão ou pergunta) ou deu erro, com sinal sonoro nos três últimos casos. Cobre várias sessões ao mesmo tempo (várias abas do app desktop, terminal, VS Code).

Dono: Henrique Karaim. Uso pessoal, máquina única (MacBook, macOS 26).

## Estrutura de pastas
Organização por natureza (decidido em 2026-09-09):
- `docs/` — documentação: `DISCOVERY.md` (levantamento técnico: eventos de hook, arquitetura, opções de tecnologia, riscos — ler antes de mexer em hooks) e `PRD.md` (requisitos do produto: estados, sons, comportamento visual, fases de entrega).
- `hooks/` — `hook.sh`, o script versionado que roda como hook do Claude Code (fonte de verdade; `install.sh` copia dali para `~/.claude/claude-status/`).
- `assets/` — recursos visuais do produto. Hoje só `spark.svg` (o ícone sparkle único, ver seção de design visual). Adicionado 2026-09-09.
- `app/` — reservado para a Fase 2: pacote SwiftPM do app da barra de menus (`Package.swift`, `Sources/`, ícones). Ainda não criado.
- `install.sh` — script de setup, fica na raiz (ponto de entrada).
- `CLAUDE.md` — este arquivo, na raiz por convenção do Claude Code. Contexto e decisões. Atualizar quando uma decisão mudar.

## Decisões tomadas (2026-09-09)
- **Fonte de eventos: hooks do Claude Code** em `~/.claude/settings.json`. Eles disparam em todos os clientes locais (desktop app, terminal, VS Code). Não usar parsing de transcript nem observar processos **para detectar estado** — só os hooks. *(Exceção adicionada depois no mesmo dia: o menu de uso/custo, seção 6.2b do PRD, lê o `transcript_path` sob demanda ao abrir o menu — isso não é detecção de estado, é um cálculo à parte, disparado só pelo clique do usuário, não contínuo.)*
- **Uso e custo no menu** (RF9-RF13 do PRD): sessão atual, hoje e últimos 7 dias. Tokens vêm de `usage` dentro do `.jsonl` de cada sessão (confirmado lendo um transcript real). Não existe custo gravado em lugar nenhum — todo valor em US$ é estimativa nossa via tabela de preço público, sempre rotulada como "estimado". Cálculo só roda ao abrir o menu (nunca em background), com cache de 60 s.
- **Comunicação hook → app: arquivos JSON**, um por sessão, em `~/.claude/claude-status/sessions/<session_id>.json`. Escrita atômica (tmp + mv). Não usar socket/HTTP na v1; o som deve funcionar mesmo sem o app aberto.
- **Som fica no hook** (via `afplay` com sons de `/System/Library/Sounds/`), não no app, na v1.
- **App da barra de menus em Swift nativo** (SwiftUI `MenuBarExtra`, SwiftPM, sem Xcode — só Command Line Tools estão instalados). SwiftBar é fallback aceitável para protótipo rápido.
- **Ordem de entrega**: Fase 0 (hook espião que só loga) → Fase 1 (só sons) → Fase 2 (app na barra) → Fase 3 (refinos). Não pular a Fase 0: a detecção de pergunta (`PreToolUse` com matcher `AskUserQuestion`) ainda não foi confirmada na prática.

## Mapeamento evento → estado (resumo)
| Hook | Estado | Texto na barra (inglês, decidido 2026-09-09) | Cor do sparkle |
|---|---|---|---|
| sessão sem atividade; `Notification/idle_prompt` | idle | *(nenhum, só ícone)* | cinza 30% opacidade |
| `UserPromptSubmit`, `PreToolUse` (tool ≠ AskUserQuestion) | working | "..." (três pontinhos, não a palavra — **a confirmar com o usuário**) | branco |
| `PreToolUse`/`PermissionRequest` com `tool_name == "AskUserQuestion"` | waiting_question 🔔 | "Waiting for reply" | amarelo |
| `PermissionRequest` com outro `tool_name` | waiting_permission 🔔 | "Waiting for permission" | amarelo |
| `Stop` (não `SubagentStop`) | done 🔔 (volta a idle após 8 s) | "Done" | branco |
| `StopFailure` | error 🔔 | "Error" | vermelho (**proposta minha, a confirmar**) |
| `SessionEnd` | remove a sessão | — | — |

Prioridade de agregação: error > waiting_* > working > done > idle. Com 2+ sessões no mesmo estado top, texto ganha contagem — mecanismo exato ("rodízio" entre sessões?) ainda **a confirmar com o usuário**, ver seção de design visual.

## Design visual do ícone (revisado em 2026-09-09 — mudança grande, substitui a versão anterior)
- **Um único ícone para todos os estados**: o sparkle em [assets/spark.svg](assets/spark.svg) (arquivo real do usuário, 4 pontas curvas, não mais os ícones variados por estado da versão anterior). Nunca muda de forma, só de cor.
- **Cores do sparkle** (únicas 3 confirmadas por mensagem direta do usuário): `waiting_question`/`waiting_permission` = **amarelo**; `working`/`done`/outros = **branco**; `idle` = **cinza a 30% de opacidade**. `error` não foi mencionado — vermelho é sugestão minha, não confirmada.
- **`idle` é o único estado só-ícone**, sem texto ao lado — deve ocupar o mínimo de espaço e ficar discreto, igual wifi/volume/bluetooth na barra do usuário (referência: captura de tela que ele mandou).
- **Os outros estados mostram sparkle + texto ao lado**, na mesma cor. Textos em **inglês** (decisão 2026-09-09: UI do produto em inglês; documentação do projeto continua em português).
- **Dois pontos ainda em aberto, aguardando o usuário confirmar**: (1) se "working" mostra literalmente "..." (três pontos, sem palavra) ou algo diferente; (2) o que acontece no texto da barra quando há mais de uma sessão em estados diferentes ao mesmo tempo ("outros: mais de uma sessão, vou dando o mesmo tempo" — minha melhor tentativa de leitura foi um rodízio de exibição entre sessões, não confirmado).
- Mockup usa Tabler só pros ícones das linhas do menu (que foram removidos a pedido do usuário); o sparkle em si já usa o SVG real, não mais uma aproximação desenhada à mão.
- Detalhe por sessão (qual projeto está em qual estado) fica no menu que abre ao clicar, não na barra.

## Convenções
- Scripts de hook em `~/.claude/claude-status/` (fora deste repositório) mas com cópia versionada em `hooks/` aqui, mais um `install.sh` que copia e mergeia o `settings.json`.
- Código do app em `app/` (pacote SwiftPM) quando a Fase 2 começar.
- Hooks sempre `"async": true` e sem dependência de Node ou Python quando possível (`PreToolUse` dispara dezenas de vezes por turno).
- **Textos de UI do produto em inglês** (mudou 2026-09-09 — antes era português). Documentação do projeto (este arquivo, PRD, discovery) continua em português, é só para o usuário. Identificadores de código sempre em inglês.
- Sons (atualizado 2026-09-09, escolhidos ouvindo os 14 sons reais, não por lista traduzida): **Ping** = pergunta e permissão (mesmo som, de propósito — usuário não quis diferenciar por som), **Glass** = concluído, **Sosumi** = erro.

## Cuidados conhecidos
- `Stop` não dispara em interrupção manual (Esc). Usar `idle_prompt` ou timeout próprio para sair de "working".
- `SessionEnd` pode não chegar ao fechar a janela do app desktop. Expirar sessões sem update há mais de 30 min.
- Eventos de subagentes chegam com `agent_id`. Tratar como "working" da sessão pai.
- Debounce no som de "done" em turnos curtos (< 10 s) para não irritar.

## Estado atual
- 2026-09-09: discovery e PRD escritos. Nenhum código ainda. Nenhum hook configurado em `~/.claude/settings.json`.
- 2026-09-09 (mesmo dia, depois): **Fase 0 instalada e confirmada ao vivo.**
  - [hooks/hook.sh](hooks/hook.sh) — hook espião (versionado no projeto, fonte de verdade).
  - [install.sh](install.sh) — copia o hook para `~/.claude/claude-status/hook.sh`, faz backup do `settings.json` antes de mexer e mescla o bloco de hooks sem apagar chaves existentes (idempotente: rodar de novo não duplica).
  - Eventos instalados: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Notification`, `Stop`, `StopFailure`, `SubagentStop`, `SessionEnd`. Todos `async: true`.
  - Log em `~/.claude/claude-status/events.log` (fora do projeto, não versionado).
  - **Confirmado nesta sessão, sem precisar reiniciar o Claude Code:**
    - o `settings.json` é lido a quente — hooks passaram a disparar no meio da sessão já em andamento, sem restart;
    - `$HOME` dentro do comando do hook expande corretamente (o hook roda via shell);
    - `session_id` é distinto por sessão e `cwd` vem correto — visto ao vivo com duas sessões simultâneas (esta pasta e a do Design System) gravando no mesmo log sem se misturar;
    - `PreToolUse`/`PostToolUse` chegam com `tool_name`, `tool_input` e (no Post) `tool_response` completo, incluindo `duration_ms` — dá para medir a duração do turno para o debounce do RF4 do PRD.
  - **Reversão**: `cp ~/.claude/settings.json.backup-20260909-160433 ~/.claude/settings.json` desfaz tudo.
- 2026-09-09 (análise do log, ~80 eventos / 2.0 MB): **descoberta que muda o desenho da Fase 1.**
  - `AskUserQuestion` **não gera nenhum sinal próprio**. Ele passa pelo mesmo mecanismo de permissão de qualquer tool: apareceu em `PreToolUse` e em `PermissionRequest` com `tool_name: "AskUserQuestion"`, e a `Notification` correspondente veio com `notification_type: "permission_prompt"` e `message: "Claude needs your permission to use AskUserQuestion"` — indistinguível de pedir permissão pra rodar um Bash, exceto pelo texto livre. **A `Notification` sozinha não carrega `tool_name`**, então para separar `waiting_question` de `waiting_permission` o app precisa olhar `PreToolUse`/`PermissionRequest` (que têm `tool_name`), não só a `Notification`. Atualizado em `docs/PRD.md` (seção 6.1 e risco #1).
  - `PermissionRequest` **disparou mesmo em `permission_mode: "auto"`** — mas só para `AskUserQuestion`. No mesmo período, 10 chamadas de Bash e 13 de Edit não geraram nenhum `PermissionRequest`. Ou seja: em modo `auto`, ações comuns são auto-aprovadas, mas uma pergunta ao usuário sempre precisa passar pelo prompt. Falta confirmar o comportamento em modo `default`/`ask`.
  - `SubagentStop` chega com o **mesmo `session_id` da sessão pai** (não precisa de lógica extra pra agrupar), mas nunca deve ser tratado como `done` — só o `Stop` da sessão principal fecha o turno.
  - Bônus: `UserPromptSubmit` carrega `session_title` (nome legível da sessão, ex. "Widget de status Claude Code para macOS") — melhor que derivar nome só do `cwd` para o menu da Fase 2.
  - **Ainda não observado**: `StopFailure`, `Notification/idle_prompt`, `Notification/elicitation_dialog`.
- 2026-09-09 (checagem seguinte, 217 eventos / 4.0 MB): `SessionEnd` confirmado — disparou 2x, em sessões diferentes (`Clinical Copilot IA Forum` e a pasta raiz do usuário), sempre com `reason: "other"`. Ainda não apareceu nenhum outro valor de `reason` (`clear`, `resume`, `logout`, `prompt_input_exit`) — na prática, pelo menos ao fechar a sessão dessas formas, o campo não diferencia o motivo. `StopFailure` segue em zero: nenhum erro de turno aconteceu ainda.
  - **Tamanho**: 80 eventos → 2.0 MB em menos de 1h de uso normal (edições e chamadas de browser tool pesam mais). Confirma o cuidado já anotado: não deixar a Fase 0 rodando por dias sem checar `du -h ~/.claude/claude-status/events.log`.
- 2026-09-09 (decisão): seguimos para a Fase 1 **sem** confirmar `StopFailure` em uso real — é o caso mais simples do mapeamento (igual estrutura do `Stop`), risco baixo.
- 2026-09-09: **Fase 1 implementada e testada.**
  - [hooks/state.py](hooks/state.py) — lógica real de estado + som (substitui o modo espião). [hooks/hook.sh](hooks/hook.sh) virou um wrapper fino que só repassa o stdin pra ele (mantido porque é o comando já registrado no `settings.json`, evita mexer lá de novo).
  - [install.sh](install.sh) atualizado: copia `hook.sh` **e** `state.py`, idempotente (rodar de novo não duplica hooks no `settings.json`, só redeploya os scripts).
  - Escreve `~/.claude/claude-status/sessions/<session_id>.json` por sessão (schema do PRD: `state`, `detail`, `turn_started_at`, `updated_at`) e toca som via `afplay` em background.
  - Log leve de depuração em `~/.claude/claude-status/debug.log`, rotacionado nas últimas 500 linhas (bem mais barato que o `events.log` da Fase 0, que parou de crescer e ficou como histórico congelado da investigação).
  - **Testado com payloads sintéticos** (sessão fictícia, sem afetar sessões reais): `waiting_question` toca Glass uma vez só mesmo com `PreToolUse` seguido de `PermissionRequest` no mesmo estado (RF3 ok); `waiting_permission` toca Ping; turno curto (< 1s) não toca som de concluído, turno longo toca Hero (RF4 ok); `StopFailure` toca Basso; `SessionEnd` remove o arquivo da sessão.
  - Confirmado ao vivo, sem reiniciar nada: as duas sessões reais que já estavam abertas (esta e a do Design System) passaram a ser rastreadas pelo novo hook automaticamente.
- 2026-09-09 (personalização dos sons): usuário quis trocar os 4 sons padrão. Tentei decifrar duas listas de nomes traduzidos que ele mandou em captura de tela (nenhuma batia com os nomes reais dos arquivos) e acabei inventando teorias de parentesco de palavra (`Hero→Heroine`, etc.) pra forçar uma correspondência — isso era confiança inventada, não verificação, e o usuário corretamente chamou de alucinação. **Lição**: quando o usuário manda uma lista de nomes que não existem nos arquivos reais, não tentar decodificar por dedução — tocar os sons reais direto (`afplay`, já confirmado que funciona no Mac dele) e deixar o usuário escolher pelo ouvido, sem intermediário de tradução.
  - Escolha final, por audição direta dos 14 sons reais: **Ping** = pergunta e permissão (mesmo som, de propósito), **Sosumi** = erro, **Glass** = concluído. `Hero` e `Basso` (sons originais da Fase 1) saíram de uso.
  - Testado de novo com sessões fictícias após a troca: os 4 sons tocaram certos, na ordem esperada. `hooks/state.py` e o instalado em `~/.claude/claude-status/` batem.
- 2026-09-09 (decisão de escopo): usuário quis pular o uso de alguns dias e ir direto para a Fase 2.
- 2026-09-09 (mockup do menu + rename do projeto): "Claude Status" virou **Claude Lights**. Menu revisado: sem ícones nas linhas, "Abrir ao iniciar" com check à direita (não à esquerda), uso/custo numa linha só, cabeçalho "Sessões", rodapé "Claude Lights v0.1".
- 2026-09-09 (ícone único + sparkle real + inglês): usuário simplificou de 5 ícones-por-estado para 1 ícone único (o sparkle) que só muda de cor; trouxe o SVG real (`assets/spark.svg`); decidiu que o texto de UI vira inglês. Detalhes e itens ainda em aberto na seção "Design visual do ícone" acima.
- 2026-09-09 (usuário confirmou os 3 pontos pendentes): "working" mostra só "···"; multi-sessão usa rodízio de fato; vermelho confirmado para `error`.
- 2026-09-09: **Fase 2 (app Swift) começou e já roda de verdade na barra.**
  - Pacote em `app/` (SwiftPM, `Package.swift`, macOS 13+): `SparkShape` (Shape traçado do `assets/spark.svg`), `Models` (estado + prioridade + cor + label em inglês), `SessionStore` (polling 0.5s de `~/.claude/claude-status/sessions/*.json`, expira sessão sem update há 30min — RF6, agrega por prioridade, rotaciona a cada 3s entre sessões empatadas), `UsageCalculator`/`UsageStore`/`Pricing` (lê tokens reais do `.jsonl` de transcript, preço buscado fresco em platform.claude.com/docs/en/about-claude/pricing em 2026-09-09, não de memória — RF11), `MuteManager` (escreve `mute_until`, lido pelo hook), `LoginItemManager` (SMAppService de verdade, não enfeite), `MenuBarIconView` + `SessionsMenuView` (a UI).
  - `hooks/state.py` ganhou `transcript_path` no arquivo de sessão (necessário pro cálculo de uso) e `is_muted()` antes de tocar som (necessário pro botão "Mute for 1 hour" funcionar de verdade, não só de mentira na UI).
  - **Escopo reduzido em uma coisa**: a seção 6.2b do PRD previa 3 recortes de uso (sessão atual / hoje / semana). Implementei só **hoje** e **últimos 7 dias** — "sessão atual" não tem um dono único e óbvio quando várias sessões estão abertas ao mesmo tempo (o design original não previa isso). Sinalizado no PRD e aqui; avisar o usuário.
  - `app/package.sh` empacota o binário como `.app` de verdade com `Info.plist` (`LSUIElement=true`) e assina ad-hoc.
  - **Dois bugs reais encontrados testando de verdade (não só compilando):**
    1. `NSApp.setActivationPolicy` dentro de `App.init()` derrubava o processo (`EXC_BREAKPOINT`, nil ao forçar unwrap de `NSApp`) — `NSApplication.shared` ainda não existe nesse ponto do ciclo de vida do SwiftUI. Corrigido movendo a chamada para dentro de um `.task` numa view.
    2. O sparkle (`SparkShape().fill(color)`) não aparecia na barra — ficava invisível, sem erro nenhum. `MenuBarExtra` trata `Shape` customizado no label como imagem "template" (monocromática, cor descartada). Corrigido renderizando o sparkle como bitmap via `ImageRenderer` com `isTemplate = false` explícito.
  - **Confirmado com screenshot real da barra do usuário**: o sparkle branco aparece certinho, do mesmo formato do `assets/spark.svg`, e o texto de rodízio bateu com o estado real das duas sessões abertas na hora (`Design System` e a própria sessão deste projeto, ambas "working").
  - **Não verificado ainda**: o conteúdo do menu que abre ao clicar. Não consegui clicar programaticamente (osascript sem permissão de acessibilidade) — precisa o usuário clicar e confirmar visualmente.
- 2026-09-09 (usuário testou e achou bug real no uso/custo): "Today" mostrava 5714M tokens / ~US$2318, quando o usuário sabia que usou ~1.5M na semana toda. **Dois bugs de verdade, achados só rodando com dado real, não em teste sintético:**
  1. Filtro por `mtime` do **arquivo inteiro**, não por linha. Um arquivo de sessão de dias atrás que recebeu uma linha nova hoje entrava com todo o histórico antigo contado como "hoje". Corrigido: cada linha do transcript tem seu próprio `timestamp`; agora filtro linha a linha, `mtime` do arquivo só serve de pré-filtro pra pular arquivo claramente antigo.
  2. Mesmo depois de corrigir (1), ainda sobrou 246M/~US$103 pra "hoje" — muito acima do esperado. Causa: uma chamada de API pode gerar **várias linhas no transcript**, uma por bloco de conteúdo (pensar, texto, tool-use), todas com o mesmo `requestId` e repetindo o total de tokens da chamada inteira. Eu somava cada linha como um turno novo, contando a mesma chamada 2-3x. Corrigido deduplicando por `requestId` (guardado num `Set`, só a primeira ocorrência conta). Validado com script Python independente antes de aplicar no Swift, batendo número por número.
  - Mesmo após as duas correções, "hoje" ainda pode parecer grande porque leitura de cache soma o contexto acumulado inteiro a cada turno — é uma quantidade bruta diferente de "quanto eu digitei/li". Não confirmado contra o Console real da Anthropic; avisar o usuário disso.
- 2026-09-09 (usuário pediu simplificações e uma feature nova, tudo aplicado):
  - **Sem rodízio multi-sessão**: a barra mostra só o estado de prioridade mais alta (erro > espera > trabalhando > concluído), nunca alterna entre sessões. Nome de projeto nunca aparece na barra, só dentro do menu.
  - **`working` voltou a ser a palavra** "Working…" (não mais "···" — o usuário mudou de ideia sobre a escolha anterior).
  - **Volume do som**: novo. `afplay -v` é multiplicador relativo ao volume do sistema, não absoluto (testado de verdade baixando o volume do Mac) — não dá pra garantir "sempre audível" só com isso. Implementado em duas camadas: (a) slider "Alert volume boost" 1x-10x em Settings, grava `~/.claude/claude-status/sound_volume`, lido pelo `state.py`; (b) toggle "Force max system volume", **desligado por padrão** porque é invasivo — quando ligado, o hook sobe o volume real do sistema pra 100% por ~2s antes de tocar e devolve ao valor anterior depois, afetando qualquer áudio tocando nesse instante. Os dois agrupados numa nova seção "Settings" do menu, junto com "Open at login".
  - Recompilado, reempacotado, relançado sem crash; confirmado por screenshot que a barra mostra "✦ Working…" sem nome de sessão.
- 2026-09-09 (espaçamento): usuário pediu 6px entre ícone e texto na barra (era 4px). Aplicado em `MenuBarIconView`, recompilado, sem crash.
- 2026-09-09 (bug real: "done" nunca saía da barra): o plano original (docs/PRD.md 6.1: "8s, depois idle") **nunca foi implementado** na Fase 2 — ficou só documentado desde o discovery, esquecido na hora de escrever o Swift. `state.py` grava "done" e o arquivo fica assim até o próximo evento de verdade mudar; nada contava os 8 segundos. Corrigido em `SessionStore.poll()`: ao ler cada sessão, se `state == .done` e `updated_at` tem mais de 8s, o app trata como `.idle` (na barra e na lista do menu, não altera o arquivo em disco). `SessionInfo.state` virou `var` pra permitir esse ajuste em memória.
  - **Não confirmado por captura de tela desta vez**: tentei isolar e testar (movendo temporariamente o arquivo da sessão "working" pra sobrar só uma sessão "done" antiga de 368s), mas a barra de menus não aparecia em nenhuma captura — provavelmente alguma janela em tela cheia escondendo a barra do sistema, não um bug do app. Arquivo de sessão real restaurado depois do teste. Pedir pro usuário confirmar ao vivo se o "Done" some sozinho depois de ~8s.
- 2026-09-09 (usuário achou o design de volume confuso, redesenhado): a primeira versão tinha dois controles independentes — um multiplicador relativo sempre ativo e um "force" separado sempre em 100%. Usuário perguntou "tenho que ativar o max e depois configurar a intensidade dele?", ou seja, esperava um modelo aninhado (um liga/desliga, e um valor que só importa quando está ligado). Redesenhado: **um único toggle "Force max volume"**; a porcentagem (`force_volume_level`, 50-100%) só aparece e só importa quando ele está ligado. Removido o multiplicador solto (`sound_volume`) inteiramente — sem ele, o som toca no volume normal do sistema, sem boost algum.
- 2026-09-09 (usuário removeu 3 itens do menu): uso/custo, "Mute for 1 hour" e "Open event log" saíram, "não acho que é necessário". Deletei o código de verdade (`UsageStore.swift`, `UsageCalculator.swift`, `Pricing.swift`, `MuteManager.swift`), não deixei morto no projeto. `state.py` perdeu `is_muted()`/`mute_until` — não tinha mais nenhuma UI que os usasse.
- 2026-09-09 (toggles de verdade): "Open at login" e "Force max volume" viram `Toggle` nativo do SwiftUI (`SwitchRow`), não mais checkmark num clique de linha — pedido do usuário, junto com uma explicação de uma linha embaixo do "Force max volume" dizendo exatamente o que ele faz e o efeito colateral.
- 2026-09-09 (testado de ponta a ponta, com medição real, não achismo): baixei o volume do sistema pra 15, liguei force com nível 90, disparei um som via hook, e confirmei lendo o volume do sistema em 3 momentos — foi pra 90 na hora do som, voltou pra 15 depois de alguns segundos sozinho. Bateu certinho. Volume do Mac restaurado ao valor original (38) depois do teste.
- **Estado atual do menu**: Sessions (lista) → Settings (Open at login, Force max volume + slider condicional) → rodapé "Claude Lights v0.1" → Quit. Nada de uso/custo, mute ou log por enquanto.
- **Próximo passo**: usuário confirma ao vivo a interface nova (toggles, explicação do force volume, menu sem os itens removidos) e se "Done" ainda some sozinho depois de ~8s (não confirmado por screenshot na rodada anterior). Considerar copiar pra `/Applications` quando estiver satisfeito.
- 2026-09-09 (alinhamento): toggle de "Open at login"/"Force max volume" estava grudado no texto em vez de ir pra borda direita — `Toggle(isOn:){Text}` não estica sozinho. Corrigido com `HStack + Spacer() + Toggle("", isOn:).labelsHidden()`, igual ao padrão que o slider "Force volume to" já usava. Removida uma indentação extra do slider que os toggles não tinham.
- 2026-09-09 (projeto virou repositório git, pronto pra compartilhar): usuário perguntou como escalar/compartilhar no GitHub.
  - **Trocado**: bundle ID de `care.marisa.claudelights` (citava o domínio da empresa) para `dev.henriquekaraim.claudelights` — decisão do usuário, feita antes de deixar público.
  - **Criados**: `README.md` (com screenshot real em `assets/demo-menubar.png`, instruções de instalação, customização), `LICENSE` (MIT, decisão do usuário), `.gitignore` (`app/.build/`, `.DS_Store`, backups do `install.sh`).
  - `git init` + primeiro commit (branch `main`), 21 arquivos.
  - **Falta**: criar o repositório de verdade no GitHub e dar push. `gh` CLI não está instalado aqui, nem Homebrew pra instalar — usuário precisa criar um repositório vazio em github.com (sem README/license/gitignore, já temos os nossos) e me passar a URL, ou instalar `gh`/Homebrew se preferir eu fazer via CLI depois.
  - Reempacotado com o bundle ID novo, testado sem crash.
- 2026-09-09 (repositório no ar): usuário criou o repo vazio em `github.com/henriquekaraim22/claude-lights`. Sem `gh`/Homebrew nesta máquina, gerei uma chave SSH nova (`~/.ssh/id_ed25519`, sem senha) e pedi pro usuário adicionar a pública em github.com/settings/ssh/new. Confirmado com `ssh -T git@github.com`, troquei o remoto pra SSH e dei push. Repositório público no ar, branch `main`, 2 commits.
- 2026-09-09 (toggle voltou atrás, depois voltou de novo): usuário testou o `Toggle` nativo ao vivo e achou ruim. Pediu um indicador redondo (bolinha preenchida/contorno) — implementado como `DotToggle`. Junto, o título de "Force max volume" foi pra 15pt (os outros ficaram em 13pt). **Usuário testou o dot e achou pior ainda** ("ficou muito ruim"), e reclamou especificamente do tamanho de título inconsistente entre as duas linhas. Voltou pro `Toggle` nativo, mas menor: `scaleEffect(0.7)` + `.frame(width: 30, height: 18)`, e `titleSize` virou fixo em 13pt pras duas linhas — removido o parâmetro de tamanho por linha do `SwitchRow`, não faz mais sentido ter. **Lição**: esse componente específico (indicador on/off no Settings) já passou por 3 versões numa tarde só porque cada mudança de aparência só ficou clara depois de rodar de verdade — vale ir com incrementos menores aqui em vez de trocar o mecanismo inteiro de novo sem necessidade.
  - Espaçamento entre título e subtítulo do "Force max volume" (6pt + 2pt de padding) e o texto encurtado de uma linha continuam da versão anterior, não foram mexidos nesta rodada.
  - Recompilado, reempacotado, sem crash.
- 2026-09-09 (app se auto-instala + gerador de DMG): usuário perguntou como criar um instalador de Mac pra mandar pra outras pessoas.
  - **`app/Sources/ClaudeLights/HookInstaller.swift`**: roda o `install.sh` (bundlado dentro de `Contents/Resources/`, junto com `hooks/hook.sh` e `hooks/state.py`) via `Process`, sem precisar do usuário abrir Terminal. `SessionStore.hooksInstalled` checa `hook.sh` existir a cada poll; quando falso, o menu mostra um banner "Claude Lights isn't connected to Claude Code yet" com botão "Set up integration".
  - `app/package.sh` atualizado pra copiar `install.sh` + `hooks/` pro bundle, mantendo a mesma estrutura relativa que o script já espera (não precisou mudar uma linha do `install.sh` em si).
  - **Testado de verdade, não só compilado**: movi `hook.sh`/`state.py` reais pra `/tmp` (simulando app recém-baixado), reempacotei, rodei o `install.sh` bundlado diretamente (mesma chamada que o `Process` faria) — reinstalou os dois arquivos idênticos à fonte, `settings.json` reconheceu os hooks já existentes (idempotente), e um evento de hook real funcionou depois. Ambiente real restaurado ao final, nada do usuário foi perdido.
  - **`app/make-dmg.sh`**: gera `app/.build/ClaudeLights.dmg` — pasta de staging com o `.app` + atalho simbólico pra `/Applications`, layout de ícones lado a lado via AppleScript no Finder (janela sem toolbar, ícones grandes, posicionados). Testado montando o `.dmg` de verdade e conferindo por screenshot.
  - **Pendência conhecida**: o app usa o ícone genérico cinza do sistema no Finder/DMG, nunca criamos um `.icns` customizado a partir do sparkle. Perguntar ao usuário se quer isso antes de considerar o instalador "pronto pra mandar pra alguém".
  - README atualizado com seção de instalação por `.dmg` (recomendada, sem terminal) e a opção via código-fonte/terminal como alternativa.
