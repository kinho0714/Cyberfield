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

## Missão P0+P1 (02/11/2026)
Evidência: Godot 4.7.2 oficial, cena real `main.tscn`, headless + Xvfb (1600×720, 1280×720,
960×540); toques como eventos de tela reais (`Input.parse_input_event`, emulação de mouse
desligada como no aparelho). Nenhum item testado no Android físico.
| Sistema | Estado | Evidência / observação |
|---|---|---|
| Terminal de blueprints por toque | CORRIGIDO | antes: 1488 px de lista em 528 px, sem rolagem por toque, blueprint fora da tela (reproduzido); depois: `blueprint_menu_touch_smoke_test` (abrir por INTERAGIR, estudar/fabricar/S2/raridade por toque, arrasto, recorte, abas, mouse, teclado, voltar) |
| Baús trap | CORRIGIDO | antes: 25 falhas (mortos em 150 quadros na Cidade Baixa/Lab; 333/686 no Industrial); depois: `trap_chest_spawn_smoke_test` 0 falhas, 7 baús, 14 inimigos, 3 biomas |
| Modo Dev | COMPROVADO (desktop/toque simulado) | `dev_mode_smoke_test`: opção por toque, botão DEV por toque, todas as abas, perfil real idêntico byte a byte; toque físico PENDENTE |
| Distribuição de armas | COMPROVADO | `weapon_loot_distribution_smoke_test`: 1,49 ofertas/estágio (antes ~0,38), 19/19 armas, baús soltam pickup real, chefe dá projeto; geração idêntica à base |
| 8 armas novas | COMPROVADO / FRACO | comportamento por categoria real; arte original; reutilizam projéteis/FX; balanceamento sem playtest |
| Escada de serviço nos poços | COMPROVADO | `exploration_routes_smoke_test`: 156/156 poços críticos; robô sobe só pulando com escalada desligada, não sobe sem a escada, descer continua livre |
| Passagem de dash + baú secreto | COMPROVADO / FRACO (arte) | 30/30 biomas; andar/pular não abrem, dash abre, registrado no mapa; baú solta arma mín. incomum |
| Progressão por saída (A alterna, B aprofunda/atalho) | COMPROVADO | só saídas A = sequência antiga; B da Cidade Baixa → Laboratório no jogo real; rótulos com destino real |
| Jhon Design B, arsenal, cyberwares, acessórios | SEM REGRESSÃO | testes antigos (`jhon_design_b_animation`, `arsenal_expansion`, `mega_pass_arsenal_sfx_ui`) aprovados |
| Suíte Godot completa | SEM REGRESSÃO | 48/53 aprovados; as 5 falhas são as mesmas da base `413b508` (43/48) |
| Instalador Termux | COMPROVADO (clones) | 25/25: instala na base simulada (mesma árvore, hash diferente, sem identidade git), detecta já instalado, `--rollback`, recusa alteração local/base errada/arquivo solto/patch corrompido, `--verificar` não altera, avisa recursos privados; aparelho PENDENTE |

## Refinamento UI, amizades e coop privado (03/11/2026)
Evidência: Godot 4.7.2 oficial, `main.tscn` real, headless + Xvfb (1600×720 e 1280×720), toques
como eventos de tela reais; relay em TLS de loopback. Nada testado no Android físico.
| Sistema | Estado | Evidência / observação |
|---|---|---|
| Menu JOGAR/SOCIAL/OPÇÕES/SAIR e subpáginas | COMPROVADO | `social_menu_smoke_test` (ordem, toque, VOLTAR, foco de origem); capturas 01–03, 05, 08, 13 |
| Partida avulsa com dificuldade (modo antigo) | SEM REGRESSÃO | `focused_stabilization_input_audio_test`, `visual_pass3_smoke_test` |
| Coop mesmo dispositivo / LAN pela seção COOPERATIVO | COMPROVADO | LAN: dificuldade → lobby → volta à página; `phase8_lan_lobby_touch_smoke_test` ok |
| Campanhas: cartões, progresso, continuar, renomear, excluir c/ confirmação | COMPROVADO | criação/continuação/renomear/cancelar/excluir pela UI; slot restante íntegro; capturas 04–07 |
| Formato do save de campanha | INALTERADO | progresso só lido (`progress_summary`); testes de store/sessão do Codex ok |
| Perfil: nome, retrato oficial, ID público, privacidade | COMPROVADO | `social_profile_smoke_test`, `social_menu_smoke_test`; captura 09 |
| Solicitações recebidas/enviadas, aceitar/recusar/cancelar, bloquear/desbloquear | COMPROVADO (local + sessão) | 4 clientes Godot: aceitação mútua e recusa sem cartão; capturas 10–12 |
| Amizades online (servidor de contas) | PENDENTE | botão desabilitado com motivo; `authenticate_online` = ERR_UNAVAILABLE |
| Sessão privada: criar/entrar por código/convites/revogar/sala | COMPROVADO (loopback) | `private_relay_social_test` 7/7 (anfitrião + 3 Godot reais); capturas 14–16 |
| Servidor indisponível informado | COMPROVADO | conexão real a porta fechada → `server_unavailable` e mensagem |
| Gameplay cooperativo sincronizado pela sessão privada | PENDENTE | plano em `ARQUITETURA_SOCIAL_COOP.md` |
| Hub MUNDO / SESSÃO no kit novo (pausa) | COMPROVADO | pausa restaurada; painel social por cima volta ao hub; captura 17 |
| Hospedagem G14 / túnel público | PENDENTE (projeto) | `HOSPEDAGEM_PRIVADA_G14.md`; nada publicado |
| E2EE | NÃO IMPLEMENTADO | interface diz que TLS não é ponta a ponta; chat desativado |
| Android físico (toque, teclado virtual, 20:9) | PENDENTE | roteiro no relatório |
| Instalador Termux (patch base `9b8d843`) | COMPROVADO (clones) | 25/25 casos; aparelho PENDENTE |

## Integração Codex + Claude — 03/11/2026

- [x] Preservar `7426f3b` e aplicar os três commits UI/social em branch independente.
- [x] Conferir SHA-256 e reconstruir as três árvores da base original do patch.
- [x] Integrar sala/amizades à ponte real, mantendo perfis e saves separados.
- [x] Executar vinte suítes headless na cópia congelada (ver relatório de integração).
- [ ] Validar no Android físico: teclado, toque, 16:9/20:9, CONTINUAR e dash.
- [ ] Após endpoint autorizado: validar dois e quatro APKs reais, queda/retomada,
      saída com modais/inventário abertos, retorno a solo e desempenho no G14.
- [ ] Completar interações/mapa/projéteis e recuperação integral de host morto;
      backend de contas/amigos continua pendente. Não declarar coop completo.
