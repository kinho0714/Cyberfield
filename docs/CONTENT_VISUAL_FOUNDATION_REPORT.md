# Relatório — Content / Visual Asset Foundation Pass

## Resultado e baseline

Concluída a fundação incremental, sem produzir/substituir arte. Workspace: `C:\Users\vinic\Documents\Cyberfield_Visual_Work`. Branch `qwen-transfer-post-visual-2026-10-03`, HEAD `724ea8c2b36528f1e822263fe3aaa9c0204e96fa`. O working tree já tinha alterações extensas de passes anteriores, incluindo scripts de apresentação/localização e arquivos não rastreados. Estado inicial e hashes: [baseline.json](content_foundation/baseline.json). Nenhum reset/restore/clean/stash, commit ou push foi realizado.

Antes de mudanças, o editor/headless 4.7.2 inicializou sem erro de parser; os smoke tests official_visual_integration, phase8_combat_content, casa_jhon_stage0, phase8_final_consolidation, visual_pass3 e phase6_lan_contract passaram. `biome_generation_smoke_test` terminou com código zero e marcador de sucesso, mas emitiu erros pré-existentes: `RunManager._configure_run_weapon_pool_from_meta` acessa a árvore durante `_initialize` do SceneTree de teste. Não foi declarado como teste limpo nem se alterou RunManager para contornar isso.

## Arquitetura auditada e decisão

| Sistema real | Resultado da auditoria / adaptação |
|---|---|
| RoomManager e RunManager | Transições, operação, estágios e estado de salas já consolidados; preservados byte a byte |
| Procedural/biomas | `BiomeDefinition`, pools `.tres`, `BiomeGenerator` e mapa existentes; somente gates de apresentação e contexto visual de spawn recebem registry |
| Common/Ranged/Heavy | IAs e cenas continuam; Common corresponde ao arquétipo melee; novos dados não alteram stats/ranges/cooldowns/aggro |
| Boss | Protótipo compartilha Enemy/role boss; recebe slot visual opcional separado para não adquirir automaticamente identidade de melee |
| Player/co-op | `PlayerCharacterVisual` já separa visual da física; associação player_1/Jhon, player_2/Jackson, player_3/Kai, player_4/Spark intacta |
| Armas/ataques | `WeaponCatalog.WEAPONS` é fonte gameplay efetiva; `WeaponDefinition` já existia; foram adicionados vínculos opcionais, sem segundo backend |
| Projéteis | `ProjectileVisual` existente recebe SpriteFrames opcional; movimento/dano/impact duration ficam intactos |
| Loot/interativos | Pickups/chests/exits já existem; nenhuma nova economia/loot/hazard ou identidade narrativa foi criada |
| Inventário/equipment/backpack | Dois slots reais de armas, gadgets reservados pela UI e cargo futuro via RunBackpack; só ícone opcional foi acrescentado |
| Casa/Laboratory | Casa atual usa adapter próprio sobre cena funcional; lookup de atlas/estágio foi colocado nesse adapter; cenas e estações preservadas |
| HUD/menu/UI | Adapters centrais existentes recebem slots/Theme; callbacks, modal lifetime, touch e foco preservados |
| LAN/local co-op/save | Nenhum novo ID entra em RPC/save; LanSession, MetaProgression, LocalCoopInput e demais contratos permanecem |
| Carregamento | Preloads locais existentes mantidos como fallback; novos paths centralizados em dados, carregados somente quando consumidores ativos os usam |

Foram escolhidos um catálogo Resource pequeno e perfis Resource opcionais, sem autoload novo, factories de IA redundantes, varredura runtime ou sistemas vazios de hazards/áudio/gadgets. `lower_city` permanece no mapa e na geração determinística atual; o alias para `biome_01` vale somente para apresentação. O hash de bioma já fazia parte da seed procedural antes deste pass e foi preservado.

## Arquivos criados e modificados por este pass

Criados:

