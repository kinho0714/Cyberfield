# Cyberfield — Direção visual

Versão 2 · 30/10/2026 · Documento vivo. Mudanças de regra exigem aprovação.

> **Mudança da v2 (Operação Renascimento Total):** a pedido da direção (referências de
> 30/10: rua neon, side-scroller em crepúsculo violeta, laboratório magenta/ciano e
> fábrica ferrugem/ciano), magenta e violeta passam a ser **luz ambiente legítima** do
> cenário. A regra "magenta só para ameaças" da v1 foi revogada. A legibilidade das
> ameaças agora vem das regras da seção 2.4.

## 1. Identidade

**"Tecnologia que sobreviveu à cidade."** O Cyberfield é um mundo em que a alta
tecnologia foi instalada às pressas sobre uma cidade que já estava ruindo: terminais
limpos parafusados em concreto molhado, cabos improvisados sobre aço oxidado,
laboratórios brilhantes debaixo de bairros sem luz.

Três princípios valem para tudo:

1. **Função antes de brilho.** Cada luz tem dono: uma lâmpada, uma tela, um letreiro,
   uma arma. Não existe neon "de enfeite" sem fonte.
2. **Legível sem efeitos.** Com partículas, brilho e chuva desligados, o jogo
   continua reconhecível pela silhueta, pelo material e pela arquitetura.
3. **Escuro com intenção.** A base é escura para que o que importa (jogador, ameaça,
   interação) apareça. Escuridão nunca esconde perigo.

O que **não** somos: néon roxo e rosa em todas as superfícies, grade sintética dos
anos 80, nem cópia de franquias conhecidas.

## 2. Paleta

### 2.1 Base (materiais)

| Nome | Hex | Uso |
|---|---|---|
| Abismo | `#05080F` | céu profundo, vazios |
| Grafite | `#0D1520` | sombras de estrutura, fundos de painel |
| Aço | `#1A2733` | metal estrutural |
| Aço claro | `#2C3E4C` | bordas e chanfros de metal |
| Concreto | `#2A2F36` | alvenaria e lajes |
| Ferrugem | `#5C3C2C` | corrosão e caixotes |
| Névoa | `#3A4A63` | perspectiva atmosférica |

### 2.2 Cores de função (semânticas, obrigatórias)

| Função | Cor | Hex | Regra |
|---|---|---|---|
| Sistema, jogador e interação segura | Ciano | `#39DFF2` | UI, foco, bordas caminháveis, habilidades do jogador. |
| **Ameaça** | Carmesim | `#FF2A6D` | Inimigos, ataques, projéteis e áreas de dano. No cenário, o magenta é permitido (2.4) mas nunca no plano jogável próximo a uma ameaça. |
| Perigo crítico | Vermelho | `#FF3D5F` | HP baixo, armadilhas ativas, alarme. |
| Recompensa, valor e luz prática | Âmbar | `#E8A852` | dinheiro, loot, lâmpadas de rua, sinalização industrial. |
| Cura e sucesso | Verde | `#43F2B0` | cura, conclusão, farmácia. |
| Atmosfera distante | Violeta | `#3A2448` a `#6A4FB0` | só em céu e camadas distantes, sempre de baixo contraste. |

Regra de contraste: **personagens e ameaças sempre ≥ 2 níveis de luminância acima do
fundo imediato.** Camadas de fundo ficam com saturação ≤ 60% e brilho ≤ 50% do primeiro
plano.

### 2.4 Legibilidade de ameaças sem exclusividade de cor (v2)

1. **Separação de planos.** Todo fundo é desenhado em camada de tela atrás de uma névoa
   de módulo (alfa 0,20–0,34) e com névoa atmosférica própria. O plano jogável é sempre
   o mais nítido e contrastado.
2. **Bordas caminháveis acesas.** Todo topo pisável tem linha clara de 1–2 px na cor do
   bioma (lilás, âmbar, ciano, rosa-claro), distinta das luzes de fundo.
3. **Silhueta.** Inimigos mantêm contorno escuro e massa carmesim saturada. O cenário
   usa magenta em letreiros e luz, nunca em grandes massas sólidas no nível do chão.
4. **Arena do chefe.** O Núcleo é escurecido de propósito (condutos a 70/255) para o
   chefe carmesim e sua aura serem o ponto mais brilhante.

