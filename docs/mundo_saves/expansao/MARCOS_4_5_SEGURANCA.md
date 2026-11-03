# Marcos 4–5 — perfis locais e protótipo cooperativo privado

Estado: componentes locais e protocolo IMPLEMENTADOS/TESTADOS AUTOMATICAMENTE.
Amigos online, gameplay cooperativo sincronizado e quatro APKs reais NÃO concluídos.
Nenhum serviço foi publicado, túnel aberto, conta criada ou serviço pago contratado.

## Perfil, privacidade e UI (Marco 4)

`LocalPlayerProfile` cria identidade local persistente somente quando necessária;
solo não exige conta. ID interno de 128 bits e identificador público local distinto;
nome público editável, contatos/solicitações locais, remover, bloquear/desbloquear,
preferência de convites e presença privada. Contatos são marcados `local_unverified`,
solicitações `local_pending_not_sent`. Não representam amizades confirmadas online.
`public_view` exclui ID interno, grafo social, bloqueios e privacidade. A autenticação
online retorna ERR_UNAVAILABLE até existir backend real; IDs declarados não autenticam.

`AtomicDocument` mantém documentos JSON com checksum, temp/flush/rename e três
revisões válidas, preserva corrupção e recusa schema futuro. Perfil com todas as
revisões inválidas não é substituído silenciosamente por identidade nova. Dados
ficam em `user://identity_v1`, separados de campanhas e de caches coop recebidos.
Não há senhas, credenciais ou tokens persistidos no perfil. Em repouso os documentos
não são criptografados: nesta etapa guardam dados locais minimizados, protegidos
pelas permissões do runtime. Distribuição APK/backup Android e necessidade de
Keystore/DPAPI devem ser avaliadas antes de persistir qualquer credencial futura.
Checksum não autentica o conteúdo contra alguém com acesso de escrita ao disco.

UI no menu e hub: mundo/regiões/autosave, perfil/contatos offline e conexão privada.
Reutiliza tema e roteador de toque existentes. Convites online não são apresentados
como enviados por contatos locais. Bloqueios locais ainda NÃO substituem autorização
por identidade autenticada no backend. Testar teclado virtual/toque no APK continua
pendente; teste headless abre/fecha os painéis e verifica restauração da pausa.

## Protocolo privado funcional (Marco 5, parcial)

`tools/private_coop/relay.py` é serviço exclusivo de jogo: WSS obrigatório, certificado
TLS requerido, bind fixo **127.0.0.1**, sem comandos de shell/SSH/admin remoto e sem
TCP público por padrão. `websockets==15.0.1` é dependência open source do host, não
plugin do jogo nem dependência dos convidados. O Moto G14 pode sediar o processo de
testes; suspensão do Android, foreground service/wake lock e disponibilidade real
na rede ainda não foram validados. Os convidados têm cliente nativo no jogo, sem
necessidade prevista de Termux/VPN, mas o fluxo APK + internet depende de endpoint
WSS publicamente alcançável e de implantação autorizada, ainda inexistentes.

A criação exige segredo forte do proprietário carregado por variável de ambiente
`CYBERFIELD_HOST_KEY`, jamais embutido no APK ou no repositório. O servidor gera
três capacidades aleatórias de uso único, expiração de dez minutos e três assentos.
O ID do jogador da sessão é atribuído pelo servidor; nunca pelo cliente. Convites
não são senha de conta nem prova de identidade humana: autorizam quem possui o
segredo. Devem ser entregues privadamente a cada convidado. O backend futuro deverá
vincular contas verificadas, amigos e bloqueios à autorização de cada assento.

O início do protocolo exige EXATAMENTE quatro conexões autorizadas. Apenas o host
(assento 1, G14) publica estado/eventos; inputs dos demais são rotulados pelo relay
com a origem real, sequência crescente e ações permitidas. Revisões rejeitam escrita
obsoleta. Eventos têm IDs persistidos e ACK idempotente; ao atingir 1024 IDs a operação
é recusada em vez de truncar o ledger e permitir duplicação. Não é implementação das
regras de recompensa do gameplay: a autoridade do host ainda precisa da ponte real
para o RunManager, física, inventário, combate e transições.

Snapshots recebidos contêm estado compartilhado, separado de saves individuais.
Relay conserva três cópias íntegras no diretório explicitamente escolhido para
coop. Escreve o primeiro snapshot e limita checkpoints periódicos a dois segundos;
eventos e desconexões forçam checkpoint. Revisões de rede continuam monotônicas.
Arquivos de cache são ordenados por revisão/quantidade de eventos, sem depender do
relógio de parede. `PrivateSessionClient` usa WebSocketPeer com TLS normal, sem
client_unsafe ou desabilitar verificação de certificado. Não expõe tokens na URL.
Ele grava só os snapshots realmente recebidos em `user://coop_received_v1/<session>`,
com identidade de sessão/campanha, revisão e checksum, também com limite de dois
segundos; suspensão/saída tentam flush. Backups não são descartados por falha de rede.

Queda pausa o protocolo e reserva os assentos por dez minutos. Reconexão usa segredo
aleatório separado, mantido somente em memória, validado e rotacionado pelo servidor;
ao retornar todos os quatro, protocolo retoma. Após timeout suspende e conserva o
snapshot. O teste usa relógio controlado para o prazo, não dez minutos transcorridos
fisicamente. Reinício do processo do relay perde autorizações voláteis: snapshots
persistem, mas restauração/autorização após reinício e seleção confirmada de backup
participante continuam pendentes. Não há migração automática de host nem descarte
silencioso das cópias existentes.

