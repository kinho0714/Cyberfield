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