### 2.3 Paletas por bioma

| Bioma | Dominante | Acento de cenário | Clima |
|---|---|---|---|
| Cidade Baixa (`lower_city_night`) | crepúsculo violeta, prédios índigo | letreiros ciano/magenta/âmbar/violeta, lanternas âmbar | chuva, reflexos, monotrilho com trem |
| Industrial (`industrial_forge`) | aço oxidado, ferrugem, smog | âmbar de fornalha, faixas de perigo, ciano de bordas | brasas subindo, fumaça, engrenagens girando |
| Laboratório (`lab_cryo`) | azul clínico, painéis modulares | ciano e magenta (lavagens), verde de fluido | poeira em suspensão, monitores |
| Hub, Casa Jhon | madeira (casa) + painéis (lab) | âmbar doméstico, ciano/magenta no laboratório | poeira, varredura holográfica |
| Núcleo, chefe (`core_reactor`) | grafite escuro | carmesim do reator (pulsa), magenta contido | faíscas, aura do chefe |

## 3. Luz

- **Fontes visíveis.** Todo cone, halo ou reflexo parte de um objeto desenhado
  (poste, tela, letreiro).
- **Luz aditiva com teto.** Halos usam alfa ≤ 30% e cobrem no máximo cerca de 15% da
  tela visível.
- **Hierarquia.** Jogador > ameaça > interativo > cenário. O cenário nunca brilha mais
  que um projétil inimigo.
- **Piscadas.** São raras (intervalo ≥ 4 s), curtas (≤ 0,25 s) e nunca estroboscópicas.
  No perfil Reduzido, ficam desligadas.
- **Sem `Light2D`** no perfil base. Luz é pintada ou feita com sprite aditivo, mais
  barato no Android em GL Compatibility.

## 4. Escala e grade

| Elemento | Medida |
|---|---|
| Personagem jogável | 64 px de altura útil, célula de 72 px de altura, pés em y = 68–69 |
| Inimigo comum e ranged | célula de 128–136 px de altura, exibida a 0,8×; o corpo lê como 1,3× o jogador |
| Heavy | ~1,6× o jogador, desenhado **nativo**, nunca ampliado |
| Chefe | 2,5–3× o jogador, desenhado nativo, com silhueta única |
| Módulo de bioma | 840 × 480; piso no topo y = 420, espessura 60 |
| Bordas caminháveis | linha de 2 px clara (ciano ou neutra) em todo topo pisável |
| Pixel | filtro *nearest*; escalas apenas inteiras ou ≥ 1 sem reamostragem fracionária em arte nova |

## 5. Linguagem de formas

- **Jogador e aliados:** formas compactas e verticais, contorno escuro, acentos
  angulares de energia ciano.
- **Inimigos:** formas curvas e predatórias (garras, caudas), assimetria, frente
  pesada. O carmesim concentra-se nas partes que causam dano.
- **Arquitetura:** retângulos com chanfro de 45°, painéis modulares, emendas visíveis.
  A tecnologia nova é limpa e reta; a estrutura antiga é irregular e remendada.
- **Interativos:** moldura própria (canto em colchete, como na UI), acento âmbar e
  movimento sutil (pulso ≤ 1 Hz). Precisam ser reconhecíveis sem texto.

## 6. Tipografia

- **Títulos e números do HUD:** fonte pixel-tecnológica OFL, por exemplo Pixelify
  Sans ou Silkscreen para títulos e uma monoespaçada pixel para números. É uma
  proposta e depende de aprovação.
- **Texto corrido** (descrições, opções): sans legível em tamanhos ≥ 20 px no celular.
- Caixa alta para rótulos de sistema ("RUN PERDIDA"); frases normais para descrições.
- Toda fonte entra com a licença no repositório (`assets/fonts/LICENSES.md`).

## 7. Interface

A UI é **o sistema operacional do Jhon**: um terminal portátil.

- Painéis escuros (`#071019`, alfa 0,85–0,95), borda de 1 px e **cantos em colchete**
  ciano. A base atual é preservada.
- **Estados.** Normal: borda com 30% de opacidade. Foco: borda cheia com barra
  lateral animada (já existe no menu). Pressionado: preenchimento ciano a 25%.
  Desabilitado: texto `#6C8596`, sem borda.
- **Toque.** Alvos com no mínimo 56 px de base; botões de ação com ícone e não só
  texto; feedback de pressão em ≤ 1 quadro.
