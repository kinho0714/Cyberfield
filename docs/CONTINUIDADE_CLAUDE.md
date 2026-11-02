# Cyberfield — checkpoint de continuidade (02/11/2026, após a missão P0+P1)

Leia junto com `CLAUDE.md` (regras) e `docs/RENASCIMENTO_CHECKPOINT.md` / `docs/RENASCIMENTO_CHECKLIST.md`
(histórico e evidências). Relatório da última missão: `docs/MISSAO_P0_P1_2026-11-02.md`.

## 1. Workspace
- Projeto (sessão na nuvem): `/home/user/Cyberfield` — Godot 4.7.2, GL Compatibility, alvo Android.
- PC do usuário: `C:\Users\vinic\Documents\Cyberfield_Visual_Work` (integração/revisão pelo Codex).
- Android: Godot Android + Termux. Recursos privados só no aparelho (não versionados): 4 áudios em
  `assets/audio/menu/` e 2 texturas em `assets/temporary_environment/architecture/`.
- Ferramentas da sessão (scratchpad, efêmero): Godot 4.7.2 oficial (SHA-512 conferido) em
  `…/scratchpad/godot/`; cópias de teste `…/scratchpad/run/{proj,dev,p1c,base}` com stubs dos
  recursos privados; `run/sync.sh` (TARGET=<cópia>), `run/suite.sh <saida> [filtro]`,
  `run/static.sh <pasta>`; venv com godot_parser/gdtoolkit em `…/scratchpad/venv`;
  entrega em `…/scratchpad/delivery/` (`build.sh`, `test_installer.sh`). Podem não existir depois.

## 2. Git
- Branch: `claude/cyberfield-patch-integration-7ek1p2`. Nenhum push (o app GitHub já deu 403 antes).
- Base no aparelho: `cyberfield-jhonb-2026-11-02` @ `b3bf6ab` = árvore de `4798b78` (`3ce08be2…`).
- Commits acima da base (todos locais): `413b508` checkpoint anterior, `c4a2c36` terminal por toque,
  `4e0cd1e` baús trap, `27e7c6e` armas/drops, `da8b31a` Modo Dev, `5ada125` exploração, + commit de
  documentação desta missão.
- Entrega 02/11 (P0+P1): `cyberfield_p0p1_2026-11-02.patch` (format-patch `--binary --no-renames`
  de `4798b78..HEAD`) + `instalar_cyberfield_p0p1_2026-11-02.sh` (cria `cyberfield-p0p1-2026-11-02`,
  backup `backup/antes-p0p1-<data>`, `--rollback`, `--verificar`). Testado só em clones.

## 3. Arquitetura nova (P0+P1)
- `ui/touch_scroll_router.gd`: toque em painéis roláveis (tap ao soltar / arrasto rola / recorte).
  Usado por `scene/meta_lab_ui.gd` (abas) e pelo painel do Modo Dev.
- Spawn de inimigo: posicionar ANTES do `add_child`; `Enemy`/`RangedEnemy.anchor_spawn_position()`
  no 1º tick de física.
- `scene/weapons/weapon_loot_table.gd`: sequência de ofertas por estágio (RNG próprio; geração dos
  biomas inalterada). Catálogo com `tier` e `biomes`. Baús têm `reward_weapon_id/reward_rarity`.
- `scene/dev/dev_mode.gd` (registro de seções extensível) + `dev_mode_panel.gd`; nó `DevMode` no
  `main.tscn`; `LocalSettings.dev_mode_enabled`; `MetaProgression.begin/end_dev_sandbox()`;
  `RunManager.dev_session` (resultado recusado pelo perfil real).
- `scene/interactables/dash_passage.gd`: parede que abre com dash; `BiomeMapState` kind `passage`.
- Gerador: `ShaftServiceSteps` (degraus nos poços do caminho crítico), `DashAlcoveNN` + `SecretLoot01`.
- Progressão: `RunManager.preview_exit_biome()` / `get_stage_biome_kind()`; A alterna, B aprofunda.

## 4. Restrições (inalteradas)
Não editar `scene/casa_jhon_hub.tscn`, `default_bus_layout.tres` nem as funções congeladas do menu de
pausa; não incluir recursos privados; sem push/merge sem autorização; "concluído" exige evidência no
Godot real; não afirmar nada sobre o aparelho sem teste físico.

## 5. Pendências
- Playtest físico de tudo da P0+P1 (toque no terminal e no painel Dev, botão DEV, escada de serviço,
  passagem de dash, rótulos das saídas, armas novas).
- LAN: loadout só no host; Modo Dev desligado em LAN por desenho.
- Arte própria da passagem de dash; projéteis/FX próprios das armas novas; sistema de combos ainda
  não implementado (fora desta missão).
