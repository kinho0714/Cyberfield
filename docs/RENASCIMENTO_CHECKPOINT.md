# Renascimento — checkpoint de progresso

Leia isto antes de qualquer coisa (regras em `CLAUDE.md`). Atualize ao fim de cada etapa.

## Estado (30/10/2026)
- Branch de trabalho: `renascimento-integracao-2026-10-30` (parte de `ad419a7` = R2).
- R2 instalado e testado fisicamente pelo usuário: reconstrução NÃO alcançada
  (ambientes vazios/pretos, visuais antigos, elementos novos invisíveis).
- Godot 4.7.2 oficial (autorizado pelo usuário, SHA-512 conferido) no scratchpad
  `godot/`. Cópia de teste em `run/proj` com **stubs só de teste** dos 6 recursos
  privados (magenta = textura do pintor antigo). Nada disso vai para o repositório.
- Captura real: `run/cap.sh <nome> [w h]` → sincroniza o repo, importa e roda
  `tests/renascimento_capture.gd` (menu, hub 0–3, 4 estágios, panorâmica, profundidade,
  combate) com Xvfb + Mesa. Relatório `RENASCIMENTO_REPORT` por captura.
- Alcance de cenas/scripts/PNGs: `run/reach.py` (resolve class_name e caminhos fixos;
  caminhos com `%s` precisam de prova no motor).

## Achados comprovados no motor
1. Abaixo da rua (poços/descidas) o fundo virava preenchimento quase preto → corrigido:
   plano `under` repete até a base da tela (todos os biomas + chefe).
2. Anteparas do gerador (colunas teal) → pele de parede + acento por bioma.
3. `CombatFx.shake`: `get_meta(nome, null)` gerava erro → corrigido.
4. Heavy usa as folhas reconstruídas (comprovado por probe).
5. CombatFx comprovado: golpe 2 nós, dash 3, morte 5 + capturas. (O "0" inicial era
   erro do teste: câmera ainda na posição anterior / contagem fora do `Main`.)
6. UI comprovada: tema e fonte Pixelify aparecem em pausa, inventário, Meta-Lab,
   atributos e seleção de modo.
7. Smoke tests reais: biome_visual_theme, combat_fx, hub_house_stages e
   casa_jhon_stage0 passam no Godot 4.7.2.

## Próximo passo
- Pedir ao usuário captura do ponto exato do "preto" no aparelho (não reproduzido fora
  dos módulos abaixo da rua e da arena do chefe).
- Laboratório (vazio), arena do chefe (escura), transições, lobby LAN/resultado,
  perfis de efeito. Restos antigos dependem de decisão do usuário (painel de
  depuração do hub, título provisório do chefe).

## Alpha 0.5.0 — Missão 01: personagens (branch `dev/visual`, base `alpha-0.5.0` = e95e361)
- Jogáveis reais: Jhon, Jackson, Kai, Spark (`entities/player_character_visual.gd`).
  Não existe "Kayle" no projeto.
- `tools/visual/character_refine.py` reconstrói as 44 folhas a partir da tag
  `alpha-0.5.0` (idempotente): limpeza de fragmentos/rótulos/linhas, poça do idle
  removida e reassentada, contorno de luz no acento do personagem (Jhon ciano,
  Jackson âmbar, Kai turquesa, Spark amarelo), "caído" na proporção de pé.
  Tamanhos e grade inalterados.
- Sombra de contato em `PlayerCharacterVisual` (filha, atrás do sprite; oculta no
  ar/parede). Sem mudança de gameplay.
- Evidência: `tests/character_lineup_capture.gd` (todos os quadros na cena real
  `player.tscn`, com cápsula e linha do chão; relata pés vs. chão) + captura de gameplay.
- Menu: `scene/fx/menu_bridge_traffic.gd` — tráfego na ponte elevada do master
  (1 Node2D, draw_rect, sem textura/shader; MÍNIMO desliga, REDUZIDO = metade).
  Comprovado por captura no fluxo real (`main.tscn`, 7 carros, movimento entre quadros).
- Push para `origin/dev/visual` bloqueado: 403 (app GitHub sem acesso de escrita).
- Pendente: redesenho real de poses (proporções do revive do Spark, borda cortada do
  hurt do Jhon), escala 1.5× não inteira do sprite (distorce pixels), menu/ponte.

## Missão arsenal/cyberwares 01/11 (branch local `claude/cyberfield-patch-integration-7ek1p2`)
- Base `dev/visual` (`ce3fae3`). Noturna 31/10 preservada em commit WIP na branch local
  `visual-noturna-2026-10-31`; branch local antiga de 29/10 renomeada para
  `backup/claude-patch-integration-2026-10-29`. Sem push.
