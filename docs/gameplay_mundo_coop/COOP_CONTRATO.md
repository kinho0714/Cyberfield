# Coop privado — ponte de gameplay para o Claude

## Composição atual após integração com o Claude

CampaignController agora possui private_gameplay e inicia a ponte ao receber active.
Não criar uma segunda ponte na UI: usar begin_private_gameplay()/end_private_gameplay().
O painel do Claude inicia/encerra o fluxo; solo, DEV e réplicas locais são protegidos.
O contrato manual abaixo continua válido para harnesses/componentes independentes.
Ver ../integracao_2026-11-03/RELATORIO.md para evidências e limites atuais.

## Integração explícita, sem UI paralela

PrivateSessionClient continua compatível com chamadas existentes. connect_session
aceita argumento final opcional required_players=4; criar fixa o número de assentos
(2–4) no servidor. Convites, perfil e lobby permanecem responsabilidade do Claude.
Não remover as marcações de protótipo nos menus até validação física e pendências.

Após PrivateSessionClient.status == active e antes de entrar em campanha solo:
1. Instanciar preload("res://scene/network/private_gameplay_bridge.gd").new().
2. Adicionar o nó à árvore; bind_gameplay(room_manager, private_client) retorna Error.
3. await bridge.begin() retorna Error; gameplay_ready informa prontidão.
4. await bridge.stop() antes de encerrar a sessão; depois client.leave().

bind recusa campanha solo ativa, partida já aberta ou LAN. Não há merge de saves.
A ponte não é iniciada por menu automaticamente; o Claude deve conectar o fluxo
existente à API acima, evitando iniciar uma campanha solo ao mesmo tempo.

O estado original de MetaProgression é preservado em memória e restaurado no stop;
durante coop seu save_path aponta exclusivamente para user://coop_authority_v1/<sala>.
Snapshots recebidos ficam em coop_received_v1, separados das campanhas. Não importar
progresso de convidados, tokens, perfil/amigos nem dados pessoais no estado enviado.

## O que a ponte faz

Host Godot usa os personagens, física, colisões, armas e IA existentes. Convidados
mandam ações booleanas; o relay atribui o assento e valida sequência/tamanho/frequência.
A ponte também rejeita replays e chaves fora da allowlist; não recebe coordenadas,
dano ou recompensas dos convidados. Inputs sem keepalive por 250 ms são liberados.
Dash passa pelo mesmo limite de três usos no personagem do host.

Snapshots até 20 Hz, com ack antes do próximo envio: posição/velocidade, animação,
vida, estados de combate/equipamento dos personagens; estados de inimigos e sua
mira; seed/estágio/bioma e economia temporária. GameplayWire converte somente
primitivos, Vector2 e PackedVector2Array para JSON, sem desserializar objetos.
Convidado gera o mesmo bioma por seed e aplica apresentações/interpolação sem IA,
colisões simuladas ou detectores interativos locais. O host decide mortes/recompensas.
Mudança de região é derivada do estado autorizado, não de comando de geração do
convidado. Nenhuma API de menu/HUD foi renomeada.

Se qualquer assento cair, o relay pausa. A ponte libera inputs e suspende o subtree
de jogo; cancela ataques pendentes e retoma quando os assentos voltam. O cliente
valida TLS e retoma sua capacidade rotacionada, recebendo o snapshot do welcome.
Não confundir identidade de assento por capacidade com identidade de conta verificada.

## Limites que impedem declarar coop completo

- Ainda faltam projéteis/efeitos dinâmicos completos nos clientes, baús/drop spawning
  e mapa compartilhado integral, escolhas remotas de atributos, votação/fast travel,
  missões cooperativas e aplicação transacional de recompensas individuais.
- story_state e inventory_state do envelope estão reservados; inventário de combate
  vem com o estado de cada jogador. Não existe campanha narrativa cooperativa completa.
- Não há armazenamento seguro das capacidades no cliente nem reconstrução de host
  morto. Checkpoint/retomada do relay não substitui persistência completa da simulação.
- Host Godot é confiável; proprietário malicioso pode manipular o jogo. O relay não
  é um servidor dedicado de física. Backend de contas e vínculos de amigos pendentes.
- Interpolação usa WSS/TCP, sem previsão de inputs do convidado. Latência de internet
  pode prejudicar jogabilidade. Não anunciar desempenho Android/4 APKs físicos.
- Ainda há avisos de ObjectDB/recursos na saída dos testes, herdados da integração.

## Áreas compartilhadas alteradas

Player: limite de dash e campos escalares de orçamento para snapshot/rede; a
animação oficial não mudou. RunManager: sinal gameplay_event e deduplicação de morte.
RoomManager: captura da área antes da transição. WorldTracker: APIs de missões e
revisita. PrivateSessionClient: tamanho opcional de sala e estado no welcome de
retomada. Demais alterações são módulos novos/IA/backend/testes. Nenhum menu,
HUD, cena de UI, perfil social, convite visual ou asset foi editado.
