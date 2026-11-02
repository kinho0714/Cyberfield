# Renascimento — checklist de integração (estado real)

Evidência = execução no Godot 4.7.2 oficial (Linux, Xvfb + Mesa, renderer
Compatibility, 1560×720 = proporção de celular) com `tests/renascimento_capture.gd`
no fluxo real `main.tscn` → hub → estágios. Os 6 recursos privados foram substituídos
por stubs **só na cópia de teste**. Não substitui o teste físico no Android.

Estados: **COMPROVADO** (aparece no jogo real, com captura/relatório) · **CORRIGIDO**
(defeito achado no motor e corrigido, comprovado após a correção) · **FRACO** (integrado,
mas a qualidade visual ainda não atinge o objetivo) · **PENDENTE** · **ANTIGO** (visual
antigo ainda em uso).

## Cenário
| Sistema | Estado | Evidência / observação |
|---|---|---|
| Fundo parallax por bioma (céu, distante, médio, letreiros, brilho, névoa) | COMPROVADO | `BiomeBackdrop` com 9–11 planos, 0 texturas nulas, nos 4 estágios |
| Fundo abaixo do nível da rua (poços/descidas) | CORRIGIDO | antes: preenchimento quase preto (Industrial pior). Agora o plano `under` se repete até a base da tela |
| Superfícies (piso, passarela, parede) | COMPROVADO | 55–73 polígonos com textura por bioma |
| Anteparas do gerador (colunas de borda) | CORRIGIDO | eram placas teal com borda ciano em todo bioma; agora textura de parede + acento do bioma |
| Adereços por módulo | COMPROVADO / FRACO (Lab) | 33–56 por bioma; Laboratório ainda parece vazio (paredes lisas) |
| Clima (chuva, brasas, poeira, faíscas) | COMPROVADO | partículas presentes em todos |
| Arena do chefe (tema reator) | COMPROVADO / FRACO | aparece, mas muito escura e de baixo contraste |
| Transições entre biomas | ANTIGO | fade preto original |

## Hub (casa do Jhon)
| Sistema | Estado | Evidência / observação |
|---|---|---|
| Arte do estágio 0 | COMPROVADO | `casa_jhon_presentation` presente, captura `hub_stage0` |
| Estágios 1–3 | COMPROVADO (via save) | capturas `hub_stage1..3` com `house_stage` alterado; nada no jogo sobe o estágio (decisão funcional pendente) |
| Atmosfera (luzes, washes, poeira) | COMPROVADO | `HubAtmosphere` presente |
| Pintor antigo (`TemporaryParallax`) | ANTIGO, oculto | ainda criado pelo RoomManager (arquivo congelado) atrás da arte nova; não aparece |
| Painel "LABORATÓRIO" (RunDebugHUD) | ANTIGO | aparece por padrão sobre o hub; é depuração do RoomManager — decisão do usuário |

## Personagens e inimigos
| Sistema | Estado | Evidência |
|---|---|---|
| Jhon (folhas v2, wall-slide reempacotado) | COMPROVADO | probe: `jhon_v2_*_v2.png` |
| Heavy reconstruído | COMPROVADO | probe: `heavy_*_v1.png` reconstruídos |
| Comum / à distância | ANTIGO por decisão | folhas v2 anteriores |
| Aura do chefe | COMPROVADO | captura `stage5` |
| Sprite próprio do chefe | PENDENTE | usa visual de Heavy |

## Efeitos de combate
| Sistema | Estado | Evidência |
|---|---|---|
| Golpe (flash + faísca) | COMPROVADO | 2 nós de efeito + captura `combat_hit` |
| Dash (rastro ciano) | COMPROVADO | 3 nós + captura `combat_dash` |
| Morte (explosão) | COMPROVADO | 5 nós + captura `combat_death` |
| Tremor de câmera | CORRIGIDO | `get_meta(nome, null)` gerava erro a cada golpe pesado |
| Perfis COMPLETO/REDUZIDO/MÍNIMO | INTEGRAÇÃO NÃO COMPROVADA | opção no menu existe; troca de perfil não capturada ainda |

## Interface
| Sistema | Estado | Evidência |
|---|---|---|
| Tema global + fonte Pixelify | COMPROVADO | todas as capturas de UI |
| Pausa, inventário, Meta-Lab, atributos | COMPROVADO | capturas `ui_*` |
| HUD (vida, joystick, botões) | COMPROVADO | capturas de gameplay |
| Seleção de modo | COMPROVADO (tema) | captura `ui_mode_select` |
| Lobby LAN, resultado da run | INTEGRAÇÃO NÃO COMPROVADA | não capturados ainda |
| Título "STAGE 6 // GUARDIÃO PROVISÓRIO" | ANTIGO | texto provisório da cena do chefe |

## Cenas e scripts fora do jogo (grafo de alcance a partir de `main.tscn`)
- Inalcançáveis: `scene/experimental/lower_city_concept.tscn`, `scene/laboratory_hub.tscn`,
  `lower_city_presentation.gd`, `legacy_lab.gd`, `jhon_idle_visual.gd` e 3 scripts de
  dados. Não removidos (aguardam aprovação).
- `scene/levels/*`: alcançáveis só por `room_exit` entre elas; o fluxo atual não entra.
- PNGs sem uso: `assets/environment/laboratory` (29), `cidade_baixa` (6),
  `experimental/lower_city_concept` (14), parte de `characters/jhon` e `ui/menu`.

