# Integração — cyberfield_missao_2026-10-29.patch

Data: 29/10/2026 · Base: `qwen-transfer-post-visual-2026-10-03` (`d54af98`)

## 1. Por que o patch falhava na master

O patch foi gerado sobre `d54af98`, a ponta de `qwen-transfer-post-visual-2026-10-03`.
Os 11 blobs de origem declarados no cabeçalho (`index abc..def`) coincidem **somente**
com essa branch.

| Base testada | `git apply --check` |
|---|---|
| master (`63a31ef`) | 11 erros |
| qwen-transfer-2026-10-02 | 10 erros |
| android-temp-environment-2026-10-05 | 5 erros |
| **qwen-transfer-post-visual-2026-10-03** | **0 erros** |

Não havia conflito real de código: a master simplesmente não tem os arquivos que o
patch altera (`scene/audio_service.gd`, `ui/localization.gd` e catálogos, HUD oficial etc.).
As três branches são descendentes lineares da master (0 commits atrás). O conteúdo de
`android-temp` já está todo em `post-visual`, exceto 2 PNGs privados removidos de propósito.

## 2. Commits

1. `Apply cyberfield_missao_2026-10-29 patch onto post-visual base`: aplicação literal.
   Os 16 blobs resultantes conferem byte a byte com o cabeçalho do patch.
2. `Add generated Lower City concept assets and fix preview crop`: correções desta integração.
3. Este relatório.

## 3. Funcionalidades integradas

| Área | Arquivos | O que faz |
|---|---|---|
| HUD / fim de run | `ui/run_end_presentation.gd` (novo), `scene/run_debug_hud.gd` | Cartão com título colorido (perdida/concluída), 6 blocos de dados, linhas por jogador e intro animada. O `RunDebugHUD` continua dono dos dados, sinais e foco; o `Title` antigo fica oculto como fallback. |
| Áudio | `scene/audio_service.gd` | Política: SFX de ação e UI silenciados por padrão (`ACTION_SFX_ENABLED := false`). Trilha, chuva, cidade e trovão mantidos. Reversível via `action_sfx_enabled = true`. |
| Menu | `scene/animated_menu_background.gd`, `scene/main_menu_alive.gd` | Parallax lento no fundo (overscan de 1,8%, mouse só fora do mobile, chuva num plano mais próximo); barra de foco animada nos itens com seleção nativa. |
| Geração procedural | `scene/biomes/biome_generator.gd` | Os *guard rails* (antes só física, invisíveis) ganham anteparo visível com borda iluminada e faixas de alerta. |
| Localização | `ui.en.tres`, `ui.pt_BR.tres`, `ui_catalog.json` | 7 chaves novas. Os 3 catálogos ficam com 131 chaves idênticas, sem duplicatas. |
| Lower City (experimental) | `scene/experimental/*`, `tools/experimental/lower_city_concept.py`, `assets/experimental/lower_city_concept/*` | Cena isolada (F6 no editor), **não carregada pelo jogo**. Arte original gerada por código. |
| Testes | 3 testes ajustados + `tests/run_end_presentation_smoke_test.gd` | Cobrem a política de áudio, os anteparos e o adaptador do fim de run. |

## 4. Correções feitas na integração

- **Referência ausente:** `lower_city_concept.gd` carrega 13 PNGs que o patch (só texto)
  não trazia. Gerei os PNGs com o script do próprio patch; a saída é determinística
  (duas execuções, SHA-256 idênticos).
- **Prévia do gerador:** o sprite do inimigo era recortado com 128 px, mas a folha tem
  4 quadros de 104 px, e aparecia uma lasca do quadro seguinte. Corrigido para
  `width // 4` e escala 0,8, iguais aos da cena Godot. Os PNGs de runtime não mudaram.

## 5. Verificação

### Executado

