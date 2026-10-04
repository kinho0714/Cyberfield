# CYBERFIELD — Visual / Asset / UX Refinement Pass 3

Data: 03/10/2026. Workspace: `C:\Users\vinic\Documents\Cyberfield_Visual_Work`.

## 1. Status

Implementação segura e validação disponível concluídas. **Resultado ambiental parcialmente limitado pelos assets; aprovação física completa pendente.** Não declarar Casa/Cidade como arte final aprovada. O trabalho anterior foi preservado, sem reconstrução, commit, push, reset, restore, clean, stash ou reaplicação do Pass 2. Nenhum patch foi gerado neste passe.

## 2–4. Baseline, branch e HEAD

- Branch: `qwen-transfer-post-visual-2026-10-03`.
- HEAD: `724ea8c2b36528f1e822263fe3aaa9c0204e96fa` (inalterado).
- Baseline: working tree físico inicial, incluindo as alterações válidas/untracked do Pass 2, não apenas HEAD.
- Evidência: `pass3_baseline/branch.txt`, `head.txt`, `status.txt`, `preexisting.diff`, `files.json` e cópias dos arquivos de texto em `source/`.
- A retomada conferiu status, diff e `git diff --check` antes de editar. O estado atual foi usado como source of truth.
- Inventário incremental em relação à baseline física: `pass3_execution_inventory.json`. Não confundir o diff total contra HEAD com alterações exclusivas do Pass 3.

## 5. Auditoria de assets

Detalhes completos: `PASS3_ENVIRONMENT_ASSET_AUDIT.md`, `pass3_asset_metrics.json` e `pass3_region_metrics.json`. Dez PNGs e 34 recortes distintos auditados; todos os recortes dentro dos respectivos atlas.

- Válidos em uso limitado: interiores estruturais retangulares da Casa; FAR da Cidade como vista finita, pequena e sem repetição seamless.
- Problemáticos: mobiliário/portas/props da Casa, bancadas e armazenamento; atlas estrutural e de props da Cidade, com translucidez ampla e resíduos de contorno.
- Reference-only: MID e NEAR da Cidade, com títulos técnicos embutidos. Sheet inteiro da oficina e sheet inteiro de interativos também não são sprites finais isolados.
- Dependentes de substituição/arte limpa: recortes com matte amplo, principalmente plantas/prateleiras, portas, mobília, máquinas e saídas. A origem em concept e o antigo `runtime_ready` do manifest não garantem alpha correto.
- Não foi aplicada remoção automática por cor, máscara arbitrária, nova geração visual ou alteração dos PNGs oficiais. Todos os hashes de PNG da baseline foram preservados.

## 6. Casa de Jhon

Preservados 2560×768, cena física, colisões, piso funcional, câmera, P1/P2, portal, terminal e anchors. Reduzidos cabeamento industrial repetido e uma coluna divisória na área doméstica; serviços industriais concentrados na oficina/técnica. Mantida a composição ocupada do Pass 2.

**Limite:** os mattes continuam visíveis, comprovados por render. Não foi possível tornar esses recortes sprites finais limpos sem arriscar apagar material legítimo ou inventar arte. A Casa ainda não atinge integralmente a leitura visual de casa antiga/base clandestina. Lista de substituições está na auditoria.

## 7. Cidade Baixa e telegraph

- MID/NEAR retirados completamente do script de apresentação. Busca nas cenas/scripts confirma ausência de referências a esses dois PNGs no runtime.
- FAR mantido a tamanho nativo em uma variante entre três, sem tratar uma faixa `NON_REPEATABLE` como background contínuo.
- Removido o painel retangular artificial que acompanhava as três faixas sobrepostas.
- Geração, RNG, módulos, rotas, shafts, saídas, colisões, spawn, inimigos, recompensas e progressão preservados.
- Teleporter cyan: apresentação e lógica permanecem byte a byte iguais à baseline.
- Telegraph Ranged: linha termina na distância visual do alvo, limitada ao alcance já existente. Direção ofensiva, travamento, alcance de ataque, dano, projectile e autoridade não foram alterados.

**Limite:** texturas estruturais/props da Cidade têm muitos pixels parcialmente transparentes; isso também contribui para o ambiente escuro. Máquinas, saída, repetição e vazios ainda exigem revisão de arte/composição após sprites limpos. Não foi criado cenário estático ou preenchimento artificial.

## 8. HUD e minimapa

Portrait usa o personagem real. Corrigida a causa principal: frame com centro opaco agora é desenhado antes da cabeça/torso. Fundo de apoio e contraste discreto melhoram leitura; arquivo do personagem não foi alterado. Dados e loop de HUD existentes preservados.

