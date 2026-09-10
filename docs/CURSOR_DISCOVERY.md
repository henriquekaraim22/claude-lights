# Discovery — integração com o Cursor

Data: 2026-09-10 · Status: **pesquisa por documentação apenas, nada verificado com uso real ainda**

## Por que este documento existe

O usuário pediu pra ampliar o Claude Lights para cobrir outras ferramentas de terminal com IA, além do Claude Code. Depois de pesquisar três candidatas (Codex CLI, Cursor, Copilot Chat nativo do VS Code), Cursor foi a escolhida pra começar. Mas **esta máquina não tem Cursor instalado**, e o usuário também não usa — diferente do Claude Code, onde eu mesmo sou o agente gerando os eventos reais, aqui não tem como testar sozinho.

Este documento existe pra não repetir o erro do início do projeto: construir lógica de estado em cima de suposição, sem confirmar com dado real. A lição registrada no `CLAUDE.md` principal ("quando o usuário manda algo que não bate com o real, verificar, não adivinhar") vale igual aqui.

## O que a documentação oficial diz (cursor.com/docs/hooks, checado em 2026-09-10)

- Cursor tem hooks de verdade, formato parecido com o do Claude Code: JSON no stdin, comando externo, `hooks.json` de configuração.
- Onde mora: `<projeto>/.cursor/hooks.json` (por projeto) ou `~/.cursor/hooks.json` (usuário, todo projeto) — usamos o de usuário, mesma escolha que fizemos pro Claude Code.
- Eventos relevantes pra detectar estado: `sessionStart`, `sessionEnd`, `beforeSubmitPrompt`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `subagentStart`, `subagentStop`, `stop`. (Existem mais — `beforeReadFile`, `afterFileEdit`, `afterAgentThought`, etc. — deixados de fora do espião de propósito: payload pesado, disparo muito frequente, sem ajudar a decidir estado.)
- **Diferença crítica de arquitetura**: os hooks do Cursor são **síncronos e bloqueantes** por padrão — o agente espera o script terminar (até o `timeout` configurado) antes de continuar. O Claude Code é assíncrono (`"async": true`). Isso muda o que é seguro construir: o script tem que ser rápido e sempre responder algo válido, ou arrisca travar/atrasar o uso real do Cursor.

## As perguntas que a documentação não responde (por isso o espião existe)

1. **Como saber que o usuário está de fato olhando pra uma caixa de diálogo pedindo permissão?** Não existe um evento tipo `PermissionRequest` do Claude Code. A permissão é um *valor de resposta* que o próprio hook pode devolver (`"permission": "ask"`) — não está claro se isso é a ÚNICA forma de permissão existir, ou se o Cursor tem um sistema de aprovação próprio, independente dos hooks, que um hook observador nunca vê disparar. Sem isso, não dá pra saber construir `waiting_permission` de verdade.
2. **Pergunta de múltipla escolha**: confirmado pela documentação (não é só falta de teste) que o Cursor não tem esse conceito — só permissão binária (permitir/negar/perguntar). Então `waiting_question` provavelmente **não existe** como estado distinto no Cursor, diferente do Claude Code. A confirmar se faz sentido ter esse estado na integração do Cursor.
3. **`postToolUseFailure` significa "o turno inteiro falhou"?** Esse evento dispara por chamada de ferramenta, não por turno. Uma ferramenta pode falhar e o agente continuar tentando outra coisa — não é óbvio que isso deveria virar o estado `error` (equivalente ao `StopFailure` do Claude Code) sem confirmar como isso se comporta na prática.
4. **O campo `status` do evento `stop`** pode indicar sucesso/erro do turno inteiro, mas a documentação não lista os valores possíveis.

## O que já existe, pronto pra quando houver acesso ao Cursor

- [`integrations/cursor/spy.py`](../integrations/cursor/spy.py) — só loga, nunca decide nada, sempre responde `{}` e sai rápido (crítico dado que os hooks bloqueiam). Testado isoladamente com payload válido, payload com campo gigante (trunca certo) e payload inválido (não quebra) — tudo sem precisar do Cursor de verdade.
- [`integrations/cursor/install.sh`](../integrations/cursor/install.sh) — mescla os 9 eventos no `~/.cursor/hooks.json` sem apagar o que já existir lá. Lógica de mesclagem testada isolada (preserva hook existente, idempotente, JSON válido no final) — só não rodei contra um `~/.cursor` de verdade, porque não existe nesta máquina.

## Próximo passo

Quando o usuário (ou alguém) tiver o Cursor instalado:
1. Rodar `integrations/cursor/install.sh`.
2. Usar o Cursor normalmente por um tempo, incluindo pelo menos uma ação que seria bloqueada por padrão (ex.: rodar um comando de shell que precise de aprovação).
3. Ler `~/.claude/claude-status/cursor-events.log` junto comigo antes de escrever qualquer lógica de estado — mesma disciplina do `docs/DISCOVERY.md` original.

Só depois disso faz sentido escrever um `state.py` equivalente pro Cursor e decidir se `waiting_question` existe nessa integração ou se o mapeamento fica só com 4 estados (idle/working/waiting_permission/done), sem o `error`, até a pergunta 3 acima ser respondida.
