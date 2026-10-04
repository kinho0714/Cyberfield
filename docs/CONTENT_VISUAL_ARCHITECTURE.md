# Cyberfield — fundação de conteúdo/apresentação

Esta fundação estende o workspace físico existente. Não produz arte nem transforma os seis IDs em seis mapas jogáveis. `content/catalog.tres` contém apenas metadados e caminhos como strings; `ContentRegistry` não é autoload. `ContentVisualProfile` é um Resource opcional, carregado sob demanda e mantido no cache da sessão. Reinicie a cena/processo após editar registros; hot reload não faz parte do contrato.

## Separação e pontos existentes

| Camada | Responsabilidade / fonte |
|---|---|
| Arquétipo mecânico | `Enemy.gd`, `RangedEnemy.gd`, `HeavyEnemy.gd`: melee/Common, ranged, heavy; boss atual reutiliza Enemy com papel de boss |
| Variante de conteúdo | `catalog.tres: enemy_variants`, associada a um bioma e arquétipo; não duplica IA |
| Apresentação | `ContentVisualProfile`: SpriteFrames, offsets e slots de assets; nunca stats, física ou autoridade |
| Bioma jogável | `BiomeDefinition`, módulos existentes e `BiomeGenerator`; registry fornece identidade de conteúdo/pacote de apresentação |
| Arma mecânica | `WeaponCatalog.WEAPONS` continua fonte usada pelo jogo; `WeaponDefinition` mantém seus campos e recebe referências opcionais |
| Equipamento/cargo | Dois slots de armas existentes; dois gadgets reservados pela UI, sem backend novo; `RunBackpack` permanece intacto |
| Hub | `casa_jhon_hub.tscn/gd` mantém colisões/estações/portal; `casa_jhon_presentation.gd` consulta pacote visual |
| UI | Adapters existentes `menu_panel_presentation`, `gameplay_hud_presentation`, `main_menu_alive`; Godot Theme opcional |

`biome_01` tem alias `lower_city`. O `.tres` atual, paths, nome Cidade Baixa, RoomManager, run stage IDs, saves e RPCs continuam usando seus valores atuais. Nunca aplique o alias indiscriminadamente a `RunManager.current_biome_id`: esse campo também representa estágios da operação. A conversão acontece somente no contexto local de apresentação.

## Catálogo

- `biome_01` … `biome_06`, cada um com roster melee/ranged/heavy, chaves localizáveis, referência opcional de cena/definição e perfil visual. Somente biome_01 aponta para mapa real.
- `enemy_b01_melee_01` … `enemy_b06_heavy_01`: 18 entradas neutras. `common` é alias mecânico de `melee`, não espécie/facção. Variante solicitada de outro bioma ou outro arquétipo é rejeitada em favor do roster correspondente.
- `player_jhon`, `player_kai`, `player_jackson`, `player_spark`: os mesmos personagens e associação participante/personagem já existentes. Sheets anteriores são fallback operacional, sem nova aprovação artística final.
- `scrap_blade`, `breaker_maul`, `arc_emitter`: preservam IDs reais, balanceamento e nomes existentes. Nenhuma arma/gadget fictício foi adicionado.
- `hub_stage_00` … `hub_stage_03`: apresentação reservada, sem progressão/unlocks novos.
- `ui_default`, `projectile_ranged`, `projectile_heavy`, `boss_existing`: perfis opcionais para os adapters atuais. `boss_existing` refere-se apenas ao boss protótipo já existente; rosters futuros de bosses ficam vazios.

IDs são strings estáveis, independentes de ordem, tradução e NodePath. Entradas retornadas pelas consultas são cópias. Não serialize Resource/Texture2D; IDs de variantes só devem entrar em save/RPC numa mudança futura explícita com compatibilidade/versionamento. Neste pass nenhum novo ID é persistido/transmitido.

`display_name_key` é separado de `id`. Chaves neutras novas ainda não foram adicionadas às traduções nem expostas em telas vazias. Nomes atuais PT-BR/English permanecem. `WeaponCatalog.get_display_name` usa a chave quando traduzida e recua ao nome atual; as telas antigas continuam funcionando com suas mensagens existentes. Adicione futuras traduções nos resources de `assets/localization/` sem usar texto traduzido como chave técnica.