| Verificação | Resultado |
|---|---|
| `git apply --check` nas 4 bases | só `post-visual` aplica limpo |
| Hashes de destino dos 16 arquivos | 16/16 conferem com o patch |
| Sintaxe GDScript (gdtoolkit), 11 `.gd` tocados | 11/11 OK |
| Sintaxe GDScript, projeto inteiro (128) | 123 OK. As 5 falhas são lambdas de uma linha, válidas no Godot 4 mas não suportadas pelo gdtoolkit, e já existiam na base. |
| Parse de `.tscn`/`.tres` (godot_parser) | `lower_city_concept.tscn`, `main.tscn` e os 2 `.tres` OK |
| Localização | en = pt_BR = json (131 chaves), sem duplicatas |
| Integridade de `res://` | **0 referências quebradas novas.** As 12 existentes são pré-existentes (ver riscos). |
| Testes Python (12) | Resultado idêntico ao da base: 8 passam, 4 falham com as mesmas 9 asserções. |
| Testes Python em modo de asserção suave | 34 falhas na base e 34 na integração, nas mesmas asserções. Nenhum contrato que passava foi quebrado. |
| Prévia visual da Lower City | Inspecionadas 3 posições de câmera, renderizadas pelo script (simulação, não captura do Godot). |

### Não executado

- **Os 60 testes GDScript headless** (`godot --headless --script res://tests/...`),
  incluindo `run_end_presentation_smoke_test.gd`, `phase5_exploration_smoke_test.gd` e
  os dois testes de áudio alterados. Motivo: o Godot não está instalado no ambiente e a
  política de rede bloqueia o download (HTTP 403).
- **Execução real do jogo**: HUD, menus, áudio e a cena Lower City não foram vistos
  rodando no Godot. A validação desses itens foi apenas estática.

Para rodar localmente:

```
godot --headless --path . --script res://tests/run_end_presentation_smoke_test.gd
godot --headless --path . --script res://tests/mega_pass_priority1_smoke_test.gd
godot --headless --path . --script res://tests/mega_pass_arsenal_sfx_ui_smoke_test.gd
godot --headless --path . --script res://tests/phase5_exploration_smoke_test.gd
godot --headless --path . --script res://tests/focused_stabilization_input_audio_test.gd
godot --headless --path . --script res://tests/final_post_phase7_1_hotfix_smoke_test.gd
```

## 6. Riscos

1. **Pré-existente, grave: o repositório não é autocontido.** Cinco scripts fazem
   `preload` de arquivos que nunca foram versionados (são áudios do menu e texturas
   privadas, com direitos não verificados segundo `assets/audio/menu/SOURCES.md`):
   `audio_service.gd`, `painter.gd`, `trap_chest.gd`, `attribute_chest.gd` e
   `biome_loot_placeholder.gd`. Num clone limpo esses scripts não compilam. Isso vale
   tanto para a base quanto para a integração.
2. **Mudança de comportamento intencional:** todos os SFX de ação e UI ficam mudos por
   padrão. Confirmar que é a política desejada para a release.
3. **Navegação por gamepad no fim de run:** os botões passam a ficar lado a lado
   (`HBoxContainer`). Navegar entre eles agora é esquerda/direita, não cima/baixo.
4. **Testes de "contrato congelado" desatualizados:** 4 testes Python já falhavam na
   base. Eles comparam hashes de funções e trechos literais de passes anteriores.
5. **`docs/pass3_baseline/`** guarda uma cópia de cerca de 1,6 MB do código-fonte, que
   pode ser confundida com o código vivo em buscas e edições.
6. Os PNGs da Lower City são gerados por script. Se o script mudar, regenere-os
   (`python3 -I tools/experimental/lower_city_concept.py`).

## 7. Próximos passos

1. Rodar os testes GDScript acima e abrir a cena `lower_city_concept.tscn` (F6) num
   ambiente com Godot 4.7 e os assets privados.
2. Decidir o risco 1: versionar os assets (se os direitos permitirem), trocar `preload`
   por `load` com fallback, ou documentar o pacote privado como pré-requisito.
3. Confirmar a política de áudio (risco 2) e a navegação do fim de run (risco 3).
4. Atualizar ou aposentar os 4 testes de contrato congelado.
5. Depois disso, decidir se `post-visual` mais esta integração devem ir para a `master`.
