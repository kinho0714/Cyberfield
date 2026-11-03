# Refinamento de UI, amizades e integração cooperativa — relatório (03/11/2026)

Branch local `claude/refinamento-ui-amizades`, criada a partir de
`origin/codex/expansao-privada-2026-11-03` (`9b8d843`). **Sem push** (aguarda autorização).
Branches oficiais e a branch do Codex não foram alteradas. Saves reais não foram lidos
nem escritos: todos os testes usam namespaces `user://test_*` descartáveis numa cópia
isolada do projeto com XDG separado.

Godot **4.7.2.stable.official.ed1daf0bf** (Linux x86_64, ZIP oficial com SHA-512
conferido; o mesmo binário autorizado nas missões anteriores). Recursos privados
substituídos por stubs **somente na cópia de teste**.

## Etapa A — auditoria (o que existia)

| Sistema | Estado encontrado | Problema |
| --- | --- | --- |
| Menu inicial | `ModeSelect` (JOGAR/OPÇÕES/SAIR → SOLO/COOP → dificuldade → mesmo dispositivo/LAN) | O controlador do Codex injetava "CAMPANHAS SOLO" e "PERFIL / COOP PRIVADO" **acima de JOGAR**, sem o estilo do menu (adicionados depois do `_ready` da página) |
| Campanhas | `CampaignStore`/`CampaignController` funcionais (aprovados no Android) | Painel com botões de largura total, fontes pequenas, "revisão N" exposta, renomear dependente de um campo no topo |
| Perfil/contatos | `LocalPlayerProfile` com contatos, rascunhos, bloqueio | Sem solicitações recebidas/aceitar/recusar/cancelar; tudo numa lista longa no painel MUNDO/SESSÃO |
| Coop privado | Relay WSS + `PrivateSessionClient` (1 Godot + 3 Python testados) | UI com 3 campos crus (endereço, sala, token), sem estados legíveis, sem lista de participantes; "servidor indisponível" não era detectado |
| Duplicações | Duas entradas de coop (COOP do menu e "PERFIL / COOP PRIVADO") | Seção paralela |

Captura "antes" e "depois" no fluxo real: ver Evidências.

## Etapa B — menu principal

```
MENU PRINCIPAL: JOGAR · SOCIAL · OPÇÕES · SAIR
JOGAR: CAMPANHA SOLO · COOPERATIVO · VOLTAR
CAMPANHA SOLO: CONTINUAR CAMPANHA · CRIAR CAMPANHA · GERENCIAR CAMPANHAS · PARTIDA AVULSA · VOLTAR
COOPERATIVO: MESMO DISPOSITIVO · REDE LOCAL (LAN) · CRIAR SESSÃO PRIVADA · ENTRAR EM SESSÃO · CONVITES · VOLTAR
SOCIAL: MEU PERFIL · AMIGOS · SOLICITAÇÕES · JOGADORES BLOQUEADOS · VOLTAR
```

- Uma única seção COOPERATIVO: os modos existentes (mesmo dispositivo, LAN) e a sessão
  privada. O tipo de coop é escolhido **antes** da dificuldade; o lobby LAN e a
  autoridade do host não mudaram, e o retorno do lobby volta à página COOPERATIVO.
- **PARTIDA AVULSA** mantém o modo antigo (perfil clássico) com as quatro dificuldades;
  campanhas seguem em NORMAL como o Codex implementou (sem mudança funcional).
- CONTINUAR CAMPANHA abre a campanha jogada por último; a página mostra
  "ÚLTIMA: nome • data". Sem campanhas, o botão fica desabilitado e o foco vai para CRIAR.
- Painéis abertos a partir do título mostram a cidade animada por trás (o
  `MenuEnvironment` reconhece o grupo `title_menu_modal`).
- Contrato de teste alterado (documentado): `focused_stabilization_input_audio_test`
  agora navega JOGAR → CAMPANHA SOLO → PARTIDA AVULSA → dificuldade.

## Etapa C — campanhas (formato do save inalterado)

Cartões por slot (número estável pela data de criação), estado (NO HUB / EM EXPEDIÇÃO •
ESTÁGIO N / RETOMADA AUTOMÁTICA / BACKUP ÍNTEGRO EM USO), painel de detalhe com créditos,
sucata, nível da casa, expedições, salas exploradas, datas locais, CONTINUAR, MUNDO,
renomear (campo próprio do slot) e exclusão em duas etapas com CANCELAR. A exclusão
continua sendo o arquivamento do Codex (texto da tela diz isso). O resumo de progresso
é **somente leitura** (`CampaignStore.progress_summary`): nenhum campo novo é gravado.

## Etapa D — social

Existia: identidade local, contatos locais, rascunhos, bloqueio. Novo:
- **Solicitações recebidas** (`incoming`) com ACEITAR / RECUSAR / BLOQUEAR;
  **enviadas** com CANCELAR (pedidos pela sessão ficam só em memória; rascunhos locais
  persistem e dizem "NÃO ENVIADO").
