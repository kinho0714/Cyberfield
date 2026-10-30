# Cyberfield — Cobertura Visual da Operação Renascimento Total (30/10/2026)

Base: `visual-lower-city-2026-10-30` (árvore `229ec67c…`, = `d21cd98` local, tag
`ponto-recuperacao-pre-renascimento`). Branch de trabalho: `renascimento-visual-2026-10-30`.

**Aviso de validação.** Nenhum item abaixo foi executado no Godot: o binário não está
disponível neste ambiente. "Reconstruído, aguardando validação" significa: arte nova
gerada e ligada à cena real, script validado por parser (gdtoolkit), testes estáticos
Python passando, conjunto de asserções do harness idêntico à base (34 falhas
pré-existentes, mesmas), referências `res://` verificadas. Só passa a "Reconstruído e
integrado" depois do teste no Godot Android do usuário. As imagens de prévia em
`tools/visual/*_preview` são **simulações em PIL**, não capturas do Godot.

Legenda: **RV** = Reconstruído, aguardando validação · **RI** = Reconstruído e integrado
(validado no Godot) · **P** = Pendente · **PD** = Preservado por decisão técnica justificada.

## 1. Cenários por cena / bioma

| Componente | Cena real | Status | O que mudou de fato |
|---|---|---|---|
| Hub — Casa Jhon estágio 0 (casa + laboratório) | `scene/casa_jhon_hub.tscn` via `casa_jhon_presentation.gd` | RV | Arte nova desenhada (`assets/environment/hub/hub_stage0_back.png`), camada de luz aditiva respirando, washes âmbar/ciano/magenta, poeira, varredura holográfica. Antes: pintura procedural plana. |
| Hub — estágios 1–3 (evolução da casa) | mesma cena; `MetaProgression.house_stage` escolhe a arte | RV | Arte nova cumulativa por estágio (`hub_stage{1,2,3}_back/lights.png`). 1 Reparos: varal de luzes, letreiro JHON, planta, tapete, bandeja de cabos, painel holográfico de projeto, filete neon na divisória. 2 Base operacional: mezanino com drone, mapa da cidade (CID/IND/LAB/NUC) sobre o terminal, pórtico do portal, pôster neon, segundo tanque. 3 Quartel: janela panorâmica, logo CYBERFIELD, exotraje no pórtico, conduto de energia sobre o Spark, letreiro RAMEN. Luzes ambiente ficam 15% mais fortes por estágio. Estágio 0 ficou byte-idêntico. Removidas as linhas ciano provisórias que marcavam o estágio. **Observação:** nada no jogo atual sobe `house_stage` (só o save); para ver os estágios use a cena de prévia `tests/visual/hub_house_stages_preview.tscn`. |
| Cidade Baixa | `lower_city_biome.tscn` (gerador) | RV | Pacote completo: céu, skyline distante com faróis, prédios médios com letreiros e brilho, monotrilho com trem a cada 34 s, névoa em 2 camadas, chuva, piso/parede/passarela texturizados, adereços por módulo. |
| Industrial | `industrial_biome.tscn` | RV | Pacote novo "forja": chaminés, guindastes-pórtico, fornos com brilho, engrenagens girando, lâmpadas com cone de luz, brasas. Antes: sem tema visual. |
| Laboratório (bioma) | `lab_biome.tscn` | RV | Pacote "crio": tanques, teto técnico, lâmpadas suspensas, poeira, piso/parede próprios. Antes: sem tema visual. |
| Arena do chefe (núcleo) | `boss_stage.tscn` | RV | Pacote "reator": céu carmim, pilares com pulso, faíscas; geometria pintada com o tile do núcleo. |
| Saídas de bioma | `biome_exit.gd` | RV | Portão novo (`exit_gate.png`) com batentes ciano e chevrons. |
| Teletransportadores | `biome_teleporter.gd` | RV | Plataforma nova (`teleporter_pad.png`), modulada por ativo/inativo. |
| Transições entre biomas | `room_manager` fade | P | Continua o fade preto original; transição temática ainda não feita. |
| Fases legadas `scene/levels/*` | só via `room_exit` dentro delas | PD | Fora do fluxo atual (menu → hub → biomas gerados). `RUN_SEQUENCE` e `initial_room_path` ainda as citam, mas nada no fluxo jogável carrega a primeira. Não redesenhadas para não gastar escopo em conteúdo inalcançável; não apagadas (dependências de testes/documentação). |
| `scene/laboratory_hub.tscn` | nenhuma | PD | Cena não referenciada pelo fluxo; a atmosfera colocada ali por engano foi revertida. |
| `lower_city_presentation.gd` | nenhuma | PD | Script órfão pré-existente; não removido sem sua aprovação. |

## 2. Personagens

