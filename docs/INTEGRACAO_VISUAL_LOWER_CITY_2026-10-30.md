# Integração visual da Lower City no gameplay — 30/10/2026

Base: `integracao-missao-2026-10-29`. O conteúdo é idêntico a `56d9e0b` / `91f8e47`
(árvore `552985b115d6fdf93eb34623386ca6e95bd0ffee`).

## Diagnóstico

O jogo mostrava o cenário antigo por três motivos somados:

1. **O renderizador de ambiente foi desligado de todas as runs** no commit `d54af98`.
   Foram removidos os 4 pontos em que `BiomeGenerator` instanciava
   `lower_city_presentation.gd`, e o parallax ficou restrito ao hub. Testes passaram a
   garantir isso (`environment_cleanup_smoke_test.gd`, `cidade_baixa_presentation_static_test.py`).
   Esse renderizador antigo (`painter.gd`) depende de PNGs privados que não estão no repositório.
2. **A cena `lower_city_concept.tscn` é isolada**: nada do jogo a carrega.
3. **O fundo de cada módulo é um polígono opaco** (840×480). Mesmo que houvesse cenário
   atrás, ele ficaria invisível durante o gameplay. Pisos e plataformas eram retângulos chapados.

## Solução

Um tema visual novo, só de apresentação, aplicado ao bioma real gerado. O renderizador
antigo não foi religado.

| Arquivo | Mudança |
|---|---|
| `scene/biomes/lower_city/lower_city_visual_theme.gd` (novo) | Tema noturno: fundo em parallax, pisos com textura, postes, poças e chuva |
| `scene/biomes/biome_generator.gd` | `VISUAL_THEMES` e `_apply_visual_theme()`, chamado no fim de `_build_world()` |
| `scene/biomes/biome_definition.gd` | Campo `visual_theme` (vazio por padrão) |
| `scene/biomes/lower_city/lower_city.tres` | `visual_theme = &"lower_city_night"`; só a Lower City ativa o tema |
| `tools/experimental/lower_city_concept.py` | Gera também `street_tile`, `catwalk_tile` e `wall_tile` (os 13 PNGs anteriores ficam idênticos) |
| `assets/experimental/lower_city_concept/*_tile.png` (3 novos) | Texturas repetíveis de rua, passarela e parede |
| `tests/lower_city_visual_theme_smoke_test.gd` (novo) | Teste headless no Godot |
| `tests/lower_city_visual_theme_static_test.py` (novo) | Contrato estático, roda sem Godot |

### O que muda na tela

- **Fundo:** um `CanvasLayer` em `layer = -10` mostra céu, skyline, prédios com letreiros
  HOTEL/FARMACIA/24H (neon com piscada rara), viaduto escurecido e duas camadas de névoa.
  A rolagem horizontal é proporcional à câmera (0,15 a 0,80). Verticalmente, o fundo fica
  ancorado no piso da rua inicial, por isso funciona também com o enquadramento Android
  (pés a 78% da tela) e com o zoom de 0,78 a 1,22. Abaixo da rua dos prédios há um
  preenchimento escuro, para nunca abrir buraco transparente.
- **Módulos:** o fundo opaco vira névoa leve (alfa 0,22 na rua e 0,34 nas outras
  linhas). A cidade aparece atrás do gameplay e o volume da sala continua legível.
- **Pisos:** textura de rua com borda ciano iluminada. Plataformas viram passarela
  gradeada e paredes de poço viram aço rebitado. As UVs são alinhadas ao mundo, sem
  emendas entre módulos.
- **Rua:** postes com cone de luz quente em 2 de cada 3 módulos, a mais de 110 px dos
  pontos de spawn, loot e saída; poças refletindo neon; chuva em duas profundidades,
  seguindo a câmera.

### Garantias

- O tema roda **depois** da assinatura de geração e do spawn de conteúdo. Ele não usa
  RNG nem cria colisões, áreas ou input, e não muda IDs. Com a mesma seed, os pares LAN
  geram o mesmo cenário.
- Só altera propriedades visuais (`texture`, `uv`, `color`) de polígonos já existentes
  e acrescenta nós de apresentação. Os polígonos de piso continuam visíveis, como exige
  o teste de limpeza.
- Os contratos anteriores continuam valendo: nenhuma referência a `CITY_PRESENTATION`,
  `lower_city_presentation.gd` ou `TemporaryParallax` nos biomas.
- Industrial, Lab e Boss não mudam.
- Usa só assets originais gerados por script, nenhum privado.

## Verificação

| Verificação | Resultado |
|---|---|
| Teste estático novo (5 casos) | OK |
| 13 testes Python, em asserção suave | Mesmas 34 asserções falhando da base, todas pré-existentes. Nenhuma nova. |
| `cidade_baixa_presentation_static_test.py` (protege o desligamento antigo) | OK |
| Sintaxe GDScript (gdtoolkit), 130 arquivos | 125 OK. As 5 falhas são lambdas de uma linha, limitação da ferramenta, e já existiam. |
| Referências `res://` | Nenhuma quebrada nova. As 12 existentes são assets privados, pré-existentes. |
| Determinismo dos PNGs | 2 execuções com SHA-256 idênticos; os 13 PNGs anteriores não mudaram |
| Composição | Simulação Python das mesmas fórmulas em desktop 16:9, Android 20:9 e sala superior. É simulação, não captura do Godot. |

**Não executado:** Godot (headless ou editor) e Android real. O motor não está
disponível neste ambiente. `tests/lower_city_visual_theme_smoke_test.gd` e os demais
testes `.gd` precisam rodar com Godot 4.7.

## Riscos

- Desempenho no Android: são 180 partículas de chuva (CPU), 8 sprites de fundo e
  materiais aditivos. É moderado, mas não foi medido em aparelho.
- Os PNGs novos são importados pelo editor ao abrir o projeto. Até a importação
  terminar, scripts que fazem `preload` deles falham.
- Legibilidade: a névoa de 0,22 pode precisar de ajuste depois de ver no aparelho
  (constantes `MODULE_HAZE*` no topo do script).

## Reverter

Remova a linha `visual_theme = &"lower_city_night"` de `lower_city.tres`. O gerador
volta ao visual anterior sem nenhuma outra mudança.