- `content/content_catalog.gd`, `content/catalog.tres`, `content/content_registry.gd`, `content/visual_profile.gd`.
- `tests/content_visual_foundation_smoke_test.gd`, `tests/content_visual_generation_smoke_test.gd`, `tests/visual_asset_manifest_test.py`.
- `tests/fixtures/content_visual_profile.tres`, `content_visual_frames.tres`, `content_ui_theme.tres` (fixtures reutilizam um ícone já existente; não são novos assets do jogo).
- `tools/validate_visual_asset_manifest.py`.
- `docs/CONTENT_VISUAL_ARCHITECTURE.md`, `docs/VISUAL_ASSET_IMPORT_CONTRACT.md`, este relatório e evidências em `docs/content_foundation/` (baseline, preservação, resultados, status e logs).

Modificados:

- `entities/enemy_character_visual.gd`, `player_character_visual.gd`, `projectile_visual.gd`: perfis opcionais e fallback.
- `scene/biomes/biome_definition.gd`: campo localizável opcional; `biome_generator.gd`: gates de apresentação data-driven e contexto do spawn, sem alterar RNG/colisões/conteúdo mecânico.
- `scene/biomes/lower_city/lower_city_presentation.gd`, `scene/casa_jhon_presentation.gd`: troca de atlas compatível sob demanda.
- `scene/weapons/weapon_definition.gd`, `weapon_catalog.gd`, `weapon_pickup.gd`: referências visuais separadas e apresentação world opcional.
- `scene/inventory_ui.gd`: ícone opcional de arma, limpo em slot vazio.
- `scene/main_menu_alive.gd`, `ui/menu_panel_presentation.gd`, `ui/gameplay_hud_presentation.gd`: hooks de Theme/bitmap/retrato preservando apresentação atual.

São 14 fontes existentes adaptadas. Seis já estavam modificadas/não rastreadas; as adições foram aplicadas sobre seu conteúdo físico atual. Outros arquivos que aparecem no git status são trabalho anterior. Godot também gera caches/UIDs de importação usuais; não são novos pacotes de arte.

## Registros e fallbacks

Preparados: seis biomas técnicos `biome_01` … `biome_06`, 18 variantes `enemy_bNN_melee_01`, `enemy_bNN_ranged_01`, `enemy_bNN_heavy_01`; quatro personagens `player_jhon/kai/jackson/spark`; três armas reais `scrap_blade/breaker_maul/arc_emitter`; quatro estágios `hub_stage_00` … `hub_stage_03`; `ui_default`, `projectile_ranged/heavy` e slot `boss_existing` do protótipo atual. Todos os paths de futuros perfis estão vazios intencionalmente. Nenhum nome definitivo de bioma/facção/boss foi inventado.

Fallbacks exercitados:

- Bioma desconhecido → conteúdo/pacote biome_01; alias lower_city → biome_01; mapas reservados não são selecionados automaticamente.
- Variante ausente ou de outro bioma/arquétipo → roster correto → apresentação atual.
- Perfil ausente, slot ausente/tipo errado → recurso atual; SpriteFrames parcial/incompatível/null → fallback por animação, preservando timing.
- Arma sem world texture → visual técnico existente; sem icon → comportamento visual atual do botão.
- Retrato ausente → crop atual do idle do personagem.
- Hub stage ausente → stage_00; estágio reservado incompleto → pacote stage_00 → atlas atual.
- Atlas com tamanho incompatível → atual, protegendo regiões authored; layout diferente ainda exige adapter explícito.
- Theme ausente → temas/overrides atuais, sem alterar foco/callbacks.

## Como continuar

Os seis exemplos concretos e formato `.tres` estão em [CONTENT_VISUAL_ARCHITECTURE.md](CONTENT_VISUAL_ARCHITECTURE.md): melee biome_01, ranged biome_02, arma, prop, background e Casa. Em resumo:

- Futuro bioma: acrescente entrada estável e roster no catálogo, perfil e conteúdo real aprovado. Reutilize adapter lower_city para atlas compatível ou registre novo adapter com mudança explícita de apresentação. Seleção/fluxo jogável de novos biomas não foi ligado a RoomManager.
- Variante: registre ID/bioma/arquétipo e perfil; o roster e `EnemyCharacterVisual` resolvem visual sem reconstruir Enemy.gd.
- Arma: gameplay continua em WeaponCatalog; registro visual aponta a perfil com `world`/`inventory_icon`, mantendo ID no inventário.
- Casa: registre os slots do perfil hub_stage_00; para prévia de outro estágio configure visual_stage_id antes de _ready. Progressão não foi implementada.
- Theme/UI: registre Godot Theme e bitmap slots em ui_default. Overrides locais continuam prevalecendo; repaginação completa atualiza os adapters centrais sem reescrever menu flow.