## Limites de segurança implementados

- TLS padrão >=1.2 no servidor; CA/hostname validados no cliente. Certificado de
  teste autoassinado é confiado explicitamente somente no fixture loopback.
- Handshake com prazo de 8 s; 12 conexões simultâneas máximas; 8 salas máximas;
  mensagens de texto até 96 KiB, snapshot até 64 KiB, filas limitadas e sem compressão.
  Limite de 40 mensagens/s com burst de 60 por conexão autorizada. Origens de browser
  são recusadas na configuração do serviço; cliente nativo não precisa de Origin.
- JSON, tipo/tamanho/ações/seq/revisão/papel validados no servidor; NaN/Infinity,
  binário, operações desconhecidas e reivindicação de autoridade recusados. Campos
  de snapshot aceitos são explicitamente limitados; gameplay host permanece confiável.
- Segredos aleatórios usam `secrets`/Crypto, hash SHA-256 e comparação constante de
  capacidades. Sem criptografia própria, senha em texto puro ou confiança em public_id.
- Sem log de payload, token, nome, chat ou grafo social. Testes usam credenciais e
  certificados descartáveis em temporário com permissões restritas; nada é versionado.
- Chat está DESABILITADO (operação não suportada). TLS é criptografia em trânsito,
  NÃO E2EE: relay e host têm acesso aos dados. Chat futuro exige autorização por sala,
  limites próprios, bloqueio autenticado, moderação/denúncia e retenção explícita;
  E2EE só poderá ser anunciada com implementação verificável de protocolo estabelecido.

Retenção: três revisões válidas por perfil/cache; corrupção fica preservada para
recuperação. Campanhas excluídas do seletor continuam arquivadas por soft delete,
conforme M1; não prometer apagamento físico. Credenciais de entrada/reconexão não
são gravadas; convite expira/é consumido, salas suspensas ficam limitadas em memória
até reinício. Os snapshots coop do host persistem até remoção explícita pelo dono;
exclusão definitiva e política temporal de retenção ainda precisam de fluxo revisável.
Nenhuma limpeza automática de saves reais foi introduzida.

## Conectividade investigada e decisão de protótipo

A API nativa [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html)
permite WSS e polling sem SDK adicional; foi escolhida para o protótipo de quatro
assentos. WSS usa TCP e pode sofrer bloqueio de fila sob perda; latência/jitter e
consumo no G14 precisam ser medidos antes de escolher o transporte definitivo.

[Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
estabelece conexão de saída e evita depender de uma porta de entrada atravessando
CGNAT; isso permite encaminhar somente o serviço de jogo e não Termux/SSH. A
[documentação de WebSockets](https://developers.cloudflare.com/network/websockets/)
confirma suporte, mas avisa que conexões podem cair em manutenção e a inspeção WAF
não cobre frames após upgrade. Nosso protocolo precisa manter autenticação, limites
e reconexão. Inferência: um túnel nomeado para o serviço loopback é candidato ao G14;
requer conta, endpoint/domínio e configuração de TLS/CA/host. Não foi configurado,
nem se pressupõem credenciais, domínio gratuito ou SLA. Não usar túnel para exportar
shell, SSH, painel administrativo ou diretório de arquivos.

Alternativa futura: [Nakama Godot](https://heroiclabs.com/docs/nakama/client-libraries/godot/)
para autenticação real, amigos e persistência; requer infraestrutura/DB e integração.
O modo [relayed padrão](https://heroiclabs.com/docs/nakama/concepts/multiplayer/relayed/)
não restringe entrada por convite nem número de membros por si só, portanto não
satisfaz a privacidade pedida sem lógica adicional. O modo
[authoritative](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/)
permite regras de admissão e partida, mas exige código de servidor. Nenhum serviço
pago/gerenciado foi contratado. ENet direto depende de conectividade UDP de entrada;
WebRTC requer ICE e eventualmente TURN/relay. CGNAT e endereço público do aparelho
não foram medidos; não declarar conexão direta operacional.

## Evidência e pendências essenciais

- `local_profile_smoke_test.gd`: criação/ID/nome/contatos/bloqueio, filtro público,
  indisponibilidade explícita de auth online, reabertura/backup e identidade corrompida.
- `private_relay_test.py`: seis testes reais de sockets TLS locais, com convites,
  quatro conexões, inputs, autoridade, snapshots, eventos idempotentes, replay,
  reconexão, timeout controlado, payload inválido e rate limit. Inclui um cliente
  **Godot real** como host e três clientes Python de protocolo, verificando input e
  backup recebido no cliente Godot. Isso NÃO são quatro jogadores/APKs nem gameplay.
- A integração completa de gameplay WSS não existe: LAN atual permanece separada.
  Menu anuncia protótipo de conexão e o botão de início apenas valida quatro assentos.
- Pendentes: backend de identidade/amigos, vinculação de convites a contas,
  implantação privada autorizada, transporte/ponte do gameplay, restauração completa
  após crash do G14/relay, quatro APKs em redes reais, queda/retorno e desempenho.
  Marcos 4/5 completos NÃO homologados.
