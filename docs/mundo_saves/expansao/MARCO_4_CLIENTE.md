# Marco 4 — perfil local e interfaces de sessão

IMPLEMENTADO e TESTADO AUTOMATICAMENTE: identidade offline persistente sem conta,
ID interno/público separados, nome, contatos locais não verificados, solicitações
locais não enviadas, bloqueio/desbloqueio, privacidade e documentos atômicos com
backups. O teste também recusa regenerar identidade quando todas as revisões de
fixture estão corrompidas. Não existe autenticação online simulada: o método de
backend informa indisponibilidade. Amigos online continuam pendentes.

UI de perfil/mundo/conexão usa os controles e tema existentes; o teste de main real
abre e fecha as páginas sem deixar a árvore pausada. Tela privada explicitamente
identifica protótipo sem gameplay. O cliente WSS não inicia cenas cooperativas nem
altera o transporte LAN. Tokens somente em memória, URL sem credenciais, CA/host
validados e cache separado dos snapshots efetivamente recebidos. Transporte testado
pelo harness do conjunto seguinte; não corresponde a quatro jogadores reais.

Regressões resolvidas nesta integração: callbacks de saída usam agora a prévia do
grafo regional correto; a posição geográfica é ajustada antes de reconstruir uma
revisão anterior; iniciar uma run no DEV não consome seed/contador nem publica áreas
no mundo legítimo, e conserva a marca DEV. O teste de sessão cobre esses casos,
baús coletados, transições, derrota/permanentes e resultado idempotente.

Evidência final em `final/engine-results.json` e logs por teste. O teste headless
não substitui teclado/rolagem/menus físicos no Android e Windows. Os avisos de
recursos/RIDs na saída são mantidos, sem declarar aplicação inteira livre de leaks.
Persistem backend de contas/amigos, convites vinculados a contas e aplicação de
bloqueios por identidade online verificada. Relatório de segurança e conectividade:
`MARCOS_4_5_SEGURANCA.md`. Não considerar Marco 4 completo/homologado.