- **Ícones.** Silhuetas de 2 tons em grade de 16 px ampliada 3×, com contorno de 1 px
  e sem gradiente. Precisam ser legíveis em 48 px.
- Erro e perigo em vermelho; sucesso em verde; valor em âmbar; o resto em ciano ou
  neutro.

## 8. Efeitos

| Evento | Padrão | Perfil Reduzido |
|---|---|---|
| Acerto em inimigo | flash branco de 70 ms no sprite + 6–10 faíscas carmesim na direção do golpe | flash 50% mais fraco, 3 faíscas |
| Golpe pesado ou slam | tremor de câmera de 3–5 px por ≤ 120 ms | sem tremor |
| Morte de inimigo | pulso de luz e 12–16 fragmentos carmesim que caem | 4 fragmentos, sem pulso |
| Dano no jogador | flash vermelho no sprite e vinheta do HUD (já existe) | sem flash de tela |
| Dash e cura | rastro ciano ou verde de 2–3 silhuetas | sem rastro |

Regras gerais:

- No máximo 1 tremor ativo por vez.
- Tetos de partículas por evento.
- Partículas fora da tela não são criadas.
- Nada pisca a mais de 3 Hz.

**Perfis de qualidade:** `Completo`, `Reduzido` (sem tremor e piscadas, partículas
÷3) e `Mínimo` (só o flash de sprite). A escolha fica nas opções.

## 9. Desempenho (metas, não medições)

Alvo: Android intermediário em GL Compatibility.

| Recurso | Teto |
|---|---|
| Partículas ativas por bioma | ≤ 250 (chuva incluída) |
| Camadas de fundo | ≤ 8 sprites |
| Shaders em jogo | nenhum no perfil Reduzido |
| Overdraw aditivo | ≤ 15% da tela |

Toda afirmação de FPS exige medição em aparelho.

## 9.1 Sistemas reutilizáveis (implementados)

| Sistema | Arquivo | Uso |
|---|---|---|
| Kit de pixel art | `tools/visual/pixelkit.py` | canvas com repetição, gradiente pontilhado, fonte 3×5, brilho, contorno, cone e radial |
| Biomas | `tools/visual/biome_art.py` → `scene/biomes/visual/biome_styles.gd` | arte e tabela de estilos de cada bioma, de uma fonte única |
| Tema de bioma | `scene/biomes/visual/biome_visual_theme.gd` | parallax, peles, névoa, props, clima e luzes por dados |
| UI | `tools/visual/ui_art.py`, `assets/ui/theme/cyberfield_theme.tres` | painéis, ícones e fonte global |
| Efeitos | `tools/visual/fx_art.py`, `scene/fx/combat_fx.gd` | faísca, explosão, cura, rastro de dash, tremor |
| Qualidade | `scene/fx/visual_quality.gd` | COMPLETO / REDUZIDO / MÍNIMO |
| Props | `tools/visual/props_art.py` | baús, portão de saída, teleporte |
| Hub | `tools/visual/hub_art.py`, `scene/fx/hub_atmosphere.gd` | Casa Jhon estágio 0 |

## 10. Referências internas

- Protagonista: `assets/players/jhon/*_v2*.png` (**aprovado**; folha-modelo pendente).
- Inimigos: `assets/enemies/common/v2`, `assets/enemies/ranged/v2`.
- Arquitetura de laboratório: `assets/environment/laboratory/` (kit aprovado).
- Atmosfera: `scene/animated_menu_background.*` (menu) e
  `scene/biomes/lower_city/lower_city_visual_theme.gd` (Cidade Baixa).
- UI: `assets/ui/gameplay_hud`, `assets/ui/menu_panels`.

## 11. Critérios de qualidade de um asset

1. Transparência real (sem fundo embutido), filtro *nearest* e sem pixels soltos.
2. Uma pose por célula, inteira e alinhada à linha de pés.
3. Respeita a cor de função: ameaça só em inimigos.
4. Lê-se em 50% de zoom e com efeitos desligados.
5. Nome previsível `<entidade>_<estado>_v<N>.png` e procedência registrada.
6. Gerado por ferramenta versionada (`tools/`), de forma determinística, ou com
   licença compatível documentada.
7. Avaliado visualmente em prancha ou captura antes de entrar.
