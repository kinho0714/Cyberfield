# Pass 3 — auditoria física dos assets ambientais

Data: 03/10/2026. Source of truth: PNGs físicos, scripts e manifests no workspace; nenhuma imagem foi modificada ou gerada. Métricas completas: `pass3_asset_metrics.json`; hashes originais: `pass3_baseline/files.json`.

## Método e classificações

Inspeção visual dos dez PNGs efetivamente ligados à apresentação da Casa/Cidade; abertura por System.Drawing para dimensões, formato, contagem de alpha zero/parcial/opaco, pixels claros opacos e bounding box global. Bounding box usa `[left, top, right_exclusive, bottom_exclusive]`. Pixels claros são R/G/B >=150 e alpha=255; a contagem não distingue automaticamente material claro de matte. Regiões de runtime foram confrontadas com os `_draw()` e os manifests. Nenhum chroma key ou threshold foi aplicado: apagaria também pixels legítimos.

- A: região utilizável em runtime.
- B: problema observado; requer correção/novo recorte autorizado, sem garantia de correção automática segura.
- C: referência/concept usado como asset final.
- D: inadequado como sprite final na forma atual; precisa substituição/produção de arte.

Uma classificação do PNG inteiro não torna todas as regiões válidas. Atlas mistos exigem aprovação por região. `audit_pass3_regions.ps1` reproduz a inspeção dos 34 recortes distintos em uso; `pass3_region_metrics.json` registra alpha e bounding boxes locais, todos dentro dos atlas.

## Casa de Jhon

| PNG em `assets/environment/casa_jhon/assets/` | Tamanho | Classificação física | Uso/decisão |
| --- | --- | --- | --- |
| `structural/casa_jhon_structural_base_stage0_v1.png` | 488×139 | Misto A/B | Interiores retangulares de piso/parede são utilizáveis; portas, escada e detalhes de contorno têm matte claro. Preservados os recortes existentes; geometria e anchors não foram alterados. |
| `props/casa_jhon_props_domestic_stage0_v1.png` | 319×146 | B; regiões com fundo grande são D para apresentação final | Alpha binário; 8.027 pixels claros opacos no atlas. TV, plantas/prateleiras e mobiliário deixam resíduos visíveis no render. Não são apenas espaços transparentes ou bug de posicionamento. |
| `props/casa_jhon_props_workshop_stage0_v1.png` | 323×146 | C como atlas inteiro; B nos recortes superiores | Contém legendas de concept entre fileiras. Pass 2 já limitava bancadas aos 40px superiores, evitando legendas, mas permanece contaminação clara nas bordas. |
| `gameplay/casa_jhon_gameplay_interactives_stage0_v1.png` | 344×146 | B/referência para apresentação | Preservado como arquivo; não é desenhado pelo novo `casa_jhon_presentation.gd`. Componentes funcionais continuam separados da arte. |

Proveniência: master manifest aponta ao concept `24945.png` e declara várias regiões `runtime_ready=true`. Essa aprovação documental não garante isolamento de alpha. O README já distingue referências e componentes bloqueados; a captura `pass3_captures/house.png` confirma que outros objetos também precisam revisão.

Escala: mobiliário ~2× (alguns detalhes 3×), personagem com altura de referência ~64px; nearest é preservado. Alterar escala não remove matte e não uniformiza a densidade de detalhe de um recorte de concept. A Casa ainda NÃO atingiu o critério visual final. Só foram reduzidos serviços industriais repetidos na zona doméstica. Layout ocupado foi preservado para não substituir a casa por um espaço vazio.

Entrega de arte necessária: portas isoladas; cama/sofá/mesa/cadeiras; geladeira; TV e terminal; plantas/prateleiras; bancada/oficina e armazenamento. Fornecer alpha limpo, sem legendas, pivô/base no chão e escala consistente com o player. Não há justificativa segura para apagar pixels claros por cor.

## Cidade Baixa

| PNG em `assets/environment/cidade_baixa/` | Tamanho | Classificação | Uso/decisão |
| --- | --- | --- | --- |
| `backgrounds/cidade_baixa_background_far_v1.png` | 493×53 | A apenas como vista finita; insuficiente como parallax final | Opaco, sem título visível, bordas não contínuas. Usado a tamanho nativo em apenas uma variante entre três; nenhuma repetição seamless alegada. |
| `backgrounds/cidade_baixa_background_mid_v1.png` | 493×54 | C | `BACKGROUND MID (MÉDIO)` embutido no canto superior esquerdo. Removido completamente do script de runtime. |
| `backgrounds/cidade_baixa_background_near_v1.png` | 493×74 | C | `BACKGROUND NEAR (PRÓXIMO)` embutido no canto superior esquerdo. Removido completamente do script de runtime. |
| `structural/structural/cidade_baixa_structural_tileset_v1.png` | 768×640 | B | 100.722 pixels com alpha parcial, 7.167 opacos. A translucidez ampla contribui para a apresentação escura; serviços/silhuetas também têm bordas claras. Recortes permanecem limitados à geometria física existente. Não aprovar como tiles sólidos finais sem revisar alpha. |
| `props/cidade_baixa_props_v1.png` | 768×360 | B/D | 71.165 pixels com alpha parcial, 4.901 opacos. Mesmo caixas têm translucidez ampla. Máquinas e outros elementos carregam matte/gutters/resíduos. Preservados provisoriamente; não aprovar o atlas inteiro como sprite final. |
| `gameplay/cidade_baixa_gameplay_interactives_v1.png` | 768×259 | C como sheet inteiro; B/D para vários sprites | Contém labels técnicos e áreas cinzas incorporadas. O recorte da saída exclui os títulos, mas seu contorno ainda precisa arte limpa. Não confundir essa saída com o teleporter cyan funcional. |

Manifest de backgrounds: origem são faixas exatas da seção Backgrounds/Parallax do concept, `scale=1:1`, `NON_REPEATABLE`, alpha 255 em toda a imagem. A intenção anterior de "componente opaco" não torna os títulos aceitáveis. Não houve máscara/crop arbitrário para esconder MID/NEAR; as duas dependências foram retiradas. Os arquivos permanecem arquivados.

Limitações restantes: FAR ainda é uma pequena faixa de concept; máquinas/saídas precisam sprites limpos; composição continua repetitiva e há vazio abaixo da geometria. Não foi criada arquitetura procedural nova ou arte artificial para preencher esses espaços. Nenhum RNG, room, colisão, spawn, shaft, inimigo, reward ou teleporter foi alterado.

## HUD: causa adicional confirmada por render

`portrait_frame.png` tem centro opaco. Desenhá-lo depois do personagem escurecia o recorte. Pass 3 desenha o frame antes do personagem real; o render final confirma cabeça/torso legíveis. PNG, sprite do player e animações foram preservados.

## Aprovação

Auditoria física dos arquivos e render automatizado executados. NÃO equivale a aprovação física completa de gameplay. Casa e parte dos props da Cidade permanecem dependentes de arte final limpa. Não classificar o passe inteiro como visualmente concluído.
