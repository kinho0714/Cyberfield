# Auditoria visual do Cyberfield — 30/10/2026

Base auditada: `d21cd98`, conteúdo idêntico à branch `visual-lower-city-2026-10-30`
testada no Android. Branch de trabalho: `renascimento-visual-2026-10-30`. Ponto de
recuperação: tag `ponto-recuperacao-pre-renascimento`.

**Método.** Leitura de cenas e scripts, medição automática das folhas de sprite (caixas,
células e fragmentos isolados), pranchas de contato ampliadas e conferência de
referências `res://`. Não houve execução no Godot: as conclusões sobre o que aparece
em jogo vêm do código que monta cada visual.

## 1. Diagnóstico geral

O Cyberfield tem **ilhas de boa arte cercadas de placeholders**. Personagens jogáveis,
inimigos comum e ranged, o kit do laboratório e a UI têm qualidade de produção e
paleta coerente. Mas a experiência de jogo é dominada por superfícies que nunca
receberam arte:

- Industrial e Lab: retângulos chapados.
- O chefe: um inimigo comum ampliado.
- O Heavy: folhas corrompidas.
- O combate: quase sem feedback.
- A tipografia: a fonte padrão do motor.

A Cidade Baixa noturna é hoje o único bioma com direção de arte em jogo.

## 2. Inventário e classificação

Escala: Q = qualidade atual (1–5); I = importância; P = potencial de melhoria;
R = risco de regressão; C = custo.

| Sistema | Onde | Q | I | P | R | C | Observação |
|---|---|---|---|---|---|---|---|
| Jhon (protagonista) | `assets/players/jhon` (11 folhas, células 72 px de altura) | 4 | 5 | 3 | médio | médio | Design forte e consistente: altura de 64 px e pés em y=68–69 em todas as folhas. Tinha defeitos de recorte (corrigidos no lote 0). A sombra no idle aparece em 2 de 4 quadros. |
| Jackson, Kai, Spark | `assets/players/*` | 4 | 3 | 2 | médio | médio | Mesmos defeitos de wall slide (corrigidos). Ainda há fragmentos sem revisão. |
| Inimigo comum v2 | `assets/enemies/common/v2` | 4 | 5 | 2 | baixo | — | Silhueta carmesim clara, lê bem como ameaça. |
| Ranged v2 | `assets/enemies/ranged/v2` | 4 | 4 | 2 | baixo | — | Coerente com o comum. |
| **Heavy** | `assets/enemies/heavy/*_v1.png` | **1** | 4 | 5 | médio | alto | **Folhas corrompidas**: textos de geração ("ATTACK / SHOOT (6 FRAMES)", "JUMP"), recortes ampliados, retângulos opacos e checklist. As células cortam poses ao meio. Isso aparece em jogo a partir da fase 3 (no normal). |
| Chefe (fase 6) | `boss_stage.gd` | 1 | 5 | 5 | médio | alto | É o `Enemy.tscn` comum com escala 1,65. Não há arte, silhueta nem estados próprios. |
| Projéteis | `entities/*projectile*` | 3 | 3 | 3 | baixo | baixo | O projétil do heavy tem lixo de geração na folha de movimento. |
| Cidade Baixa (jogo) | `lower_city_visual_theme.gd` | 3 | 5 | 4 | baixo | médio | Integrada em 30/10. Repete a cada 1440 px e o letreiro "24H" magenta colide com a cor de ameaça. |
| **Industrial** | `industrial.tres` via gerador | **1** | 5 | 5 | baixo | médio | Sem tema: fundo azul opaco e pisos verde-azulados chapados. |
| **Lab (bioma)** | `lab.tres` via gerador | **1** | 5 | 5 | baixo | médio | Mesmo caso do Industrial. O kit do laboratório existe e não é usado aqui. |
| Hub Laboratório | `laboratory_hub.tscn` + `assets/environment/laboratory` (29 PNGs) | 4 | 4 | 2 | médio | — | Kit modular de alta qualidade e procedência própria (manifestos). As folhas de props têm fundo escuro embutido. |
| Casa Jhon | `casa_jhon_hub.tscn` + `assets/environment/casa_jhon` | 3 | 3 | 3 | médio | médio | Kit em estágios 0–3. |
| Assets antigos Cidade Baixa | `assets/environment/cidade_baixa` | 2 | 1 | — | — | — | Lavados e cinzentos; vários com rótulos embutidos (auditoria do Pass 3). Fora de uso. |
| Renderizador temporário | `scene/temporary_environment` | 2 | 1 | — | — | — | Desligado das runs em `d54af98`. Depende de PNGs privados. |
| Menu principal | `animated_menu_background.*` | 4 | 4 | 2 | médio | — | Chuva, nuvens e relâmpagos com shader; é a peça atmosférica mais madura. |
| HUD de combate | `ui/gameplay_hud_presentation.gd`, `assets/ui/gameplay_hud` | 3 | 5 | 3 | médio | médio | Kit limpo e consistente (painéis escuros e cantos ciano), porém genérico. Ícones toscos: "usar" é uma mancha branca. |
| Menus e painéis | `ui/menu_panel_presentation.gd`, `assets/ui/menu_panels` | 3 | 4 | 3 | médio | médio | Mesma linguagem do HUD; estados de foco bons. |
| Fim de run | `ui/run_end_presentation.gd` | 4 | 3 | 2 | baixo | — | Refeito em 29/10. |
| **Tipografia** | nenhuma fonte no projeto | **1** | 5 | 5 | médio | baixo | Fonte padrão do Godot em todo o jogo. |
| **Feedback de combate** | `Enemy.gd`/`player.gd` `take_damage` | **1** | 5 | 5 | baixo | médio | O acerto deixa o sprite semitransparente por 0,1 s, o que lê como "sumiu". A morte some em 0,3 s. Não há faíscas, tremor, *hit-stop* nem efeito de morte. |
| Opções de acessibilidade visual | `local_settings.gd` | 1 | 4 | 4 | baixo | baixo | Não existe opção para reduzir efeitos, flashes ou tremor. |
| Partículas e luz | — | — | — | — | — | — | Partículas só no menu e na chuva. Nenhuma `Light2D`. O único shader é o do menu. |

