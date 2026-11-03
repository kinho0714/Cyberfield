# Otimização e loading — 03/11/2026

Branch: `codex/otimizacao-loading-2026-11-03`.
Base confirmada: `289a3caaa70864387cd44b1e79947f08edf68ba8`, integração mais recente
no HEAD local ao iniciar. Origin: https://github.com/kinho0714/Cyberfield.git.
A branch original de integração e os commits anteriores foram preservados.
Não houve push, merge compartilhado, reset, checkout forçado ou limpeza.

## Evidência e linha de base

O proprietário aprovou fisicamente, antes desta rodada, inicialização, menus e acesso
à gameplay da integração. Informou quedas de fluidez; não forneceu medição de FPS.
Isso não aprova fisicamente as novas alterações.

Medição desta rodada: Godot oficial 4.7.2 Linux ARM64 **headless**, via PRoot/Termux.
Não é execução gráfica no editor Android nem APK exportado. Cópias congeladas,
XDG/userdata isolados e campanhas descartáveis; nunca os saves do proprietário.
A linha de base foi conferida contra o Git: 179 arquivos runtime iguais a 289a3ca
(`otimizacao_2026-11-03/baseline-proof.json`).

O microbenchmark final usa `main.tscn`, campanha descartável, seed de área 1947 e
três execuções alternadas por versão. As seis execuções produziram a mesma assinatura
procedural, 14 inimigos e o mesmo harness. Depois de gerar a região, congela a cena
para medir trabalho delimitado: sete lotes de 100 amostragens, 100 aplicações de
input LAN, três capturas de snapshot, três salvamentos e 500 chamadas da HUD. Portanto,
esses tempos não representam uma partida ativa nem FPS. `OS.get_static_memory_usage`
mede alocações estáticas da engine, não RSS total nem memória de GPU. Startup e
transição foram cronometrados à parte e variam com escalonamento/cache.

## Gargalos encontrados e mudanças

- WorldTracker.sample validava todo o catálogo e construía/copiava o grafo inteiro
  a cada 250 ms para obter só o ID da sala. Validação agora ocorre por novo objeto
  de mundo; consulta direta ao ID evita copiar módulos/conteúdo. Validação de dados
  carregados e checksums dos saves permanecem completas nas fronteiras.
- Minimap reconstruía o grafo a cada 120 ms mesmo com assinatura invariável. Agora
  observa identidade/assinatura da região e só busca o grafo quando mudam.
- HUD oculto fazia buscas/ordenação/formatação; debug construía texto mesmo desligado.
  Esses caminhos retornam cedo. Loadout solicitava redesenho em dois pontos por frame; agora
  compara os dados visuais e redesenha quando mudam, incluindo recargas/cargas.
- TransitionFx redesenhava sem nada visível. Agora invalida somente na faixa ativa
  ou para limpar o último desenho. Tráfego de menu oculto não atualiza carros.
- LAN offline, amostragem sem campanha e ponte coop sem sessão deixam de receber
  callbacks contínuos. WSS mantém conexões autorizadas/convites/reconexão; no estado
  terminal conclui o handshake de fechamento e libera o socket. Protocolos iguais.
- Mensagem de erro de save deixa de reconstruir o dicionário/texto em todo frame.
- O mapeamento remoto LAN reconfigurava as 14 ações para cada uma das 13 ações
  de cada pacote. Agora inicializa uma vez por perfil/sessão; shutdown invalida o
  cache. Press/release e protocolo permanecem iguais. Há microbenchmark específico.
- Snapshot fazia múltiplas consultas completas de propriedades por nó, incluindo
  até seis para localizar a identidade. Agora reutiliza os metadados dentro da
  captura e conserva prioridade dos IDs, campos e ordem escalar/container → RNG.
  Não há cache global que fique obsoleto entre scripts/saves diferentes.
- CampaignStore serializava/Base64/hash a mesma revisão duas vezes antes da escrita.
  Agora resolve primeiro a revisão disponível e codifica uma vez; checksum, verificação,
  flush, rename atômico, retenção e formato não foram alterados.
- Cenas de regiões deixaram o preload inicial do RoomManager; loading faz IO
  threaded, montagem incremental na thread principal e aplicação protegida do save.
- Geometria, revestimento e decoração cedem frames sem alterar artes, iluminação,
  chuva, partículas ou RNG. Referências e APIs síncronas anteriores foram mantidas.
- Gravador local de desempenho opcional/desativado por padrão, com limite de frames
  e duração. Não coleta identidade, saves, tokens ou dados de rede; não faz upload.

Não foram desligados inimigos distantes nem alterados raycasts/colisões/combate sem
medição que justificasse mudar sua simulação. A IA e os três dashes foram preservados.
Nenhum asset foi removido por suposição; ver auditoria separada.

## Validação e resultados medidos

Com seed, geometria e carga equivalentes, as medianas dos microbenchmarks antes/depois
foram:

| Operação isolada | Antes | Depois | Variação medida |
|---|---:|---:|---:|
| 100 amostragens do WorldTracker | 228.537 µs | 4.809 µs | −97,9% |
| 100 aplicações de input LAN | 65.648 µs | 5.607 µs | −91,5% |
| Captura de snapshot | 314.128 µs | 66.747 µs | −78,8% |
| Transação de save | 764.977 µs | 437.930 µs | −42,8% |
| 500 chamadas da HUD | 36.127 µs | 38.478 µs | +6,5% (piorou) |
| Startup headless | 18,59 ms | 15,75 ms | −15,2%, alta variação entre execuções |
| Transição completa headless | 0,92 s | 1,87 s | +103,1% (mais longa) |
| Memória estática da engine | 269.184.216 B | 268.827.244 B | −0,13%, diferença pequena |
| Recursos contados pela engine | 511 | 505 | −6 |