## Ainda não verificado no aparelho
Se o preto relatado no R2 estava só nos módulos abaixo da rua e na arena do chefe.
Pedir ao usuário uma captura do ponto exato.

## Arsenal, cyberwares e slots ativos (01/11/2026)
Evidência: `tests/arsenal_expansion_smoke_test.gd` no fluxo real `main.tscn` → Casa (terminal) →
bioma gerado → combate → morte → Casa, Godot 4.7.2; capturas com `-- <dir>` sob Xvfb.
| Sistema | Estado | Evidência / observação |
|---|---|---|
| 12 armas, 7 categorias com comportamento próprio | COMPROVADO | escopeta soma chumbos, rifle perfura 2, flecha cai em arco, bastão acerta 2 alvos |
| Raridade (Comum/Incomum/Raro, tiers superiores desligados) | COMPROVADO | atributos reais mudam; pickup sorteia raridade; fabricação escolhe raridade |
| Blueprint → estudo → fabricação → loadout | COMPROVADO | terminal da Casa, botões reais; loadout aplicado no hub e na run seguinte |
| Cyberwares (6 linhas, MK1–3, 4 slots) | COMPROVADO | vida máx., cura, dash, dano físico medidos no jogador; drop do chefe instalado |
| Persistência (save v4) | COMPROVADO | perfil novo lendo o mesmo arquivo vê arsenal, implantes e acessórios |
| Dois slots ativos (gelo, fogo, torreta) | COMPROVADO | tecla F usa granada; congela, queima com dano contínuo, torreta acerta sozinha |
| HUD de equipamento + botões touch | COMPROVADO (desktop) | `LoadoutHUD` visível na run; 2 botões touch criados — toque físico no Android PENDENTE |
| Arte original (armas, projéteis, FX, ícones) | COMPROVADO / FRACO | aparece no jogo; arma sobreposta ao personagem é provisória (sem poses próprias) |
| LAN | FRACO | só o host recebe o loadout; clientes não veem granadas/torreta |

## Missão Visual 02 — cenários (01/11/2026)
Evidência: Godot 4.7.2, Xvfb, 1560×720, fluxo real `main.tscn`; capturas antes/depois em
sequência para chuva e parallax.
| Sistema | Estado | Evidência / observação |
|---|---|---|
| Escala da Casa (porta, móveis, máquinas vs. Jhon ≈ 95 px) | CORRIGIDO | `hub_art.py` mede tudo contra o Jhon; antes balcão > Jhon, geladeira 2,5×, teto 6× |
| Janela da Casa: paisagem da Cidade Baixa | COMPROVADO | `HubWindowView`: céu, 3 camadas, letreiros, carro voador, recorte na moldura |
| Chuva na janela | CORRIGIDO | antes pintada no PNG; agora 2 camadas + gotas no vidro; 3,5–4,6 mil px mudam entre quadros |
| Parallax da janela | CORRIGIDO | antes inexistente; câmera +88 px → camada distante desliza ~23 px na moldura, vizinho ~3 px |
| Painel "LABORATÓRIO" no hub | CORRIGIDO | só com HUD de depuração (F4) |
| Sob a rua (Cidade Baixa/Industrial/Lab) | CORRIGIDO | arcos irregulares com lojas, túneis, fornos, esteiras, escotilhas |
| Paredes do Laboratório | COMPROVADO | painéis com recortes, pilastras iluminadas, eletrodutos |
| Transição entre salas | COMPROVADO | varredura/scan/glitch sobre o fade (captura no meio do fade, alfa 0,52) |
| HUD de equipamento | COMPROVADO | fontes maiores, munição grande, recarga sobre o ícone |
| Teste "LowerCityMid" | PENDENTE | não existe em nenhum ref deste repositório (cópia do PC?) |

## Jhon Jhones Design B — animações oficiais (02/11/2026)
Evidência: `tests/jhon_design_b_animation_smoke_test.gd` no fluxo real (main.tscn → Casa → run),
headless e com Xvfb; importação por `tools/visual/character_sheet_import.py` (fontes conferidas
por SHA-256 contra o manifesto do pacote).
| Item | Estado | Evidência / observação |
|---|---|---|
| IDLE, WALK, RUN, JUMP, FALL, LAND, DASH (rolamento) | COMPROVADO | estados observados no jogo: idle→run→jump→fall→land, dash |
| HURT, DOWNED, GET_UP | COMPROVADO | dano, queda e reviver; GET_UP só aparece em co-op (no solo cair encerra a run) |
| AIM/SHOOT pistola, rifle, arco | COMPROVADO | tiro → shoot_*, depois aim_* por 0,6 s; arma separada na mão |
| RELOAD_PISTOL | COMPROVADO / CONFERIR | quadros seguem o tempo real de recarga; mapeamento do pacote marcado "conferir" |
| MELEE_READY_IMPACT / MELEE_PUNCH_01 | COMPROVADO | postura com arma de impacto; golpe corpo a corpo genérico até haver animação por arma |
| RELOAD_RIFLE | NÃO INTEGRADO | o arquivo mostra o Jhon desabando (variação de DOWNED), não recarga |
| RELOAD_SHOTGUN, DOUBLE_JUMP | FORA DO PACOTE | não inventados |
| Revive, parede, mergulho | ANTIGO | sem folha aprovada: continuam com as folhas v2 (outro design) |
| Retrato do HUD | COMPROVADO | recortado do IDLE oficial |
| Android físico | PENDENTE | export inclui tudo (`all_resources`); não testado no aparelho |