Minimapa recebeu padding de 20px e superfície interna de contraste. Fog, descoberta, rooms, dados, marcadores funcionais e navegação preservados. Mudança visual isolada em `biome_minimap.gd`, facilmente reversível por revisão das duas alterações de apresentação.

## 9. Low HP

- Acima de 50%: sem overlay e sem processamento da animação.
- Em 50%: intensidade 0,025, início discreto.
- Até 0%: crescimento contínuo até intensidade máxima 0,38.
- Até 25%: preservado também o acento crítico no frame/HP.
- Pulso suave de ±8% da intensidade base; frequência aumenta discretamente com perigo.
- Overlay ignora input, mantém a camada 39 e para de processar quando oculto. Sem shader novo, flash agressivo, alteração de HP/dano/cura/downed ou rede.

## 10–11. Menu, pré-run, Pause, Settings e foco

Menu/pré-run/lobby que usam `main_menu_alive.gd` compartilham o adaptador visual de botões: normal legível, cyan para hover/foco, pressed coerente e painel mais opaco. Preservados navegação, callbacks, bloqueios de início, dificuldade, seleção local/LAN e hotfix de dropdown.

Eliminada a segunda seleção desenhada pelo código antigo nos controles com novo estilo. O StyleBox de foco separado fica vazio, enquanto o estado visual selecionado ocupa o estilo normal durante o foco lógico. Teclado/gamepad continuam habilitados; sliders mantêm indicação ativa. Tabs e slots preservam o estado de seleção/equipamento ao sair do foco. A nova aparência não é um segundo retângulo sobreposto.

## 12. Localização

Recursos nativos `Translation` PT-BR/English, registrados centralmente em `ui/localization.gd`. Catálogo com 124 mensagens em `assets/localization/ui_catalog.json`; recursos `.tres` reproduzíveis por `docs/build_pass3_translations.ps1`.

Idioma em Settings/Jogo; aplica imediatamente e persiste em `[ui] language` no config existente. Default PT-BR; valores não suportados caem para PT-BR. Labels/botões usam tradução automática do Godot; textos compostos migrados usam `tr()` e notificações de mudança, sem polling novo.

Cobertura prioritária: menu/pré-run, Pause, categorias/controles de Settings, Inventory/Backpack, armas/raridades/tipos apresentados, resumo da sessão/run, títulos principais de HUD e mensagens estáticas principais de lobby LAN. `COMMON` aparece como `COMUM` em PT-BR.

