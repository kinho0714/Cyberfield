# Cyberfield — checkpoint de continuidade (02/11/2026)

Leia junto com `CLAUDE.md` (regras) e `docs/RENASCIMENTO_CHECKPOINT.md` / `docs/RENASCIMENTO_CHECKLIST.md`
(histórico e evidências). Este arquivo resume o estado para retomar depois de `/clear`.

## 1. Workspace
- Projeto (sessão na nuvem): `/home/user/Cyberfield` — Godot 4.7.2, GL Compatibility, alvo Android.
- PC do usuário: `C:\Users\vinic\Documents\Cyberfield_Visual_Work` (integração/revisão pelo Codex).
- Android: Godot Android + Termux. Recursos privados só no aparelho (não versionados): 4 áudios em
  `assets/audio/menu/` e 2 texturas em `assets/temporary_environment/architecture/`.
- Ferramentas da sessão (scratchpad, efêmero, fora do repositório): Godot 4.7.2 em
  `…/scratchpad/godot/Godot_v4.7.2-stable_linux.x86_64`; cópia de teste `…/scratchpad/run/proj`
  (com stubs dos recursos privados); script de suíte `…/scratchpad/arsenal/smoke.sh`; venv com
  godot_parser em `…/scratchpad/venv`. Podem não existir numa sessão nova.

## 2. Git (verificado em 02/11)
- Branch ativa: `claude/cyberfield-patch-integration-7ek1p2`.
- HEAD antes deste checkpoint: `4798b78` "Let reviving an ally win over get-up; update tests for the Design B contract".
  O commit deste arquivo fica logo acima dele.
- Base: `origin/dev/visual` = `ce3fae3` (árvore `303b14ed…`). A branch local `dev/visual` está em
  `06553cf` (hashes diferentes, mesma árvore de `ce3fae3`).
- Commits locais NÃO enviados (nenhum push; o push anterior deu 403 por permissão do app GitHub):
  1. `2615965` arsenal modular, cyberwares e 2 slots ativos
  2. `34cdfa3` projéteis maiores + estabilização do teste do arsenal
  3. `f0ffa47` Casa do Jhon reconstruída em escala + janela viva
  4. `5702d71` missão noturna 31/10 trazida (cherry-pick de `e7bbdc2`)
  5. `beb4d28` sob-a-rua variado, paredes do Lab, transição, HUD
  6. `11f829d` evidências no checkpoint/checklist
  7. `47febdc` Jhon Jhones Design B (animações oficiais)
  8. `56abce4` retrato do HUD com o Design B
  9. `4798b78` prioridade reviver > levantar; testes no contrato novo
- Outras branches locais preservadas: `visual-noturna-2026-10-31` (`e7bbdc2`, WIP noturna),
  `backup/claude-patch-integration-2026-10-29` (`d21cd98`), `renascimento-integracao-2026-10-30`,
  `renascimento-visual-2026-10-30`, `master` (= origin/master `63a31ef`).
- Entrega ao Android (02/11): patch `cyberfield_arsenal_cenarios_jhonb_2026-11-02.patch`
  (9 commits sobre `ce3fae3`, SHA-256 `d12afb99…7644`) + `instalar_cyberfield_2026-11-02.sh`
  (cria a branch `cyberfield-jhonb-2026-11-02`, árvore final `3ce08be2…`). Testado só em clones;
  instalação no aparelho ainda não confirmada.

## 3. Alterações não commitadas
- Nenhuma (`git status` limpo antes deste arquivo).

## 4. Decisões e arquitetura
- **Arsenal**: `scene/weapons/weapon_catalog.gd` orientado a dados (12 armas, 7 categorias:
  blade, blunt, pistol, semi_auto, shotgun, rifle, bow). Escopeta = raios por chumbo com dano
  somado; impacto = consulta de área (ShapeCast para no 1º corpo); rifle perfura; arco com gravidade.
- **Raridade** separada de nível: `scene/equipment/rarity_table.gd` (comum/incomum/raro ativos;
  épico/lendário desligados). Pickups sorteiam raridade com RNG próprio (não consome RNG do bioma).
- **Cyberwares**: `scene/equipment/cyberware_catalog.gd` (6 linhas, MK1–3, 4 slots da
  `GameplayProgressionFoundation`). Drops por papel de inimigo com RNG próprio.
- **Acessórios**: `scene/equipment/accessory_catalog.gd` + `entities/player_gadgets.gd`
  (gelo, fogo, torreta; ações `gadget_1/2`: F/G, LT/D-pad ▲, botões touch).
  Status em `scene/combat/enemy_status.gd` (ajusta `move_speed` por razão).
- **Persistência**: `MetaProgression` save v4 (armory, loadout, cyberwares, instalados,
  acessórios); saves v1–v3 compatíveis. Blueprints chegam ao terminal mesmo na derrota;
  cyberware achado só fica na vitória (derrota = sucata).
