# Social e cooperativo — arquitetura (03/11/2026)

Separação por camadas (nenhuma tela grava dados diretamente):

| Camada | Arquivo | Papel |
| --- | --- | --- |
| Persistência | `scene/persistence/atomic_document.gd` (Codex) | JSON com checksum, temp+rename, 3 revisões |
| Perfil (modelo) | `scene/social/local_profile.gd` | identidade local, amigos, solicitações, bloqueios, privacidade |
| Texto seguro | `scene/social/text_safety.gd` | nomes sem controles/bidi/invisíveis, IDs normalizados |
| Transporte | `scene/network/private_session_client.gd` (Codex + 03/11) | WSS/TLS validado, sala, assentos, roster, social, revogação |
| Convite | `scene/network/private_invite_code.gd` | código `CF1-…` (endereço + sessão + capacidade), decodificação estrita |
| Ponte social | `scene/social/social_bridge.gd` | liga sessão ↔ perfil; pedidos enviados só em memória |
| Servidor | `tools/private_coop/relay.py` (Codex + 03/11) | autoridade de admissão, roster sanitizado, encaminhamento social |
| Apresentação | `ui/cyber_ui.gd`, `ui/cyber_modal.gd`, `scene/social/social_panel.gd`, `scene/network/private_session_panel.gd`, `scene/persistence/campaign_panel.gd`, `scene/persistence/campaign_services.gd` | telas; só chamam as camadas acima |
| Composição | `scene/persistence/campaign_controller.gd` | cria os nós e atende às intenções do menu (`mode_select.gd`) |

## Amizades: o que é real hoje

- **Sem servidor de contas.** `authenticate_online()` devolve `ERR_UNAVAILABLE`;
  o botão "ENVIAR PELA INTERNET" fica desabilitado com o motivo. Nada é simulado.
- **Contato local** (`local_unverified`): adicionado pelo ID público, só neste aparelho.
- **Rascunho de solicitação** (`local_pending_not_sent`): guardado, rotulado como não
  enviado, cancelável.
- **Solicitação pela sessão privada** (real): entre participantes já autorizados por
  convite na mesma sala. O relay só encaminha para assento conectado da mesma sala,
  limita 12 pedidos por assento e por sessão, e só aceita resposta para um pedido
  pendente. A recusa não revela o cartão de quem recusou. Aceitar vira
  `session_mutual_unverified`: confirmado pelos dois lados, identidade **declarada**.
- **Bloqueio** local: descarta pedidos do ID (sem avisar o remetente), remove dos
  amigos e das solicitações; normalização de maiúsculas impede contorno pelo formato.
  Não impede alguém de usar um código de convite já enviado → revogar convites.
- A lista da sala (roster) mostra só assento, nome e retrato. IDs públicos só viajam
  dentro de uma solicitação explícita. O relay não grava o grafo social.

## Para amizades online de verdade (pendente)

Requer backend autenticado (ex.: Nakama com servidor autoritativo, ou serviço próprio)
com: contas verificadas, amizades confirmadas no servidor, bloqueios aplicados no
servidor, convites vinculados a contas, presença com consentimento, e credenciais
guardadas com Keystore (Android)/DPAPI (Windows) — nunca em texto puro no `user://`.
A interface já separa "local", "pela sessão" e "pela internet" para receber isso sem
reescrever telas.

## Gameplay cooperativo: o que falta para 4 jogadores reais

O protocolo valida sala, inputs rotulados pelo servidor, snapshots com revisão e
eventos idempotentes, mas **não move personagens**. Ponte proposta (incremental):
1. Anfitrião: ao `active`, instanciar participantes 2–4 como na LAN atual
   (`room_manager._create_network_players`) e alimentar o input deles com
   `PrivateSessionClient.input_received` (ações já filtradas pelo relay).
2. Anfitrião publica um snapshot compacto (posições/estado/vida) a 10–15 Hz com
   `publish_snapshot`; convidados aplicam com interpolação, como o cliente LAN faz.
3. Transições de sala e recompensas como `publish_event` (ledger idempotente).
4. Persistência coop separada das campanhas solo (já é: `user://coop_received_v1`).
5. Só então testar quatro APKs em redes reais.
Reaproveitar a predição/autoridade da LAN (`scene/network/lan_session.gd`) é preferível
a criar uma segunda pilha de replicação.

## Criptografia ponta a ponta (estudo; não implementada)

TLS protege o trajeto aparelho ↔ servidor; o relay (e a borda do túnel) veem os dados.
Para um chat privado futuro:
- Protocolos estabelecidos: Signal (X3DH + Double Ratchet) para conversas 1:1; MLS
  (RFC 9420) para grupos. Não inventar criptografia própria.
- Godot não traz essas primitivas prontas (o `Crypto` nativo tem RSA/AES/HMAC, sem
  X25519/Ed25519); exigiria GDExtension auditada (ex.: libsodium) e verificação de
  chaves entre amigos (código de segurança comparado fora do jogo).
- O servidor continuaria necessário para entrega, limites e denúncia; o conteúdo
  não seria legível por ele.
- Até existir isso implementado e validado, a interface diz explicitamente que **não
  há** ponta a ponta e o chat segue **desativado** no relay.