**Cobertura parcial deliberada:** textos de debug, mensagens de erro/transporte LAN já formatadas no backend e outras telas fora do passe ainda podem permanecer em PT/EN. Nenhum ID, path, resource name, action name, save key ou networking key foi traduzido. Novas mensagens de UI devem entrar no catálogo. Baseado no sistema oficial [TranslationServer](https://docs.godotengine.org/en/4.6/classes/class_translationserver.html), validado no Godot instalado 4.7.2.

## 13–14. Inventory, Backpack e sistemas novos

Inventory continua exibindo/equipando os dois slots reais do backend, com definição e atributos das três armas existentes preservados. Não foi imposto um novo contrato melee/ranged ao loadout atual. Dois espaços de gadget são representativos/vazios; nenhum gadget funcional ou sprite de arma foi inventado.

Backpack é uma aba separada com modelo mínimo em `RunBackpack`, filho do RunManager criado pela UI. Exibe dinheiro sujo **compartilhado real** da equipe e itens por participante; carga inicia vazia. Snapshots são cópias defensivas. API futura aceita IDs/quantidades fornecidos por um coletor autorizado e bloqueia escrita por clientes LAN; nenhum coletor fictício foi conectado.

O modelo limpa carga ao preparar run/voltar a hub/menu e sinaliza mudanças. UI atualiza ao abrir, trocar aba, mudar idioma ou receber sinais de dados; não há loop próprio por frame. Regras de extração, morte/dinheiro, economia, crafting, armazenamento e replicação de novos itens não foram implementadas. O dinheiro existente é somente lido, não movido ou duplicado no modelo.

Layout mede o mínimo real e reage a mudanças de tamanho: equipamento e Mochila foram capturados sem cortar o botão Voltar a 1280×720.

## 15–19. Contratos

| Contrato | Resultado |
| --- | --- |
| Gameplay alterado? | **NÃO** em regras, dano, movimento, combate, cura/downed/revive/rewards. Apenas apresentação do telegraph e nova fundação/UI de cargo. |
| Networking alterado? | **NÃO** em protocolo, autoridade, schema ou fluxo. Pontos visuais do telegraph continuam usando o canal de apresentação existente. Novo cargo não tem replicação conectada. |
| Procedural alterado? | **NÃO**. Gerador e RunManager byte a byte iguais à baseline. |
| Touch alterado? | Controles de gameplay/joystick/multitouch intactos. Settings ganhou o dropdown de idioma pelo mesmo fluxo modal; aba Mochila usa navegação/touch existentes. Arbitragem scroll/slider preservada. |
| Save/config alterado? | Somente chave aditiva `[ui] language` no ConfigFile de settings. Zoom, áudio, escala touch e chaves desconhecidas preservados por teste. Save/profile de progressão não foi alterado. |

Hashes confirmados para 14 arquivos protegidos em `pass3_frozen_contracts.json`: RunManager, RoomManager, LanSession, gerador, teleporter, cena física da Casa, player, Enemy/HeavyEnemy, touch controls/cena, joystick, botão mobile e project.godot.

## 20–22. Arquivos desta execução

Modificados em relação à baseline física (14; alguns já eram untracked/alterados pelo Pass 2):

- `entities/RangedEnemy.gd`
- `scene/casa_jhon_presentation.gd`
- `scene/biomes/lower_city/lower_city_presentation.gd`
- `scene/biomes/biome_minimap.gd`
- `scene/inventory_ui.gd`
- `scene/local_settings.gd`
- `scene/main_menu_alive.gd`
- `scene/mode_select.gd`
- `scene/network/lan_lobby.gd`
- `scene/pause_menu.gd`
- `scene/pause_menu.tscn`
- `scene/run_debug_hud.gd`
- `ui/gameplay_hud_presentation.gd`
- `ui/menu_panel_presentation.gd`

Criados para implementação/validação:

- `assets/localization/ui_catalog.json`, `ui.pt_BR.tres`, `ui.en.tres`
- `scene/run_backpack.gd`, `ui/localization.gd`
- `tests/visual_pass3_smoke_test.gd`, `visual_pass3_capture.gd`, `pass3_translation_diagnostic.gd`
- `docs/PASS3_ENVIRONMENT_ASSET_AUDIT.md`, este relatório
- `docs/build_pass3_translations.ps1`, `audit_pass3_regions.ps1`
- `docs/pass3_asset_metrics.json`, `pass3_region_metrics.json`, `pass3_changed_from_baseline.json`, `pass3_execution_inventory.json`, `pass3_parse_results.json`, `pass3_frozen_contracts.json`
- `docs/pass3_baseline/` (evidência inicial/cópias; `.gdignore` evita carregar o projeto arquivado)
- `docs/pass3_captures/` (oito renders de menu, Settings PT/EN, Casa, equipamento, Mochila, Cidade e Low HP)
- `docs/pass3_testdata/` (configs/perfil isolados dos testes; sem usar o config pessoal como fixture)
- Logs `docs/pass3_*.log`; inventário exato está em `pass3_execution_inventory.json`.

Removidos: **nenhum arquivo original**. PNGs/títulos inadequados continuam arquivados; só dependências de runtime foram retiradas. Alterações/fontes/assets do Pass 2 não foram descartados.

## 23–26. Validação, resultados e falhas

Godot real: **4.7.2.stable.official.ed1daf0bf**. Parser nativo `--check-only`: 15 scripts novos/alterados, exit 0 e zero erros de script. Referências literais de recursos conferidas. Formatação: 124 entradas, zero divergências nos parâmetros `%d/%s/%f`. `git diff --check` passou.

| Teste | Resultado |
| --- | --- |
| `visual_pass3_smoke_test.gd` | PASS: thresholds e ativação/desativação do Low HP, locale imediato/persistente, config preservado, dropdown modal de idioma, cargo vazio/dinheiro real, cópias defensivas/reset de cargo, preview sem equipar, telegraph limitado, layout dentro da tela. |
| `casa_jhon_stage0_smoke_test.gd` | PASS: dimensões, anchors/interação e geometria física. |
| `official_visual_integration_smoke_test.gd` | PASS: personagens/enemies/projectiles. |
| `ranged_enemy_rebuild_v2_smoke_test.gd` | PASS. |
| `pass6_dropdown_modal_smoke_test.gd` | PASS. |
| `phase8_lan_lobby_touch_smoke_test.gd` | PASS: lobby/touch/host/seleção/dropdown. |
| `android_touch_hud_modal_hotfix_smoke_test.gd` | PASS em simulação Godot no PC. |
| `phase8_final_consolidation_smoke_test.gd` | PASS. |
| `phase4_stats_hud_smoke_test.gd` | PASS. |
| `visual_pass3_capture.gd` | PASS com OpenGL Compatibility/Radeon RX 5500 XT; oito PNGs inspecionados. |
| `pass6_hotfix2_scroll_smoke_test.gd` | Falha na linha 34 também na baseline isolada: assume todos os controles na mesma página rolável; Pass 2 já usa categorias. Não alterado para ocultar falha. |
| `phase8_multi_seed_smoke_test.gd` | Emite marcador OK, mas produz erros de RunManager fora da SceneTree também na baseline. Não contado como PASS limpo. |

Baseline isolada foi copiada a diretório temporário, importada e executada; o workspace físico nunca foi revertido. Logs comparativos: `pass3_scroll_baseline.log`, `pass3_seed_baseline.log` e logs correspondentes atuais.

Falhas ambientais preexistentes: certificado raiz do sistema não pôde ser lido; editor headless inicialmente sem permissão para salvar editor settings e Android build-tools indisponíveis. Sem relação com código do passe. Testes novos usam fixtures no workspace para evitar escrita em config pessoal.

Python executável funcional não está disponível (alias WindowsApps não executa). Suíte Python/gdtoolkit/godot-parser NÃO executada; parser nativo e smoke tests reais foram usados. Suites históricas de Pass 2 contêm hashes/expectativas que congelam arquivos de apresentação agora deliberadamente alterados; não foram reescritas para alegar que essa suíte passou.

Novas falhas de script nos checks/smoke tests finais: **nenhuma observada**. Durante desenvolvimento, testes novos encontraram ordem do portrait, sincronização do dropdown e tamanho do painel; corrigidos e revalidados. Capturas atuais substituem as anteriores.

## 27–28. Riscos e itens não implementados

Dependência principal: produção/reextração aprovada de sprites ambientais com alpha correto. Os arquivos atuais ainda impedem aprovação visual final da Casa e limitam a Cidade. Não há solução automática segura de matte comprovada nesta execução.

Aparência de foco, contraste, vignette/pulso, viewport reduzido e texto EN precisam avaliação física. Novos itens da mochila não devem ser conectados a gameplay LAN sem definir coletor/autoridade/replicação e regras de extração; atualmente somente dinheiro existente é integrado.

Deliberadamente fora do passe: teleporter definitivo/narrativa, sprites novos, economia/crafting/armazenamento completos, gadgets funcionais, regra de morte/dinheiro, save/network/procedural rewrite, câmera nova e combate novo. Tradução de absolutamente todas as strings/debugs também não foi prometida.

## 29–30. Runtime e teste físico

**GODOT RUNTIME RUN — PHYSICAL TEST REQUIRED.** Render automatizado e smoke tests reais executados; não houve aprovação manual completa, teste em Samsung A15 ou LAN com vários dispositivos físicos.

Roteiro recomendado:

1. Menu → Jogar → Solo/Local Co-op → dificuldades/confirmação; verificar contraste, focus/hover/pressed e retorno.
2. LAN → criar/procurar/IP/lobby; gamepad/teclado/touch; abrir/fechar dropdown e verificar foco sem borda duplicada.
3. Casa → caminhar Entrada/Doméstica/Oficina/Técnica; portal/terminal/P1/P2/colisões/câmera. Conferir os mattes documentados, sem classificar arte atual como final.
4. Operação/Cidade → vários seeds/rotas/shafts/saídas; confirmar ausência de MID/NEAR com títulos técnicos, teleporter intacto e telegraph com término coerente.
5. HUD/minimapa → portrait, dados reais, fog/marcadores/Pause/mapa completo.
6. HP 100%, 51%, 50%, 40%, 25%, 10% → curar; observar curva/pulso, input e legibilidade de combate; testar downed/revive em co-op/LAN.
7. Pause → Inventory → Equipment/Stats/Run/Backpack; dinheiro real compartilhado, carga vazia, equipamentos existentes, slots de gadget vazios; preview não equipa; Voltar permanece alcançável.
8. Settings → PT-BR/English com menu e run abertos; checar strings, tamanhos, foco e atualização imediata. Reiniciar o jogo e confirmar idioma/zoom/áudio/touch persistidos.
9. Retornar ao gameplay/hub/menu; confirmar desbloqueio de input. Fazer rodada dedicada no Samsung A15 (multitouch/scroll/slider/dropdown/performance) e LAN em dispositivos diferentes.

Próximo trabalho ambiental: usar a auditoria e os renders para preparar sprites limpos aprovados antes de uma nova composição. Não reaplicar Pass 2 nem reconstruir o projeto.