- **Pedido de amizade real entre participantes da sessão privada** (relay encaminha só
  para assento conectado da mesma sala, limita 12 por assento, aceita resposta só para
  pedido pendente; recusa não revela o cartão de quem recusou). Aceito pelos dois lados
  → `session_mutual_unverified` (identidade declarada, não verificada).
- **Retrato** escolhido entre os quatro jogáveis, recortado do 1º quadro do idle oficial
  (nenhuma arte nova). Nome público até 24 caracteres, sanitizado.
- **Privacidade**: solicitações "da sessão" ou "ninguém"; convites "amigos"/"ninguém"
  (preferência para o backend futuro); presença privada.
- **Sem servidor de contas**: "ENVIAR PELA INTERNET" desabilitado com o motivo. Nenhuma
  operação online é simulada.
- Compatibilidade: perfis antigos (sem `incoming`/`avatar`, bloqueio `true`) carregam
  sem regravação; as chaves novas só são gravadas na próxima alteração do usuário.

## Etapa E — cooperativo

Tela COOPERATIVO PRIVADO com abas SALA / CRIAR SESSÃO / ENTRAR / CONVITES, sobre o
cliente WSS real:
- **Código de convite único** `CF1-…` (endereço + sessão + capacidade). O anfitrião
  copia um código por convidado; o convidado cola (botão COLAR) e entra. Decodificação
  estrita (prefixo, base64url, sem NUL, 4 campos, `wss://` sem credenciais/parâmetros).
- **Convites**: contagem regressiva estimada dos 10 min, "Para: amigo" (rótulo local para
  lembrar quem recebeu cada código) e **REVOGAR CONVITES NÃO USADOS** (novo no relay).
- **SALA**: estado legível (OFFLINE, CONECTANDO, NA SALA, PROTOCOLO ATIVO, PAUSADA,
  RECONECTANDO, SUSPENSA, ERRO), quatro assentos com nome/retrato/conectado, validação
  de 4 conexões (texto deixa claro que ainda não inicia partida) e SAIR.
- **Servidor indisponível** agora é detectado (`server_unavailable`) e explicado.
- Relay: `roster` (assento, nome, retrato, conectado — sem IDs) e operações sociais.

**Estado real do coop:** transporte, admissão, sala, convites, social e protocolo de
inputs/snapshot funcionam com **quatro clientes Godot reais** em TLS de loopback.
**Gameplay sincronizado NÃO existe** (personagens não são criados nem replicados pela
sessão privada). Não testado com quatro APKs nem em rede real/internet. Plano da ponte
em `ARQUITETURA_SOCIAL_COOP.md`.

## Etapa F — segurança e privacidade

- Nomes sanitizados no cliente **e** no relay (controles, quebras, marcas bidi e
  invisíveis): impede nomes que se passam por outros na lista. Teste confirma.
- IDs normalizados (maiúsculas/hífens) antes de qualquer comparação: um bloqueio não é
  contornado escrevendo o ID com outra capitalização. Teste confirma.
- Minimização: roster sem IDs; cartão social com 3 campos; recusa sem cartão; relay não
  grava o grafo social (teste lê o disco); `public_view` sem ID interno/grafo.
- Segredos: chave do anfitrião, convites e retomada só em memória; campos mascarados e
  limpos após o uso; só o endereço `wss://` é lembrado (teste confere o arquivo).
- Respostas de amizade não solicitadas são recusadas no relay **e** ignoradas no cliente.
- Lista de recebidas limitada (32) e pedidos por assento limitados (12).
- TLS com validação normal do Godot; **não é ponta a ponta** (dito na tela). Chat segue
  desativado. Estudo de E2EE em `ARQUITETURA_SOCIAL_COOP.md`.
- Hospedagem no G14: projeto e checklist em `HOSPEDAGEM_PRIVADA_G14.md`; nada publicado.

## Etapa G — polimento

Kit `ui/cyber_ui.gd` + `ui/cyber_modal.gd` sobre as texturas oficiais de
`assets/ui/menu_panels` (painel com scanlines, abas, cartões, painel de detalhe magenta,
linhas do menu de pausa) e o tema/fonte existentes: cabeçalho com barra magenta, abas,
corpo rolável + coluna de detalhe (aproveita 20:9), rodapé com mensagem colorida
(ok/aviso/erro/ocupado) e VOLTAR; botões de 52 px, estados hover/pressionado/
desabilitado/foco, transição de entrada, confirmação em duas etapas, toque por
`TouchScrollRouter`, teclado virtual nos campos, gamepad/teclado por foco nativo.
Termos internos traduzidos (BAIRRO/MUNICÍPIO, provisório/confirmado/reservado).