- Relatório: `docs/ARSENAL_CYBERWARE_2026-11-01.md`. Teste: `tests/arsenal_expansion_smoke_test.gd`.
- Achado no motor: o cenário dos biomas está na camada 1 (não 2) — granadas atravessavam o chão.
- Achado no motor: `ShapeCast2D` para no 1º corpo; varredura de impacto usa consulta de área.
- Próximo: playtest físico (toque nos botões F/G, legibilidade do HUD a 20:9, balanceamento),
  loadout por cliente na LAN, poses de personagem com armas.
## Missão noturna 31/10 (branch local `visual-noturna-2026-10-31`, SEM commit)
- Relatório: `docs/NOTURNA_2026-10-31.md`. Âncoras de quadro (pivô/flip) nos 4 personagens,
  Laboratório mais denso, arena do chefe mais clara. Tudo validado no Godot; aguardando
  aprovação do usuário para commit em `dev/visual`.

## Missão Visual 02 — cenários (01/11, mesma branch, sem push)
- Casa reconstruída em escala (Jhon ≈ 47 px na arte 2×), andar de cima em corte acima da
  laje (y < 316 no mundo, fora do alcance do pulo duplo), janela viva `scene/fx/hub_window_view.gd`.
- Noturna 31/10 trazida para esta branch (cherry-pick do WIP).
- `under_layer` e `lab_mid` com variedade; `scene/fx/transition_fx.gd`; HUD refinado.
- Pendências: "LowerCityMid" não reproduzível aqui; escalada de parede nas bordas do hub
  pode subir acima da laje (visual); toque/legibilidade no Android a confirmar.

## Jhon Design B (02/11, mesma branch, sem push)
- Importador genérico `tools/visual/character_sheet_import.py` (config por personagem; originais
  fora do repositório, SHA-256 registrado). Saída `assets/players/jhon/design_b/` (160×100, 1,0×).
- `PlayerCharacterVisual`: caminho de "conjunto oficial" dirigido por dados
  (`entities/character_animation_sets.gd`); Jackson/Kai/Spark seguem no caminho antigo.
- Projétil: colisão na altura de sempre; só o desenho sai do cano (hitboxes dos inimigos ~30 px).
- Testes antigos que fixavam escala 1,5/11 animações do Jhon foram atualizados para o novo contrato.
- Próximo: playtest Android; folhas para revive/parede/mergulho e RELOAD_RIFLE correta.

## Missão P0+P1 (02/11, mesma branch, sem push) — relatório `docs/MISSAO_P0_P1_2026-11-02.md`
- Base exata `4798b78` (árvore `3ce08be2…`) = `b3bf6ab` do aparelho (`cyberfield-jhonb-2026-11-02`).
- P0-A terminal de blueprints: lista longa sem rolagem por toque (emulação de mouse desligada) →
  abas + `ui/touch_scroll_router.gd` (toque ao soltar, arrasto rola, recorte respeitado).
- P1-A baús trap: inimigo entrava na árvore antes de ser posicionado → dano de queda fantasma.
  Corrigido no baú e com re-ancoragem do spawn no 1º tick (`Enemy`/`RangedEnemy`).
- P1-B: `scene/weapons/weapon_loot_table.gd` (sequência por estágio, afinidade de bioma, baús com
  arma, raridade por estágio de verdade) + 8 armas novas. Geração byte a byte idêntica.
- P0-B: `scene/dev/dev_mode.gd` + `dev_mode_panel.gd`; perfil de teste isolado
  (`<save>_dev_sandbox.json`); opção nas Configurações; botão DEV no HUD; F9.
- P1-C: escada de serviço nos poços do caminho crítico; `scene/interactables/dash_passage.gd`
  + alcova secreta por bioma; saída A alterna bioma, B aprofunda/atalho; rótulos reais.
- Testes novos: blueprint_menu_touch, trap_chest_spawn, weapon_loot_distribution, dev_mode,
  exploration_routes. Entrega: patch + instalador Termux testado em clones (scratchpad).
- Próximo: playtest físico (toque no terminal/painel Dev, botão DEV, passagens de dash, escada
  de serviço, rótulos de saída), balancear as armas novas, arte própria da passagem de dash.

## Missão mundo/saves — 03/11/2026 (Codex, Termux)
- Missão externa lida integralmente; Bíblia de Lore encontrada e consultada.
- Base real `dbffe33`; branch nova `codex/mundo-saves-marcos-0-1-2026-11-03`.
- Marco 0: auditoria commit `803fa10`, relatório `docs/mundo_saves/MARCO_0.md`.
- Marco 1: implementação PARCIAL em `scene/persistence/`, integração de campanhas
  solo e rollback DEV. Relatório `docs/mundo_saves/MARCO_1.md`; evidência estática
  `docs/mundo_saves/validation.json`. Não homologado/concluído.
