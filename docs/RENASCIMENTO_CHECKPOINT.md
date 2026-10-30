# Renascimento — checkpoint de progresso

Leia isto antes de qualquer coisa (regras em `CLAUDE.md`). Atualize ao fim de cada etapa.

## Estado (30/10/2026)
- Branch de trabalho: `renascimento-integracao-2026-10-30` (parte de `ad419a7` = R2).
- R2 instalado e testado fisicamente pelo usuário: reconstrução NÃO alcançada
  (ambientes vazios/pretos, visuais antigos, elementos novos invisíveis).
- Godot 4.7.2 oficial (autorizado pelo usuário, SHA-512 conferido) no scratchpad
  `godot/`. Cópia de teste em `run/proj` com **stubs só de teste** dos 6 recursos
  privados (magenta = textura do pintor antigo). Nada disso vai para o repositório.
- Captura real: `run/cap.sh <nome> [w h]` → sincroniza o repo, importa e roda
  `tests/renascimento_capture.gd` (menu, hub 0–3, 4 estágios, panorâmica, profundidade,
  combate) com Xvfb + Mesa. Relatório `RENASCIMENTO_REPORT` por captura.
- Alcance de cenas/scripts/PNGs: `run/reach.py` (resolve class_name e caminhos fixos;
  caminhos com `%s` precisam de prova no motor).

## Achados comprovados no motor
1. Abaixo da rua (poços/descidas) o fundo virava preenchimento quase preto → corrigido:
   plano `under` repete até a base da tela (todos os biomas + chefe).
2. Anteparas do gerador (colunas teal) → pele de parede + acento por bioma.
3. `CombatFx.shake`: `get_meta(nome, null)` gerava erro → corrigido.
4. Heavy usa as folhas reconstruídas (comprovado por probe).
5. CombatFx comprovado: golpe 2 nós, dash 3, morte 5 + capturas. (O "0" inicial era
   erro do teste: câmera ainda na posição anterior / contagem fora do `Main`.)
6. UI comprovada: tema e fonte Pixelify aparecem em pausa, inventário, Meta-Lab,
   atributos e seleção de modo.
7. Smoke tests reais: biome_visual_theme, combat_fx, hub_house_stages e
   casa_jhon_stage0 passam no Godot 4.7.2.

## Próximo passo
- Pedir ao usuário captura do ponto exato do "preto" no aparelho (não reproduzido fora
  dos módulos abaixo da rua e da arena do chefe).
- Laboratório (vazio), arena do chefe (escura), transições, lobby LAN/resultado,
  perfis de efeito. Restos antigos dependem de decisão do usuário (painel de
  depuração do hub, título provisório do chefe).