## Testes executados (resultados reais)

| Teste | Resultado |
| --- | --- |
| `tests/social_menu_smoke_test.gd` (main.tscn real: toque, navegação, campanhas pela UI, social, servidor indisponível real, LAN, hub) | **failures=0** |
| `tests/social_profile_smoke_test.gd` (estados, migração, bloqueio, sanitização, convite) | **failures=0** |
| `tests/private_relay_social_test.py` — 6 testes de relay em TLS real | **6/6 OK** |
| `tests/private_relay_social_test.py::test_four_real_godot_clients` — anfitrião + 3 convidados Godot | **OK em 3/3 execuções** (convites por código, roster, amizade aceita mútua, recusa, inputs rotulados, snapshot recebido e salvo) |
| `tests/private_relay_test.py` (Codex, 6 testes, inclui cliente Godot) | **6/6 OK** com o relay modificado |
| `tests/social_menu_capture.gd` (17 capturas, 1600×720) | ok (ver Evidências) |
| Suíte Godot completa (62 scripts `extends SceneTree`) | **55/62**; base do Codex 54/59. Mesmas falhas pré-existentes (ver abaixo) |
| Testes estáticos Python | mesmo conjunto de falhas da base (10 pré-existentes) |
| Harness de asserções suaves | 35 na base do Codex = 35 agora (mesmas asserções) |

### Suíte completa — comparação com a base (`evidencias/suite_*.txt`)

- Falham **na base e agora**, sem relação com esta missão: `content_visual_foundation`,
  `pass6_hotfix2_scroll` (asserções antigas → timeout), `mega_pass_ui_integration`
  (timeout), `phase8_lan_lobby_process` (exige dois processos com papel em variável de
  ambiente), `private_transport` (só roda dentro do harness Python, que passa).
- `private_session_peer_smoke_test` (novo) também só roda dentro do harness (passa lá).
- `casa_jhon_stage0_smoke_test` é **instável e independente desta mudança** (cena do
  hub congelada e idêntica): passou na suíte da base e falhou na suíte final; isolado,
  falhou 3/3 na base e passou 3/3 no estado final (`evidencias/casa_jhon_stage0_instavel.txt`).
- Testes do Codex relacionados (campanhas, mundo, rotas, perfil, DEV, exploração) e os
  de menu/toque/LAN (`focused_stabilization_input_audio`, `visual_pass3`,
  `phase8_lan_lobby_touch`, `android_touch_hud_modal_hotfix`) passam.

### Entrega por patch (Termux)

`cyberfield_ui_amizades_2026-11-03.patch` (`git format-patch --binary --no-renames`,
base `9b8d843`) + `instalar_cyberfield_ui_amizades_2026-11-03.sh`: SHA-256, base pela
árvore Git, verificação commit a commit em índice temporário, backup, branch nova
`claude/refinamento-ui-amizades`, `--rollback`, `--verificar` e aviso dos recursos
privados. Testado em clones que simulam o aparelho (mesma árvore, hash diferente, sem
identidade Git): **25/25** casos (instala, já instalado, rollback, recusa alteração
local, base errada, arquivo solto e patch corrompido, recursos privados ausentes).
O patch não contém recursos privados nem segredos. Aparelho: PENDENTE.

Pendentes (não executados aqui): Android físico (toque real, teclado virtual, 20:9),
Windows, quatro APKs em rede real, túnel/endpoint público, desempenho no G14.

## Instruções para testar no Godot Android

Preserve os saves reais; use uma campanha descartável para exclusão.
1. Menu: JOGAR, SOCIAL, OPÇÕES, SAIR; nada acima de JOGAR. Toque e VOLTAR do aparelho.
2. JOGAR → CAMPANHA SOLO: CONTINUAR deve abrir sua campanha mais recente na posição
   salva (repita o teste aprovado de fechar e reabrir). GERENCIAR: cartões, detalhe,
   renomear, MUNDO, excluir → CANCELAR; excluir só uma campanha de teste.
3. PARTIDA AVULSA → dificuldade: o modo antigo continua igual.
4. COOPERATIVO: MESMO DISPOSITIVO (com controle P2) e REDE LOCAL (LAN) devem funcionar
   como antes (agora a dificuldade vem depois da escolha).
5. SOCIAL: renomear, trocar retrato, adicionar contato por ID, rascunho e cancelar,
   bloquear/desbloquear; fechar o jogo e reabrir para conferir.
6. COOPERATIVO → CRIAR SESSÃO com um endereço inexistente: deve dizer "Servidor
   indisponível". ENTRAR com texto aleatório: "Código de convite inválido".
7. No hub: MUNDO / SESSÃO pausa o jogo; abas MUNDO/SOCIAL/COOP; fechar retoma.
Registre aparelho, commit, passos, esperado/observado e o erro completo se houver.
