# Integração Codex + Claude — 03/11/2026

Workspace: ~/cyberfield-claude.
Branch nova: codex/integracao-gameplay-ui-amizades-2026-11-03.
Base Codex: 7426f3b40ad3c042204a89ac7af671ee036bf908.
A branch codex/gameplay-mundo-coop-2026-11-03 permanece nesse HEAD.
Não houve push, merge para branch compartilhada, reset, checkout forçado,
limpeza do repositório ou cópia para a pasta do Godot Android.

## Integridade e histórico

Arquivos recebidos lidos de /sdcard/Download; instalador NÃO executado.
SHA-256 conferidos com SHA256SUMS-1.txt:
- Patch: a8035327f0204d29122cdc8d70a472e3a060ac608017573ecae427582e9d0e7d
- Instalador: 5b5306d5bfe30d978fe3bf465fd7e5f14ff49ffea9139559de8c7df694c1900a

As três árvores originais também foram reconstruídas e conferidas contra os
valores do instalador em índice temporário, partindo de 9b8d843, sem trocar a
branch atual nem executar o script. Evidência: evidencias/preservacao.json.

Aplicação: git am --3way na branch nova a partir do Codex mais recente.

| Commit original Claude | Commit aplicado | Conteúdo |
| --- | --- | --- |
| a97ead4 | 42152f6 | navegação, campanhas, kit modal/visual, texto seguro |
| e4e901d | 413d924 | perfil, amizades pela sessão, convites, roster e relay |
| ac123f6 | 07bb47e | relatórios, evidências históricas e testes do Claude |

Os quatro commits Codex (765e8b5, 0a1b9ee, 8217505, 7426f3b) permanecem ancestrais.
O commit adicional de integração liga as camadas e registra regressões/evidências.
Não se fez cherry-pick de uma árvore antiga sobre o gameplay novo.

## Conflitos resolvidos

Somente PrivateSessionClient e relay.py tiveram conflito textual no segundo mail.
- Cliente: posição 7 de connect_session aceita o número de assentos do Codex ou o
  cartão público do Claude. Posição 8 permite cartão junto do número de assentos.
  Chamadas anteriores de seis argumentos continuam válidas. TLS continua verificado.
- Relay: required_players 2–4 e recuperação/checkpoints foram mantidos, junto com
  pending_friends, roster sanitizado, solicitações/respostas e revogação do Claude.
  Na retomada, nome/avatar podem ser atualizados pelo cartão do hello; não são
  persistidos no checkpoint. IDs públicos não são inseridos no roster.
- Hashes de retomada, sequências, expiração e backups do Codex não foram substituídos.

## Integração funcional

CampaignController compõe uma única PrivateGameplayBridge com o cliente da UI.
INICIAR COOPERATIVO solicita start ao relay; quando este confirma active, host e
convidados entram no gameplay existente. Fecham-se as telas de título, sem telas
paralelas. Retomada active não cria outra ponte. Todo erro mantém campanhas solo.

begin_private_gameplay()/end_private_gameplay() são os pontos de composição; a UI
não deve instanciar outra ponte. PrivateSessionPanel._leave, retorno ao menu e
abandono encerram a ponte, desconectam, restauram perfil/caminho individual e liberam
pausas pertencentes aos modais. Nenhum dado coop é importado como campanha solo.
Criar/continuar solo é recusado durante conexão/sessão privada pendente ou ativa;
a UI também recusa entrar/criar/iniciar privado sobre uma partida já aberta.

Correções adicionais verificáveis:
- Bind de nova sessão limpa revisão, mundo e sequências anteriores da ponte.
- Falhar antes de iniciar não apaga o perfil nem troca save_path por uma string vazia.
- DEV é indisponível durante coop; controles de convidados continuam passivos ao
  fechar painéis. Serviços do hub permitem acessar social/sala durante coop.
- RoomManager.get_local_gameplay_participant_id()/is_private_guest() expõem o assento
  correto a HUD/inventário. O convidado vê seus próprios dados, não os do host.
- Inventário do convidado fica em consulta; mudanças de equipamento pelo painel
  são desabilitadas e explicadas até existir um comando autoritativo correspondente.
  Isso evita simular uma alteração local que o host não reconhece. Solo/LAN mantidos.
- Amizades continuam passando por SocialBridge/LocalPlayerProfile/relay reais.
  Identidade é declarada por capacidade de sessão; não há autenticação de contas.
  Bloqueio, aceitação, recusa, contatos locais e rascunhos mantêm os rótulos do Claude.

Fontes centrais de dash, inimigos, MissionLedger, WorldTracker e AreaJournal foram
comparadas byte a byte com 7426f3b e estão intactas. As interfaces foram adaptadas
a esses sistemas, sem substituir suas implementações por versões anteriores.