As quatro primeiras linhas mostram redução de CPU **nessas operações controladas**;
não podem ser convertidas em ganho percentual de FPS. A HUD não ganhou nesse probe e
deve ser perfilada graficamente. A transição demora mais no headless por incluir a
preparação fatiada e yields; a vantagem pretendida é manter a tela responsiva, ainda
pendente de confirmação física. Os dados completos, incluindo as três amostras e a
assinatura, estão em `otimizacao_2026-11-03/benchmark-controlled/results.json`.
Uma comparação preliminar com seeds/geometrias diferentes foi preservada em
`benchmark-seed-confounded/` e não foi usada para calcular ganhos.

Testes de engine: 22/22 da integração, 3/3 de save/sessão/loading após a otimização
do snapshot, e 1/1 de toque no lobby LAN. A verificação estática registrou 43 PASS,
0 FAIL, com Godot runtime e testes físicos Android explicitamente fora desse script.
TLS/relay/social: 14/14 em loopback. Gameplay integrado: três execuções documentadas
com host e convidado Godot reais, incluindo mudança de região, dano, amizade e
reconexão. Quatro assentos: teste aprovado com um host de gameplay Godot e três
clientes Godot de transporte simulados, incluindo snapshot de região/dano e retomada
do mesmo assento. Isso não equivale a quatro cenas de gameplay completas nem a quatro
dispositivos. A tentativa anterior com quatro cenas completas no mesmo PRoot falhou
após muitas pausas/reconexões e timeout de amizade/reconexão; fica registrada como
falha do harness pesado, sem aprovação. Na primeira simulação leve, o harness também
presumiu ordem fixa de assentos; a versão corrigida aceita qualquer assento autorizado
e confirma que a retomada conserva o mesmo ID. Essa simulação passou.

O erro `Cannot call method 'close'` vinha de `client.socket` nulo no teste, após o
transporte já ter liberado o socket terminal. O harness agora valida disponibilidade
e só fecha quando o objeto existe. Os métodos de saída do cliente de produção também
guardam socket nulo. Os novos registros de estado/status não mostraram erro WSS nas
repetições finais; os convidados retomaram `active` e validaram região e estado de
combate. A falha inicial não foi reproduzida, e o primeiro registro não guardou o
código de erro; sua causa exata permanece indeterminada. Por isso, apesar das
repetições aprovadas, a correção da falha inicial ainda requer validação física
Android/WAN antes de homologar o cooperativo.

O código, os testes e os relatórios desta rodada estão preparados para revisão, mas
a missão permanece **sem homologação final** até a causa da primeira falha WSS ser
identificada ou o teste físico controlado confirmar que ela não ocorre no Android.

Logs detalhados e dados brutos ficam em `otimizacao_2026-11-03/`.

Uma rodada preliminar detectou teste antigo dependente de espera fixa de 1,2 s.
O teste agora aguarda prontidão explícita com deadline. O runner passou a salvar
logs durante execução e matar o grupo de processos no timeout, evitando órfãos.
Não se tratou timeout como aprovação e não se apagou requisito funcional.
O teste DEV também passou a aguardar geometria estável do botão antes do toque;
fechamento/F9 continuaram obrigatórios e foram revalidados.
A revisão final de falhas mantém pausa/controles bloqueados até dispensar o erro,
e trata o toque Android pelo roteador existente, sem depender de emulação de mouse.

## Limitações e próximos testes

Não existe ganho de FPS Android/GPU comprovado nesta rodada. Startup e montagem
continuam com etapas indivisíveis, texturas dinâmicas e fallback síncrono; o orçamento
por lote não garante frame de 4 ms. A engine ainda carrega o main antes do loading.
O probe da HUD não demonstrou ganho e o tempo total de transição headless cresceu;
medir no APK antes de homologar. O snapshot otimizado passou nos testes de campanha.

Há avisos ObjectDB/recursos na saída dos processos; baseline também os apresenta.
Algumas execuções dummy exibem aviso de textura/RID. Não equivalem a vazamento
crescente comprovado em uma partida, mas impedem afirmar ausência de vazamentos.
Teste de transições verifica nós retornando ao patamar do hub; medir RAM longa no A14.

No privado, cada cliente valida/aplica seu estado antes de revelar a região. Não foi
implementado ACK global simultâneo de prontidão por região. Quatro APKs físicos/WAN,
recuperação de host morto e narrativa coop completa continuam pendentes. O relay
permanece relay; janela de reconexão de 10 minutos preservada.

Não há validação física nova de sprites, efeitos ou fluidez. Seguir
`CHECKLIST_ANDROID_OTIMIZACAO.md`, comparar editor e APK e só então homologar.
A pasta `/sdcard/Documents/Cyberfield_Marco1_Teste` não foi modificada.

Contratos e falhas: `LOADING_TRANSICOES_2026-11-03.md`.
Assets: `AUDITORIA_ASSETS_2026-11-03.md`.