- Sem Godot executável neste ambiente: NÃO executar nem afirmar resultados dos
  smoke tests novos. Próximo passo é rodar store/session/DEV no motor 4.7.2 e corrigir
  a integração; depois validar Android/Windows. Não avançar ao Marco 2 ainda.
- Saves não escritos nesta execução; seis assets privados não rastreados preservados
  com hashes verificados. Sem reset, limpeza, checkout forçado ou push.

### Marco 1 — hotfix de compilação após primeiro teste Android
- Relato do proprietário: Godot Android 4.7.2 não inferiu `restored` em
  `campaign_controller.gd:118` (acesso dinâmico a `game.mode_selected`).
- Corrigido com `bool` explícito e conversão do operando; revisão dos `:=` dos
  scripts novos, dicionários do controlador tipados e resultado DEV tipado.
- Evidência local: `docs/mundo_saves/validation_inference_hotfix.json`.
- Compilação/funcionalidade Android ainda aguardam validação. Não iniciar Marco 2.


### Marco 1 — ciclo básico aprovado pelo proprietário no Godot Android 4.7.2
- Evidência manual relatada: criou/carregou campanha, movimentou o personagem,
  encerrou completamente a execução, reabriu e usou CONTINUAR. Progresso observado
  e posição restaurados corretamente. TESTADO EM DISPOSITIVO e APROVADO PELO
  PROPRIETÁRIO somente para esse cenário; não atribuir execução de smoke tests.
- Método de encerramento, hub/bioma e campos específicos do progresso não foram
  detalhados. Não inferir teste de crash, force-stop, combate ou todos os atributos.
- Relatório `docs/mundo_saves/MARCO_1.md` atualizado com matriz de evidências e testes
  pendentes: DEV, backups/corrupção/versões, A/B/exclusão/legado, cobertura da run/
  morte/antiduplicação, gatilhos de autosave, suspensão, Windows e desempenho.
- Marco completo ainda em validação parcial. Não avançar ao Marco 2. Nesta revisão,
  somente documentação alterada; saves, código e assets permanecem preservados.

### Expansão integrada autorizada — base real 2fafe47
- Nova missão permite Marcos 1–5, inclusive partes independentes enquanto testes
  externos estiverem pendentes. Revoga a pausa anterior no Marco 2.
- M1: store/session/DEV executados no Godot oficial 4.7.2 Linux ARM64 headless via
  PRoot no temporário, projeto e dados isolados. Todos failures=0. Relatório
  `docs/mundo_saves/expansao/MARCO_1_RODADA.md`; avisos de recursos na saída registrados.
- Proprietário confirmou também recuperação de interrompida e independência de A/B.
- Próximo: catálogo/hierarquia/distribuição reservada e exploração persistentes.

### Expansão — mundo/procedural
- Catálogo versionado e hierarquia mundo/estado/cidade/município/bairro/sala,
  distribuição de sete slots reservados persistida, visão pública filtrada.
- Seeds separadas, grafo de rotas por bairros e integração incremental no gerador;
  seed de área preservada na recuperação; UI de mundo/seleção no hub.
- world_persistence, region_routes e campaign_session integrados: failures=0 no
  motor headless isolado. Relatório `expansao/MARCOS_2_3.md`. Android/Windows e
  progressão geográfica completa permanecem pendentes.

### Expansão — perfis e protótipo privado (continuidade final)
- M1: d1f79b0. Mundo/rotas: 7e622a6. Perfil/cliente/UI: 0c21fc8.
- Perfil local offline persistente, dados públicos/privados separados, contatos
  não verificados, bloqueios e backup; sem autenticação online fictícia.
- Relay de jogo WSS loopback e cliente Godot reais; convites-capacidades expiráveis,
  quatro assentos, autoridade host, revisão, reconexão e caches separados.
- Sockets TLS e um host Godot + três clientes Python foram testados; não são quatro
  jogadores/APKs. Nenhuma publicação/túnel. Sem conta/backend de amigos configurado.
- Regressão: DEV iniciado no hub não altera contador/seed/áreas reais; baú não
  reaparece, transição/prévia e derrota/recompensa foram incluídas no teste de sessão.
- Relatório geral `docs/mundo_saves/expansao/RELATORIO_RODADA.md`, segurança e roteiro
  Android no mesmo diretório. Próximo: validação física, avisos de cleanup, ponte
  de gameplay WSS, backend e implantação autorizada. Não declarar marcos completos.