## Validação e reprodução

Motor: Godot oficial 4.7.2 Linux ARM64 headless via PRoot/Termux; NÃO Godot Android
nativo/APK. Projeto e XDG isolados em diretório temporário. Os seis assets privados
necessários ao runtime foram usados apenas na cópia de teste, nunca versionados.
Dados de campanhas/perfis e credenciais TLS são descartáveis, criados pelos testes.

A primeira rodada atualizou a cópia temporária com processos ainda abertos e gerou
uma mistura de scripts carregados. Essa evidência foi descartada como aprovação.
A rodada final usa project-final-2 congelado: nenhum script dessa cópia foi alterado
durante as execuções. Hashes do código testado são conferidos contra o workspace.

Evidências finais, sem herdar aprovação dos relatórios recebidos:
- evidencias/engine-final/engine-results.json: runner com vinte suítes e marcadores
  obrigatórios, exit code e ausência de SCRIPT ERROR. Inclui lifecycle de falha,
  menus/toque/campanhas, social/migração, áudio/gamepad, LAN/touch/HUD, dash/animação,
  IA, exploração, missões/revisita, codec, arsenal, store/sessão, mundo/rotas e DEV.
- evidencias/gameplay-final.log: dois e quatro processos Godot reais, usando o
  controller e o botão da sala, gameplay por WSS/TLS em loopback, amizades durante
  partida, reconexão, HUD/inventário por assento, bloqueio DEV, fechamento de painéis
  e saída pelos painéis de sessão/inventário com pausa/perfil individual restaurados. Não são quatro APKs físicos.
- evidencias/relay-social.log: sete testes do Claude, incluindo quatro processos
  Godot para códigos de convite/roster/amizade aceita/recusada e estados privados.
- evidencias/relay-regressao.log: sete testes Codex, incluindo autorização, rate limit,
  autoridade/revisão, replays, backups e retomada após reiniciar a instância do relay.
- evidencias/static.json: verificações de gramática/regressões/whitespace e hashes;
  não substitui compilação nem validação física.

O runner tools/validate_integrated_expansion.py recusa o workspace original; usar
--godot <launcher> --project <copia-congelada-importada> --output <evidencias>.
Para rede, configurar CYBERFIELD_GODOT, CYBERFIELD_TEST_PROJECT e CYBERFIELD_OPENSSL,
mais dependências de teste fora do repositório. Executar os métodos
PrivateGameplayTests.test_integrated_menu_two_godot_clients e
PrivateGameplayTests.test_integrated_menu_four_godot_clients de
 tests/private_gameplay_test.py. Não atualizar a cópia enquanto o motor a utiliza.

Os avisos de ObjectDB/recursos/RIDs ao encerrar alguns testes permanecem; não se
comprovou ausência de leaks. Capturas gráficas atuais não foram executadas: o script
do Claude exige display. As capturas/evidências recebidas são históricas da base.

## Limites e validação física pendente

Não declarar o coop completo: projéteis/efeitos, baús/drop/mapa compartilhado integral,
escolhas remotas, missões coop, recompensas individuais e recuperação de host morto
continuam pendentes conforme contrato do Codex. Inventário de convidado é consulta;
backend de contas/amigos, vínculo de convites e autenticação real não existem.
Chat continua desativado; TLS não é E2EE. Nenhum serviço/túnel foi publicado.

Validar em campanha descartável no Godot Android, antes de substituir a cópia usual:
1. Navegação/toque/VOLTAR e teclado virtual em 16:9 e 20:9; campanhas independentes,
   renomeação, cancelamento/exclusão individual e CONTINUAR após fechar o jogo.
2. Dash de três usos, quarto bloqueado, recuperação de 1/2/3 usos; rolamento oficial,
   combate, colisões, paredes, plataformas, pulo, DEV solo e inimigos.
3. Perfil/amizades locais e de sessão: aceitar/recusar/bloquear, persistência ao
   reabrir, convite inválido/usado/revogado, ausência de falsa amizade autenticada.
4. Após autorização de endpoint: dois APKs e depois quatro, controles/HUD por assento,
   troca de região, queda/retomada, sair pelo painel com jogo pausado e voltar a solo
   sem mudar créditos/caminho de save. Testar conta/aparelho real e cadeia TLS.
5. Desempenho/bateria/temperatura e suspensão no G14, Windows e falha de armazenamento.

A lista de arquivos alterados contra 7426f3b está em ARQUIVOS.txt. Os seis arquivos
privados continuam não rastreados e com hashes preservados. Saves reais não foram
usados pelos comandos. O projeto permanece nesta branch de integração aguardando
validação física/autorização posterior; nenhuma publicação foi realizada.
