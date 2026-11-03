# Evolução de gameplay e cooperativo — 03/11/2026

Base publicada: 9b8d84332ddaff7c7b8db7a13f7eb0ede48aba4d.
Branch: codex/gameplay-mundo-coop-2026-11-03. Sem push/merge/deploy.
A branch original continua em cd435bcf0e726bfcc8d188fb7820f2c1a6329bd9.

## Entrega e commits

- 765e8b5: dash de três usos, exports e recuperação por inatividade.
- 0a1b9ee: arquivos de áreas revisitáveis, missões por eventos, persistência e
  recompensa única em revisão atômica; APIs para integração do Claude.
- 8217505: invalidação de ataques obsoletos e interrupção por congelamento nas
  classes de inimigos existentes.
- Conjunto final: orçamento de dash em snapshots/rede; ponte WSS de gameplay,
  conversão tipada JSON, sessões 2–4, retomada de capacidades do relay, testes,
  instruções e evidências. Identificável pelo commit feat(coop) desta rodada.

Nenhum menu, HUD, cena visual, perfil social ou asset foi editado. Arquivos
compartilhados e contratos estão em COOP_CONTRATO.md. Não houve merge do Claude.
Não foram criadas missões/Guardas/diálogos canônicos ausentes da Bíblia.

## Implementado com limites explícitos

Dash: orçamento no ponto de entrada, mesmo para chamada direta; intervalo após fim,
recuperação com um/dois/três usos, interrupções, deltas de física e API para HUD.
Design/folhas e controles anteriores preservados. Detalhes em DASH.md.

Mundo: mantém seed/hierarquia/rotas existentes; arquivos de cena por área da run,
retorno com inimigos/objetos e posição preservados, economia e equipamentos atuais.
Descobertas continuam permanentes; não há arquivo de cenário de runs antigas.
UI de revisita depende de integração com Claude. Detalhes em MUNDO_MISSOES_IA.md.

Missões: definições confiáveis, IDs, objetivos/pré-requisitos, estados e eventos
persistentes. Mortes, dinheiro, descobertas e transições conectados; NPC/investigação
possuem API mas conteúdo/cenas ficam pendentes de definição. Apenas créditos como
recompensa nesta versão, sem duplicação após reabertura. Nenhuma missão narrativa
nova é ativada automaticamente; fixtures ficam exclusivamente nos testes.

IA: corrige windup após perda/troca de alvo, valida alcance no impacto e permite
cancelamento reutilizável em comuns/pesados/atiradores. Congelamento impede reinício.
Patrulha, sensores de piso/parede, danos/armas e designs anteriores preservados.

Coop: host Godot real simula gameplay; relay WSS só autoriza/encaminha/guarda recibos
/checkpoints. Ponte opt-in sem tela paralela, ações do convidado e estado do host,
replicação de personagens/inimigos, transição determinística, pausa/reconexão e
escopo de persistência independente. Não equivale a servidor dedicado Python.
Projéteis/efeitos, baús/mapa/interações remotas, missões coop, recuperação de host
morto e integração de UI permanecem essenciais. Ver COOP_CONTRATO.md.

G14: serviço Python compatível com ambiente ARM64, bind loopback, TLS, limites,
capacidade e autorização por sessão; recuperação usa hashes de retomada e recusa
checkpoints expirados. Preparação de implantação e alternativas CGNAT documentadas;
nenhuma configuração pública/serviço pago foi introduzida. Ver BACKEND_G14.md.

## Evidências e reprodução

Godot oficial 4.7.2 Linux ARM64 headless via PRoot no Termux, cópia do projeto e
XDG separados no temporário. A cópia contém os assets privados necessários ao
runtime, lidos sem mudar os originais; esses assets não são versionados. Um clone
GitHub sem tais dependências aprovadas não reproduz a cena completa automaticamente.

- evidencias/engine/engine-results.json: suítes reais, exit code, marcador e
  ausência de SCRIPT ERROR. Inclui dash, IA, gameplay/missões/revisita, codec,
  animação oficial, arsenal, store/sessão, mundo/rotas, perfil, DEV e exploração.
- evidencias/gameplay-wss.log: dois e quatro processos Godot reais com main.tscn,
  WSS/TLS e certificado validado em loopback; movimento no host por input remoto,
  bioma, dano replicado, autorização e queda/retomada. Há uma barreira no harness
  para que os participantes encerrem somente após todos verificarem a retomada.
  IDs de assento são atribuídos pelo servidor, não pela ordem de inicialização.
- evidencias/relay-tests.log: sete testes, incluindo convites/replay/rate limit,
  estado só do host, quatro assentos, retomada e recuperação com hashes após
  reinstanciar serviço, incluindo expiração; um Godot + três clientes Python
  no teste preexistente de transporte. Não confundir com quatro aparelhos físicos.
- evidencias/static-results.json: gramática/regressões/whitespace e seis hashes;
  não substitui motor. Android físico explicitamente pendente.
- evidencias/protocol-benchmark.json: microbenchmark sintético local ARM64;
  não representa FPS, consumo de bateria ou capacidade de quatro clientes online.

Runner: python3 tools/validate_integrated_expansion.py --godot <launcher>
--project <copia-isolada-importada> --output <evidencias>. Ele recusa o workspace
original. PYTHONPATH precisa incluir dependências de teste instaladas fora do repo.
Rede: CYBERFIELD_GODOT e CYBERFIELD_TEST_PROJECT apontam ao launcher/cópia;
CYBERFIELD_OPENSSL ao OpenSSL. Executar explicitamente os dois métodos
PrivateGameplayTests.test_two_real_godot_gameplay_clients e
PrivateGameplayTests.test_four_real_godot_gameplay_clients de
 tests/private_gameplay_test.py. Usar PYTHONDONTWRITEBYTECODE=1 evita caches no repo.

Avisos de ObjectDB/recursos ainda aparecem em testes integrados; não foi comprovada
eliminação de leaks. Os testes verificam comportamento e erros de script, não
homologação de performance. Não houve novo teste manual no Godot Android/Windows.

## Preservação e próxima etapa

Seis assets não rastreados conferidos por SHA-256 e nunca adicionados ao índice.
Saves reais não foram usados nos testes. Commits usam o noreply confirmado, sem
mudar configuração global. Código/testes/documentação revisados para segredos.
A publicação desta branch exige autorização separada; nenhum push foi realizado.

Próximo: playtest Android do dash; Claude integra APIs de áreas/missões/ponte em sua
UI; completar interações/projéteis/mapa e persistência da simulação coop antes de
homologar quatro APKs pela internet. Roteiro em VALIDACAO_ANDROID.md.