## Perfil visual e fallback

Crie `.tres` aprovado, por exemplo `content/profiles/enemy_b01_melee_01.tres`:

```ini
[gd_resource type="Resource" load_steps=2 format=3]
[ext_resource type="Script" path="res://content/visual_profile.gd" id="1"]
[resource]
script = ExtResource("1")
profile_id = &"enemy_b01_melee_01"
sprite_frames_path = "res://content/profiles/enemy_b01_melee_01_frames.tres"
asset_paths = {}
animation_offsets = {"idle": Vector2(0, -7), "walk": Vector2(0, -7)}
```

No Editor, monte um **SpriteFrames** com AtlasTexture/PNG final. Registre o caminho do perfil em `catalog.tres: visual_profiles["enemy_b01_melee_01"]`. O ID da entrada e `visual_profile_id` podem ser diferentes, permitindo reutilização de pacote.

Fallback: variante ausente/incompatível → roster do bioma (bioma desconhecido → biome_01) → perfil opcional → apresentação atual do arquétipo → fallback legado já existente. Cada animação ausente, vazia, com textura null ou contagem incompatível mantém a animação atual. Nenhum asset futuro é obrigatório. Perfil/slot inexistente ou de tipo errado não substitui a textura atual. Nenhum warning por frame é adicionado.

`merge_frames` preserva FPS, loops e duração relativa dos frames atuais; não altera telegraphs/cooldowns. Exige a mesma contagem de frames por estado devido a índices fixos das máquinas visuais:

| Apresentação | Contagens atuais |
|---|---|
| Common/melee | idle 4, walk 6, attack 5, air 4, hurt 2, death 3 |
| Ranged / Heavy | idle 4, walk 6, attack 6, air 4, hurt 2, death 3 |
| Jogáveis | idle 4, walk 6, air 4, attack Jhon 5/outros 6, dash 4, ground_slam 5, hurt 2, downed 3, revive 5, wall_slide 4, wall_climb 4 |
| Projéteis atuais | movement 8, impact 6 |

Offsets são em pixels locais de AnimatedSprite2D. Assets com novo baseline/pivot devem especificar `animation_offsets` de todos os estados afetados. Sem isso a correção legada continua, inclusive ajustes por frame de Common e wall slide dos personagens. Alterar contagens/timing, alignment por frame ou escala requer adaptação posterior consciente do componente visual, sem tocar IA. Material/VFX/áudio/stats especializados **não têm novos consumidores neste pass**; não adicione campos esperando efeito automático.

## Exemplos de integração futura