- **Fluxo da Casa**: terminal existente (`scene/meta_lab_ui.gd`) com bancada: estudar →
  fabricar (sucata, raridade) → loadout S1/S2; implantes; acessórios A1/A2.
  `RoomManager.apply_meta_loadout()` aplica no hub e no início da run.
- **Casa reescalada**: `tools/visual/hub_art.py` mede tudo contra o Jhon (~47 px na arte 2×);
  andar de cima em corte acima da laje. Janela viva `scene/fx/hub_window_view.gd`
  (parallax pela câmera, chuva, gotas). A cena `scene/casa_jhon_hub.tscn` continua intocada (congelada).
- **Biomas**: `tools/visual/biome_art.py` (`under_layer` variado, `lab_mid` com arquitetura);
  transição `scene/fx/transition_fx.gd`; painel "LABORATÓRIO" só com depuração (F4).
- **Personagens**: conjunto oficial dirigido por dados (`entities/character_animation_sets.gd`,
  gerado por `tools/visual/character_sheet_import.py`); `PlayerCharacterVisual` tem caminho
  "set" (Jhon Design B, células 160×100 a 1,0×) e caminho legado (Jackson/Kai/Spark a 1,5×).
  Arma empunhada é sprite separado na âncora da mão. Projétil: colisão na altura de sempre
  (hitbox inimiga ~30 px na cintura); só o desenho sai do cano.
- **Restrições**: não editar `scene/casa_jhon_hub.tscn`, `default_bus_layout.tres` nem as funções
  congeladas do menu de pausa; não incluir recursos privados; não fazer push/merge sem autorização;
  "concluído" exige evidência no Godot real.

## 5. Estado funcional
- **Concluído e testado no Godot 4.7.2 (headless + Xvfb)**: arsenal, cyberwares, acessórios,
  fabricação/loadout/save (`tests/arsenal_expansion_smoke_test.gd`); Casa em escala, janela com
  chuva e parallax, biomas, transição, HUD (capturas); Jhon Design B
  (`tests/jhon_design_b_animation_smoke_test.gd`).
- **Suíte Godot (última)**: 35 aprovados / 14 falhas — mesmas falhas pré-existentes da linha de base.
  `casa_jhon_stage0` é intermitente desde antes (tempo de física / estouro de tempo).
- **Testes estáticos**: mesmas falhas antigas (gameplay_hud 2, lan_post_playtest 2, menu_panels 2,
  visual_integration_pass2 3 — hashes de congelamento já desatualizados na base).
- **Parcial / limitações**: LAN — só o host recebe loadout; clientes não veem granadas/torreta.
  Jhon: revive, parede e mergulho ainda com folhas antigas; RELOAD_RIFLE do pacote rejeitado
  (mostra queda); sem RELOAD_SHOTGUN/DOUBLE_JUMP. Industrial sem máquinas animadas novas.
- **Pendente**: playtest físico no Android de tudo acima; "LowerCityMid" não existe neste
  repositório (provável cópia do PC).

## 6. Próxima missão: P0 + P1 (preparação)
Tópicos pedidos: blueprints, Modo Dev, baús trap, armas/drops e exploração. Pontos de partida reais:
- **Blueprints**: `scene/meta_progression.gd` (`recovered_models`, `blueprints`, `study_blueprint`,
  `is_blueprint_known`, `fabricate_weapon`); registro na run em `scene/run_manager.gd`
  (`record_weapon_found` → `blueprints_found`); UI em `scene/meta_lab_ui.gd`.
- **Modo Dev**: hoje só há o HUD de depuração (`LocalSettings.debug_hud_visible`, tecla F4 em
  `scene/run_debug_hud.gd`, toggle no menu de pausa). Não há modo dev de verdade (spawn, cheats).
- **Baús trap**: `scene/interactables/trap_chest.gd` (145 linhas) + `trap_chest.tscn`; eventos em
  `run_manager.gd` (`get_trap_event_composition`, `activate_trap_event`, `claim_trap_event_reward`).
  Baús de atributo: `scene/interactables/attribute_chest.gd`.
- **Armas/drops**: pickups no gerador (`scene/biomes/biome_generator.gd`, `_spawn_weapon_pickups`,
  `SPECIAL_WEAPON_DROP_CHANCE := 0.38`, `_spawn_loot`); drops de inimigos em
  `run_manager.handle_enemy_drop` (dinheiro, bandagem, sucata, cyberware).
- **Exploração**: `scene/biomes/biome_generator.gd` (1632 linhas), `biome_map_state.gd`,
  `biome_minimap.gd`, teleportes em `room_manager.gd`.
- Antes de codar: inspecionar esses arquivos, rodar a linha de base da suíte e preservar o RNG
  da geração (não consumir chamadas novas do `rng` do bioma).
