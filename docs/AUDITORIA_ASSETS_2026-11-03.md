# Auditoria de assets — 03/11/2026

Escopo: 533 arquivos de conteúdo rastreados sob assets/, 54.759.415 bytes de fontes
(antes de importação; não é tamanho do APK nem memória de GPU).
Os seis arquivos privados não rastreados não fazem parte do inventário publicável.

Evidência por arquivo: `otimizacao_2026-11-03/assets.json`, com tamanho, SHA-256,
classificação e referências literais de runtime. Reproduzir:

```
python3 tools/audit_runtime_assets.py --output /caminho/descartavel/assets.json
```

189 arquivos têm referência literal em scripts/cenas/resources/configuração de
runtime. Os outros 344 permanecem como uso incerto/dinâmico ou artístico: nomes
são compostos por ContentRegistry, catálogos, fábricas/importadores, estilos de
bioma e animações. Ausência de referência literal **não** comprova desuso.
As classificações automáticas são pistas conservadoras, não prova de dependência
transitiva ou autorização para excluir arquivos.

## Duplicados de conteúdo confirmados, preservados

- licenses/cyberpunk_street_CC0.pdf e licenses/warped_city_CC0.pdf: conservar os
  registros das duas origens/licenças; igualdade dos bytes não elimina sua função.
- gameplay_hud/official_manifest.json e menu_panels/official_manifest.json: manifests
  de pacotes distintos. Conservar contratos dos importadores e referências históricas.
- menu/animated/v2/rain_back_drop_v2.png e v3/rain/rain_back_drop_v3.png.
- menu/animated/v2/rain_front_drop_v2.png e v3/rain/rain_front_drop_v3.png.

Os quatro grupos são duplicados binários, mas não obsoletos confirmados. Os dois
conjuntos de chuva pertencem a gerações diferentes de recursos; fábricas e cenas
históricas devem permanecer reproduzíveis. Consolidar caminhos exige migração
explícita e verificação do pipeline artístico, fora de uma exclusão automática.

## Exclusões

**Nenhum asset removido.** Não foi identificado recurso comprovadamente obsoleto
cuja exclusão preserve também as dependências dinâmicas e históricas.
Nenhum save, backup, asset privado, sprite oficial ou fonte artística foi apagado.
A lista de exclusões no JSON é vazia; tudo permanece recuperável no histórico Git.

## Efeito no runtime

Esta rodada reduz trabalho e cópias de dados, não qualidade de arte. Nenhum PNG,
áudio, shader, resolução, iluminação, quantidade de partículas/chuva ou quadro de
animação foi reduzido. A construção visual assíncrona reutiliza as mesmas funções
por geometria/módulo; a revisão visual final continua necessária no aparelho.