### Volume e organização

- **376 PNGs**, dos quais só 155 são referenciados literalmente em código. O restante é
  carregado por catálogo ou manifesto, ou é material legado.
- **Duplicatas.** `Cyberfield_Visual_Integration_v1/` (2,2 MB) é cópia byte a byte de
  folhas que já estão em `assets/`. `docs/pass3_baseline/` (2,2 MB) é uma cópia de
  código-fonte e manifestos. `sprites/1 - Penguin` e `sprites/3 - Skeleton` são
  fallbacks do template inicial. Nada foi apagado; a remoção requer confirmação.
- Há 9 recursos privados fora do repositório (áudio do menu, baús e 2 texturas). Sem
  eles, 5 scripts não compilam.

## 3. Problemas de consistência

1. **Cor de função.** O magenta é a cor das ameaças (todos os inimigos, mira e
   projéteis), mas aparece no letreiro "24H" do fundo da Cidade Baixa.
2. **Biomas.** Só um dos três biomas jogáveis tem direção de arte. Ao trocar de fase,
   o jogo "desmonta" visualmente.
3. **Escala.** Personagens com 64 px de altura são legíveis. O chefe é uma ampliação
   de 1,65× de pixel art com filtro *nearest*, o que dá pixels gordos e quebra a
   grade.
4. **Sombras de contato.** Algumas folhas trazem sombra embutida (Jhon idle 1–2,
   corrida); outras não. Resultado: a sombra pisca.
5. **Linguagem de UI × mundo.** A UI é ciano-tecnológica e coerente. O mundo, fora da
   Cidade Baixa, não tem nenhum material que dialogue com ela.
6. **Tipografia.** Uma fonte genérica sem caráter convive com títulos que pedem
   identidade ("CYBERFIELD", "RUN PERDIDA").

## 4. Corrigido neste lote (baixo risco)

| Defeito | Correção | Evidência |
|---|---|---|
| Wall slide dos 4 personagens: células de 4 quadros cortavam poses ao meio; o 4º quadro de Jhon era só uma linha | `tools/visual/repack_wall_slide.py` move cada pose inteira, sem alterar pixels, para uma célula centralizada (A,B,A,B / A,B,C,B). Tamanho das folhas preservado; deslocamentos zerados. | Pranchas antes e depois; a ferramenta é idempotente; o teste agora mede a centralização na própria folha |
| Jhon: pedaços de poses vizinhas (idle, corrida, hurt, wall climb) | `tools/visual/clean_sheet_fragments.py` apaga só os fragmentos revisados do manifesto | 0 pixels alterados fora dos fragmentos |

## 5. Riscos e dependências

- **Sem Godot neste ambiente.** Toda validação visual em execução depende de capturas
  do seu aparelho.
- **Referências aprovadas de Jhon.** O repositório tem só as folhas de animação: não
  há folha-modelo, *turnaround* nem paleta oficial. **Preciso desse material** antes de
  qualquer mudança que vá além de limpeza.
- **Heavy e chefe** exigem arte nova. Gerar personagens por código não atinge a
  qualidade dos demais. As opções estão no plano.
- **Testes de contrato congelado.** Quase todos já divergem da base; usei a comparação
  de asserções como guarda contra regressões.
- **Desempenho.** Nada foi medido em aparelho. Os orçamentos do documento de direção
  são metas, não medições.

## 6. Complexidade (qualitativa)

| Frente | Complexidade |
|---|---|
| Feedback de combate e opção de reduzir efeitos | Média: sistema novo pequeno e 2 pontos de ligação |
| Temas Industrial e Lab | Média: o mesmo padrão do tema da Cidade Baixa, com reaproveitamento do kit do laboratório |
| Tipografia | Baixa técnica, alta de decisão: fonte OFL e tema global |
| Ícones de HUD | Média |
| Heavy | Alta: depende de arte nova ou de recuperação de folhas |
| Chefe | Alta: design, arte e estados |
| Cidade Baixa v2 | Média |