1. **Melee do biome_01:** coloque PNGs aprovados em `assets/enemies/biome_01/melee_01/`, monte SpriteFrames com os estados da tabela, crie o perfil acima e preencha seu caminho em `visual_profiles`. `EnemyCharacterVisual` resolve automaticamente. Não edite `Enemy.gd`.
2. **Ranged do biome_02:** crie `enemy_b02_ranged_01` SpriteFrames/perfil e preencha esse slot. O roster já aponta para a variante. Para exercitar sem criar mapa, instancie `RangedEnemy.tscn` e configure `EnemyCharacterVisual.content_biome_id = &"biome_02"` **antes** de adicionar à árvore. Um mapa futuro com `BiomeDefinition.biome_id = &"biome_02"` passa esse contexto ao spawn sem RNG adicional. Não transmita `content_variant_id` como se já houvesse protocolo para isso.
3. **Nova arma real:** registre gameplay em `WeaponCatalog.WEAPONS` com novo ID estável, dados/nome aprovados; adicione o mesmo ID em `catalog.tres: weapons`, com chave localizada e perfil. Slots consumidos: `world` pelo pickup e `inventory_icon` pela mochila. `animation_offsets["world"]` ajusta o anchor visual, sem mudar colisão. Registre também nas regras reais de obtenção/desbloqueio existentes quando autorizado. Equipamento desenhado no corpo, attack VFX e projétil de arma ainda precisam de consumidor posterior; backend/inventário não é substituído.
4. **Prop ambiental:** `biome_01` perfil aceita `asset_paths["props"]` apontando para atlas aprovado. O adapter atual exige mesmas dimensões e **mesmas regiões** do atlas existente. Para prop novo com outra região/posição, estenda somente `lower_city_presentation`/tabela de regiões, nunca sockets/colisões. Um pacote totalmente novo merece outro adapter explícito, não uma concept sheet enfiada no atlas.
5. **Background:** slot `background_far` no perfil do bioma troca a textura usada pelo adapter atual, mantendo o contrato de dimensões/posição/frequência existente. MID/NEAR e parallax novo não são implementados aqui. Para biome_02 e demais, `presentation_adapter_id = "lower_city"` reaproveita a composição visual atual; o perfil próprio substitui slots e os restantes recuam ao pacote biome_01. Isso não cria mapa jogável automaticamente. Acrescente cena/definição aprovadas ao registry quando houver conteúdo real; RoomManager continua com seu fluxo atual até uma mudança de seleção de biomas autorizada.
6. **Casa:** preencha o perfil `hub_stage_00` com slots `structure`, `domestic_props`, `workshop_props`. As referências estão somente na apresentação. Outros estágios recuam ao pacote stage_00; para prévia configure `visual_stage_id` no componente de apresentação **antes de _ready**. Atlas precisam das mesmas dimensões/regiões. Novo layout visual exige adapter de apresentação próprio; as estações funcionais não são ativadas/desativadas por arte. Nenhuma progressão foi ligada a esses IDs.

## UI/theme

`ui_default` aceita `asset_paths["theme"]` apontando a um Godot Theme. Hooks existentes aplicam-no aos containers de menu, páginas/botões dos panels e HUD; callbacks/focus/input não mudam. Overrides locais existentes têm precedência sobre Theme: uma repaginação completa deve atualizar os adapters centrais também, sem reescrever os fluxos. O fundo animado principal, mapas e outros desenhos customizados permanecem seus adapters atuais; não há pretensão de um Theme substituir automaticamente todo `_draw` do projeto.

Slots para bitmap dos panels: `panels/<path usado em style/background>`, sem `.png`; exemplo `panels/inventory/detail_panel`, `panels/settings/slider_handle`. Slots HUD: `hud/hud/player_frame`, `hud/hud/hp_track`, `hud/hud/hp_fill`, `hud/hud/portrait_frame`, `hud/icons/heal_icon`, `hud/icons/icon_attr_health`, `hud/icons/icon_attr_intelligence`, `hud/icons/icon_attr_strength`, `hud/icons/money_icon`, `hud/low_hp/low_hp_vignette`, `hud/low_hp/player_frame_critical_accent`. Retrato separado usa slot `portrait` no perfil do personagem; ausente mantém crop atual do idle.

## Import, export e performance

Veja [contrato de importação](VISUAL_ASSET_IMPORT_CONTRACT.md). Adicione somente assets finais aprovados em `assets/<categoria>/`; não é necessário mover arquivos anteriores. Novos perfis devem ficar em `content/profiles/` quando existirem, sem dezenas de diretórios vazios agora. Scripts legados continuam donos dos paths de fallback atuais; todos os **novos** paths ficam nos dados de perfis/catálogo.

O preset Android atual usa `all_resources`; `.tres`, sprites e scripts são recursos importáveis. `export_presets.cfg` não foi alterado. Se mudar para export de cenas selecionadas, inclua explicitamente os perfis/texturas referenciados por strings e valide em build exportado; referências textuais não formam dependências de export por si só.

Catálogo pequeno é preload de metadados. Perfis/texturas só são consultados pelos consumidores ativos. SpriteFrames podem ser copiados por instância quando há override, mas as Texture2D são compartilhadas pelo ResourceLoader. Não há preload dos seis pacotes, scanner runtime, IA nova, reflection pesada por frame, nem integração ComfyUI/IA. Descarregamento seletivo/hot reload de pacotes não foi implementado.