## Validação final

[test_results.json](content_foundation/test_results.json) registra código, marcador de sucesso e erros por execução. Todos os 14 smoke tests abaixo retornaram zero, com marcador esperado e sem SCRIPT ERROR/erros de runtime do projeto:

1. content_visual_foundation_smoke_test — IDs, seis rosters, variantes incompatíveis/ausentes, recurso/tipo ausente, merge parcial, contagem fixa, timing, arma world/icon, hub fallback, boss independente, personagem/retrato, Theme e contexto biome_02 em cópia transitória de definição.
2. content_visual_generation_smoke_test — reutiliza as assertivas existentes de phase8_multi_seed em execução deferred: 20 seeds × 3 dificuldades × 2 repetições = 120 gerações, sem erros de lifecycle da versão antiga do teste.
3. official_visual_integration_smoke_test.
4. common_ranged_v2_1_presentation_smoke_test.
5. player_visual_presentation_hotfix_smoke_test.
6. ranged_enemy_rebuild_v2_smoke_test.
7. phase8_combat_content_smoke_test.
8. casa_jhon_stage0_smoke_test.
9. visual_pass3_smoke_test — inclui PT-BR/English, settings, UI e operação.
10. phase8_final_consolidation_smoke_test — previsão/co-op/transições/results existentes.
11. phase6_lan_contract_smoke_test — contrato/host/discovery local.
12. phase8_lan_lobby_touch_smoke_test.
13. android_touch_hud_modal_hotfix_smoke_test — simulação headless de touch/modal.
14. phase4_stats_hud_smoke_test.

Editor/parser headless Godot **4.7.2 stable official** passou; `python tests/visual_asset_manifest_test.py`: três testes passaram, incluindo nove subcasos de contrato rejeitado. `git diff --check` passou. As suites Python históricas que dependem de Pillow/gdtoolkit/godot-parser não foram executadas: essas dependências não estão disponíveis nesta instalação. Não foram reescritos seus hashes/expectativas de passes anteriores para simular sucesso.

Avisos ambientais presentes no baseline e no final: acesso ao root certificate store e diretório Android build-tools indisponível no editor. Não são falhas do registry/parser. Não houve build/export Android.

[preservation_check.json](content_foundation/preservation_check.json) verificou 268 arquivos inicialmente modificados/não rastreados; nenhum foi perdido. Apenas seis adapters autorizados dessa lista foram alterados. Enemy/Heavy/player gameplay, RunManager, RoomManager, LanSession, MetaProgression, export_presets e project.godot permanecem iguais ao HEAD; RangedEnemy.gd e demais alterações prévias permanecem iguais ao baseline físico.

## Limitações, riscos e testes físicos

- Registry/profile é fundação, não seis biomas jogáveis, nova seleção de personagens, gadgets, campanha, lore, progressão de construção, parallax novo ou redesign.
- Materiais, VFX/áudio especializados, stats por variante, equipamento desenhado no corpo e apresentação própria de projétil por variante ainda precisam de consumidores futuros quando existir conteúdo aprovado.
- SpriteFrames precisam manter contagens/timing dos adapters atuais. Atlas precisam manter coordenadas das regiões além de dimensões. Perfis não aprovam automaticamente arte/concept sheet.
- O gate PNG não detecta semanticamente texto/checkerboard/cenário/matte; exige inspeção humana, conforme contrato.
- Paths como strings requerem atenção caso o export deixe de usar all_resources. Cache de perfis não tem hot reload/unload seletivo.
- Testes reais com janela PC, controles físicos, Android/GL Compatibility em aparelho, dois jogadores locais e LAN entre máquinas/dispositivos **ainda são necessários**. Smokes headless/simulação não certificam qualidade visual, performance mobile ou LAN físico.

O git status final completo está em [git_status_final.txt](content_foundation/git_status_final.txt); inclui os arquivos anteriores preservados e novos arquivos deste pass. Branch e HEAD permanecem iguais ao baseline. **Nenhum commit e nenhum push foram realizados.**
