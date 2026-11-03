# Loading e transições — 03/11/2026

Branch: `codex/otimizacao-loading-2026-11-03`, derivada de `289a3ca`.

## Arquitetura implementada

`scene/loading_transition.gd` é um CanvasLayer reutilizável, criado pelo RoomManager.
Mostra uma superfície opaca leve, texto contextual, progresso e cancelamento.
Não utiliza shaders, partículas nem assets novos. Refinamento artístico permanece
aberto ao Claude; nenhum menu principal foi reconstruído.

O começo da transação mostra a interface, guarda a pausa anterior e pausa a
simulação local. ResourceLoader.load_threaded_request carrega PackedScene e suas
dependências; o estado é consultado por frame. Somente o IO de recursos usa o
mecanismo de background da engine. Instanciar nós, gerar geometria, decorar,
restaurar snapshots e configurar câmera continuam na thread principal.

O progresso da barra representa **somente** o progresso informado pelo loader de
recursos. Não há porcentagem total inventada: montagem, restauração e sincronização
usam indicador indeterminado. O cache próprio retém no máximo duas PackedScenes.
O fade original permanece; não há espera adicional para simular carregamento.

A geração assíncrona conserva seed, chamadas de RNG, topologia, IDs e conteúdo.
Cede frames entre tentativas, módulos, fases de conteúdo, revestimento e decoração.
Os lotes de módulos/revestimento/decoração cedem quando consomem cerca de 4 ms;
isso não é um limite rígido por frame: uma instanciação, textura dinâmica, relatório,
restauração de entidades, fallback ou etapa indivisível pode ultrapassá-lo.
A primeira carga do próprio main.tscn/importação ainda pertence ao startup da engine.
Não há loading de bootstrap anterior à criação da árvore principal.

## Fluxos

- Menu → partida/Casa; criação e continuação de campanha.
- Continuação/recuperação: mantém o loading da Casa até validar e aplicar o snapshot.
- Casa → Cidade Baixa, Industrial, Laboratório; estágios/rotas e arena existentes.
- Retorno à Casa após morte/abandono e retorno ao menu.
- Mudança de sala pelo RoomManager; transição LAN pelo caminho existente.
- Revisita: `await WorldTracker.revisit_area_async(id)` disponibiliza o mesmo arquivo
  de área persistente com loading. O adaptador síncrono anterior continua disponível.
- Entrada e mudança de região privadas: cliente só revela a região depois de validar
  assinatura e aplicar o snapshot autorizado. Pacotes recebidos durante a montagem
  são coalescidos em um único estado pendente mais recente.
- Desconexão: mantém o bloqueio existente e mostra espera por reconexão. A janela
  de dez minutos do transporte não foi alterada; retomar não cria outra sessão.

Estados/municípios futuros usarão o mesmo contrato quando houver cenas disponíveis;
não foram criadas localidades ou histórias canônicas ausentes.

## Controle, saves e falhas

RoomManager._set_all_player_input recusa habilitar controles durante loading/espera.
Jogadores recém-criados e restaurados também ficam bloqueados. A física fica pausada;
transportes autorizados continuam com PROCESS_ALWAYS. A liberação ocorre após
ready/deferred setup, posicionamento e aplicação de estado, em frame posterior.
A pausa de um chamador externo é preservada ao finalizar.

Campanhas não fazem snapshot durante restauração/transição. Falha/cancelamento de
mudança de região restaura o RunManager e a campanha em memória e conserva a sala
anterior. Continuações inválidas tentam revisões anteriores; se todas falharem,
retornam ao menu sem gravar uma revisão vazia. Revisita tem rollback para o estado
capturado antes da tentativa. A tela de erro não autoriza um novo snapshot. Não se altera o formato/algoritmo atômico dos saves.

Começos duplicados são recusados; a geração identifica a transação para rejeitar
resultado cancelado. Cancelar não interrompe à força o worker da engine: o resultado
é descartado e o fluxo faz rollback. Recursos ausentes/falhos/timeout têm mensagem
compreensível e retorno; nenhuma tentativa concede recompensas novas por loading.
Não há cancelamento de uma restauração síncrona indivisível no meio do mesmo frame.

## Contrato para UI/Claude

- Fluxos normais existentes permanecem awaitable, sem renomear intenções do menu.
- `loading.begin(texto) -> bool`: abre transação se nenhuma estiver ativa.
- `await loading.load_scene(path) -> PackedScene`: null em falha/cancelamento.
- `loading.stage(texto)`: fase indeterminada; `loading.cancel()` invalida resultado.
- `await loading.finish(success)`: restaura pausa, fecha ou apresenta erro. A falha mantém a pausa e o bloqueio de controles até VOLTAR;
`loading.dismiss_error()` restaura o estado anterior. A tela usa o TouchScrollRouter
do projeto, com suporte a toque sem emulação de mouse. Cancelar é desabilitado
na etapa de aplicação de uma cena já preparada.
- `loading.completed(success)`, `last_error`, `last_duration_us`: observação sem saves.
- `await geography.revisit_area_async(id)`: caminho recomendado para novas interfaces.
- `RoomManager.begin_performance_capture(seconds)`: telemetria local opcional.

Não chamar APIs síncronas de DEV/snapshot diretamente a partir de novas telas durante
partidas. O adaptador síncrono existe para compatibilidade, não desenha loading.
Não abrir uma segunda PrivateGameplayBridge pela UI.

## Limites cooperativos e validação

A autoridade continua sendo o host Godot; relay não virou servidor de física.
Não foi adicionado protocolo novo de autenticação nem um ACK global de prontidão
por região. A validação e a barreira visual são **locais a cada participante**;
a homologação de uma barreira simultânea para todos os aparelhos permanece pendente.
Reconstrução de host morto, campanha narrativa coop completa e sincronização de
todos os efeitos/baús continuam limitadas conforme COOP_CONTRATO anterior.

Ver os logs headless em `otimizacao_2026-11-03/`. Testes físicos de renderização,
visual do loading, interrupção do Android, latência WAN e quatro APKs permanecem
pendentes. Aprovação manual anterior de menus/gameplay não aprova estas mudanças.

Na validação automatizada desta branch, `loading_transition_smoke_test.gd` passou
em campanhas novas/continuadas, três biomas, restauração, transição repetida,
cancelamento, erro de recurso, toque, posição e bloqueio de input. O teste de sessão
passou novamente após otimizar a captura do snapshot. WSS/TLS em loopback passou com
dois jogos Godot completos e com um host de gameplay mais três clientes Godot
simulados; a simulação comprovou snapshot de região/dano e reconexão do mesmo assento.
Isso não valida apresentação visual/renderização, WAN, suspensão do Android ou quatro
instâncias físicas. A tentativa de quatro jogos completos em um único PRoot falhou
sob carga e não foi considerada teste aprovado.
