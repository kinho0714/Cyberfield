# Contrato de importação visual — Cyberfield

**Concept / Visual Master** é referência artística. **Technical Master** é PNG tecnicamente validado. **Runtime Asset** é arquivo aprovado para uso no Godot. Uma concept sheet nunca se torna runtime automaticamente. Godot recebe somente a última etapa; não há ligação direta com geração local/IA/ComfyUI.

## Requisitos

- **Personagens/inimigos:** PNG RGBA 8-bit, alpha verdadeiro (sem checkerboard pintado), sem texto/UI/cenário; células consistentes, frame count explícito, ordem dos frames, facing, baseline e pivot documentados em pixels. Sem upscale destrutivo. Use nearest-neighbor para pixel art; informe outra filtragem somente quando aprovada. Não presuma que sheets antigos são a arte final.
- **Ambientes:** separe concept/reference dos arquivos de runtime. Sem labels técnicos, títulos `BACKGROUND MID`/`NEAR`, bordas de sheet ou matte acidental. Registre dimensões de tile/módulo e repetibilidade; backgrounds opacos podem declarar que transparência não é necessária. Props recortados exigem alpha real. Atlas de substituição do adapter atual conservam dimensões **e coordenadas/conteúdo das regiões**; dimensão idêntica sozinha não prova compatibilidade.
- **UI:** tamanho nativo, padding [left, top, right, bottom], safe bounds [x,y,w,h], alpha/transparência, estados normal/focused/pressed/disabled quando aplicável. Preserve legibilidade, 9-slice e safe areas PC/Android; não embuta texto que deveria ser localizado.
- **Armas/props:** pivot, anchor, facing e escala no mundo; diferencie icon de runtime/world. O pivot é referência do autor; `animation_offsets` traduz esse contrato para o componente Godot. Arte não redefine hitboxes/alcance.
- **Todos:** ID estável técnico, categoria, origem/referência, versão, uso pretendido, dimensões; se sheet, cell size e frame count; quando aplicável pivot/baseline; SHA-256 opcional. Registre aprovação humana e etapa. IDs nunca usam nome traduzido, posição em array ou NodePath.

## Manifesto e gate offline

Crie manifesto JSON do pacote aprovado. Exemplo de formato (paths e medidas abaixo são ilustrativos, não arquivos existentes):

```json
{"assets": [{
  "id": "enemy_b01_melee_01_idle",
  "category": "enemies",
  "stage": "runtime",
  "runtime_approved": true,
  "source": "referência aprovada / identificação da origem",
  "version": "1",
  "intended_runtime_use": "idle de enemy_b01_melee_01",
  "path": "res://assets/enemies/biome_01/melee_01/idle.png",
  "dimensions": [256, 64],
  "frame_count": 4,
  "cell_size": [64, 64],
  "pivot": [32, 57],
  "baseline": 57,
  "facing": "right",
  "requires_transparency": true,
  "no_embedded_text": true,
  "no_concept_border": true,
  "no_accidental_matte": true
}]}
```

Execute da raiz: `python tools/validate_visual_asset_manifest.py caminho/manifest.json`. A ferramenta usa somente a biblioteca padrão, não altera PNGs nem importa nada no Godot. Rejeita IDs duplicados/inválidos, arquivo fora de assets/, PNG inválido, CRC inválido, formato diferente de RGBA8 não interlaçado, dimensões/células/contagens incompatíveis, metadata obrigatória ausente, checksum incorreto e alpha completamente opaco quando transparência foi exigida. Para UI acrescente `padding`/`safe_bounds`; para weapons/props acrescente `anchor`/`world_scale`. Categorias aceitas correspondem às futuras categorias descritas na arquitetura.

**Limite:** a ferramenta não identifica semanticamente texto, checkerboard, cenário, matte pintado ou bordas de concept. Os três campos `no_*` são declarações de revisão humana, não resultado de detecção. Uma imagem com alguns pixels transparentes ainda pode conter um matte indevido. Inspecione visualmente em fundos claro/escuro e no jogo. O gate não revalida nem reprova retroativamente os assets legados usados como fallback.

## Integração e aprovação

1. Preserve referência/concept fora da rota runtime. Produza/valide Technical Master sem textos, bordas, cenário extra ou resampling destrutivo.
2. Revise visualmente transparência, baseline/pivot, crops, grid e escala. Registre aprovação; só então marque `stage: runtime`.
3. Rode gate, importe no Godot e configure filtro/material sem mudar gameplay. Construa SpriteFrames `.tres` com contagens compatíveis com o adapter atual; veja [arquitetura](CONTENT_VISUAL_ARCHITECTURE.md).
4. Registre perfil/caminho em `content/catalog.tres`. Slots incompletos usam fallback; paths vazios são intencionais.
5. Rode parser/smokes e valide em PC, Android/GL Compatibility, Solo/co-op e LAN quando pertinente. Confira o pacote exportado, memória e dimensão máxima de textura suportada pelos dispositivos alvo.

O pipeline esperado permanece: canon → visual master → referência de poses/animação → geração local → processamento técnico → validação → Technical Master → aprovação runtime → importação Godot.
