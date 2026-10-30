# Cyberfield — regras permanentes para o Claude

Godot 4.7, GL Compatibility, alvo Android (o usuário testa pelo Godot Android + Termux).
Respostas ao usuário: curtas, em português. Prioridade: código, integração, testes.

## Processo (obrigatório)
1. **Retomada:** leia `docs/RENASCIMENTO_CHECKPOINT.md` primeiro. Não refaça análises
   já registradas lá; atualize-o ao fim de cada etapa (estado, próximo passo, evidências).
2. **Integração antes de arte nova.** Antes de gerar qualquer recurso, comprove que o
   recurso anterior aparece no jogo real. Recurso que não chega à tela não conta.
3. **Por sistemas completos**, não por bioma: fundo, superfícies, adereços, luz/clima,
   UI, FX, personagens, inimigos, hub. Não concentrar tudo na Cidade Baixa.
4. **"Concluído" exige evidência de integração**: captura/log do Godot real ou teste
   em cena do jogo (smoke test carregando a cena de verdade). Validação estática
   (parser, Python) é só "integração não comprovada". Simulação PIL nunca é evidência.
5. Estado real de cada sistema em `docs/RENASCIMENTO_CHECKLIST.md`, com a evidência.

## Segurança do projeto
- Trabalhar em branch nova; nunca push/merge/publicar sem autorização explícita.
- Preservar gameplay: lógica, timings, colisão, RNG, IDs, LAN, input. Mudança funcional
  só com motivo documentado e aprovação do usuário.
- Preservar branches anteriores e backups; não apagar assets sem checar dependências.
- Não incluir recursos privados/licenciados no patch; não criar arquivos falsos para
  mascarar erros de carregamento. Recursos privados conhecidos: 4 áudios de
  `assets/audio/menu/` e 2 texturas de `assets/temporary_environment/architecture/`.
- Arquivos congelados por teste (não editar): `scene/casa_jhon_hub.tscn`,
  `default_bus_layout.tres`; funções congeladas do menu de pausa (`_load_controls` etc.).
- Não afirmar FPS/desempenho sem medição real.

## Entrega ao usuário
- Patch `git format-patch --binary --no-renames` + instalador Termux (SHA-256, checagem
  da base por árvore Git, verificação commit a commit em índice temporário, backup,
  branch nova, rollback, aviso de recursos privados). Testar o instalador em clones.
- Cadeia de branches no aparelho: `visual-lower-city-2026-10-30` (base) →
  `renascimento-total-r2-2026-10-30` (R2, testado fisicamente pelo usuário).

## Validação disponível aqui
- `gdparse` (venv no scratchpad), testes `tests/*_static_test.py`, harness de asserções
  (34 falhas pré-existentes conhecidas; o conjunto não pode mudar).
- Smoke tests `tests/*_smoke_test.gd` exigem o binário do Godot (precisa de autorização
  do usuário para baixar o oficial).