| Componente | Status | Detalhe |
|---|---|---|
| Jhon — identidade e sprites aprovados | PD | Identidade preservada por exigência sua. Corrigido: wall-slide reempacotado e centrado; fragmentos soltos das folhas limpos. |
| Jackson / Kai / Spark | RV (parcial) | Wall-slide reempacotado e centrado. Revisão de fragmentos das demais animações: **P**. |
| Redesenho completo dos personagens jogáveis | P | Exige folha de referência do Jhon aprovada por você (não usar concept sheet). |

## 3. Inimigos, chefe e objetos

| Componente | Status | Detalhe |
|---|---|---|
| Heavy (6 animações + projétil) | RV | Folhas reconstruídas a partir das poses íntegras: pedestais/dígitos removidos, quadros pontilhados descartados, morte nova (afundar), projétil e impacto redesenhados. |
| Inimigo comum / à distância | PD | Folhas íntegras e legíveis; recebem os novos efeitos de impacto/morte. |
| Chefe | RV (aura) / P (sprite) | Aura carmim pulsante, anel no chão e faíscas, mais intensos na fase 2. Sprite dedicado do chefe: **P** (arte nova necessária). |
| Baús (saque, atributo, armadilha) | RV | Arte original substitui as texturas privadas `pixelexplosive` (que nunca estiveram no repositório). Tinta por estado preservada. |
| Pickups (medkit, sucata, dinheiro, arma) | P | Medkit/sucata são Foozle CC0 (licença compatível); restilização ainda não feita. |

## 4. Interface

| Componente | Status | Detalhe |
|---|---|---|
| Kit de painéis compartilhado (41 PNGs) | RV | Painéis holográficos, ícones em grade de 16 px (48 e 64), molduras de ação, joystick, barra de vida segmentada, vinheta. Mesmas dimensões e margens 9-slice. |
| Telas que usam o kit: atributos, inventário, menu principal, Meta-Lab, pausa | RV | Herdam o kit automaticamente. |
| HUD de gameplay | RV | Mesmo kit; barra de vida e botões de toque novos. |
| Fonte | RV | Pixelify Sans (OFL, licença incluída) como fonte padrão do tema global; título de fim de run em Bold. |
| Opção EFEITOS VISUAIS (COMPLETO/REDUZIDO/MÍNIMO) | RV | Nova opção no menu de pausa → JOGO, com textos pt-BR/en. |
| Seleção de modo / lobby LAN | P | Não usam o kit de painéis; precisam ser migradas (mudança de layout, não só de cor). |
| Minimapa / mapa completo | PD | Desenhados por código e legíveis; herdam a nova fonte. |
| Título "GUARDIÃO PROVISÓRIO" da arena | P | Texto provisório do jogo, não alterado (é conteúdo, não visual). |
| Fundo animado do menu principal | PD | Já era animado e coerente com a direção. |

## 5. Efeitos de combate e sistema visual

| Componente | Status | Detalhe |
|---|---|---|
| Impacto em inimigo (faísca, flash, recuo visual) | RV | `CombatFx.enemy_hit`; substitui o "alpha 0.5" anterior. |
| Morte de inimigo | RV | Explosão aditiva de 6 quadros. |
| Dano no jogador | RV | Flash + tremor de câmera (só COMPLETO; nunca em réplica de rede). |
| Rastro do dash | RV | Fantasmas ciano aditivos. |
| Cura | RV | Anel de cura de 6 quadros. |
| Perfis COMPLETO / REDUZIDO / MÍNIMO | RV | Partículas 1 / 0,34 / 0; tremor e cintilação só em COMPLETO; MÍNIMO = só flash do sprite. |
| Tema de bioma orientado a dados | RV | `biome_styles.gd` gerado + `BiomeDefinition.visual_theme`; novo bioma = novo estilo no gerador, sem código de cena. |

## 6. Dependências privadas ainda referenciadas (não incluídas no patch)

- 4 arquivos de áudio usados por `audio_service.gd`.
- `industrial_details.png` e `outpost_services.png` usados pelo pintor temporário
  (`TemporaryParallax` em `room_manager` e `legacy_lab`).

Os 3 baús privados deixaram de ser dependência. O instalador avisa sobre os restantes.

## 7. Pendências reais (resumo)

1. Validação no Godot Android de todos os itens RV (desempenho e FPS **não medidos**).
2. ~~Arte dos estágios 1–3 da Casa Jhon~~ — feita (RV). Falta a regra de jogo que avança `house_stage` (mudança funcional: precisa da sua aprovação).
3. Sprite dedicado do chefe.
4. Redesenho dos personagens (aguarda folha de referência do Jhon).
5. Revisão de fragmentos de Jackson/Kai/Spark fora do wall-slide.
6. Pickups (medkit, sucata, dinheiro, arma).
7. Seleção de modo e lobby LAN no kit de painéis.
8. Transições temáticas entre biomas.
9. Substituir as 2 texturas privadas do pintor temporário e os 4 áudios privados.
10. Limpeza de duplicados / cenas órfãs — aguarda sua aprovação.
