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

## Gameplay cooperativo integrado (Codex + Claude)

O controlador de campanhas agora conecta a sala do Claude à PrivateGameplayBridge
quando o relay confirma active. O botão INICIAR COOPERATIVO solicita início; todos
os aparelhos autorizados iniciam o gameplay. O host Godot simula, o relay autoriza e
encaminha; não existe servidor dedicado Python de física. Dash/IA/missões e código
novo do Codex foram preservados. O convidado permanece uma réplica passiva.

Retorno ao menu ou SAIR DA SESSÃO para a ponte antes de restaurar o perfil individual.
Campanha solo e sessão privada não abrem simultaneamente. DEV é recusado em coop.
Solicitações de amizade continuam possíveis entre assentos autorizados e persistem
somente nos perfis locais, sem contaminar o estado compartilhado de gameplay.

Ainda faltam interações/mapa/projéteis completos, retomada de host morto, backend de
contas e quatro APKs em redes reais. Não declarar coop completo/homologado.
Contrato e evidências atuais: ../integracao_2026-11-03/RELATORIO.md e
../gameplay_mundo_coop/COOP_CONTRATO.md. As evidências originais deste diretório são
históricas da base 9b8d843; não equivalem a testes da integração atual.

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
