# Marcos 2–3 — mundo persistente e rotas incrementais

IMPLEMENTADO e TESTADO AUTOMATICAMENTE no Godot 4.7.2 headless (ambiente isolado
descrito no relatório M1). Ainda não testado fisicamente pelo proprietário nesta
rodada; não homologar exploração completa, todos os requisitos físicos ou Windows.

`content/world/catalog_v1.json`: catálogo versionado de dez estados state_001–010,
cidades com IDs reservados, dez templates de municípios e três bairros por template.
Cada localização possui ID composto estável, pai, tipo, nome público editável,
status narrativo e implementação. Nomes de bairros são proposed. Estados/cidades
não são nomes canônicos. Conteúdo artístico é reutilizado apenas dos três biomas
existentes; sete outros municípios não ganham mapas/arte inventados.

`WorldCatalog` valida os dados e mapeia cidade_baixa/laboratorio para os IDs de bioma
já existentes lower_city/lab sem renomeá-los. `CampaignWorld` cria o resultado
explícito uma vez por campanha; não regenera mundos/distribuições existentes.
Há sete slots reservados sem atribuir identidades pendentes; distribuição em sete
estados elegíveis distintos, excluindo os três investigativos. Guard distribution
e elegibilidade não aparecem no public_view; somente descobertas/pistas conhecidas
são exibidas. IDs de campanha são separados da seed, e o domínio da seed distingue
mundo, run e área. Eventos/pistas têm registro idempotente sem criar acontecimentos.

`WorldTracker` observa o jogo real e registra hierarquia, salas visitadas, contexto
hub e posição na campanha ativa, sem capturar DEV/LAN/legado como campanha real.
A exploração é permanente por campanha; o snapshot conserva a referência geográfica
para recuperação de revisão anterior. Mundos de campanhas antigas são adicionados
somente em memória ao continuar e publicados junto de uma revisão válida; os arquivos
anteriores não são reescritos.

`RegionRoutes` mantém grafo explícito por bairros: saída principal, alternativa,
ramo opcional com dash e convergência. A sequência dos três biomas existentes é
reutilizada; não é necessário visitar todos os municípios/bairros. A run atual
mantém o limite/arena final existentes, sem criar final narrativo. O grafo de regiões
não substitui a validação de plataformas do BiomeGenerator. Seeds de área e assinatura/
grafo reais são registrados; restauração usa a seed de área salva, evitando derivá-la
duas vezes. Sessões anteriores sem essa chave usam a seed original como fallback.
Contador de runs é persistido antes de iniciar uma run para manter a sequência.

UI: MUNDO CONHECIDO por campanha no menu; MUNDO/SESSÃO no hub com regiões descobertas
selecionáveis para a próxima run e intervalos de autosave. Usa roteador de toque e
estilo existentes. Não mostra localização de Guardas nem estados não descobertos.

Testes executados:
- world_persistence_smoke_test.gd: failures=0; hierarquia/pais, persistência,
  distribuição fixa, par conhecido de seeds, sete estados distintos e filtragem
  pública, idempotência de descobertas/pistas de fixture e isolamento entre mundos.
- region_routes_smoke_test.gd: failures=0; conectividade com habilidades básicas,
  gate de dash, seeds estáveis entre IDs de campanha independentes, variação por
  run e seed conhecida, grafo explícito preservado.
- campaign_session_smoke_test.gd após integração: failures=0; bioma real salva e
  reconstrói com assinatura validada. `session-world.log` conserva os avisos de
  recursos em uso na saída, sem erros de script.

Pendentes: teste Android da seleção/regiões/saídas e de troca de bioma, cobertura de
plataformas com habilidades reais em todos os destinos; mapa visual geográfico
mais completo, progressão entre estados/cidades futuros, migração de catálogos
incompatíveis e geometria de versões futuras. Bairros ainda reutilizam pools dos
biomas; não há trinta cenários artísticos. Os slots de Guardas são reservados;
restrições narrativas adicionais exigem dados oficiais, não personagens inventados.


A regressão ampliada também passou pelo teste físico automatizado já existente de
exploração: 30 gerações nos três biomas, escadas críticas e passagem de dash, sem
substituir o gerador. Os avisos de recursos/RIDs na saída desse teste são preservados.
Novos guards impedem que uma run iniciada no hub DEV consuma seed/contador, publique
áreas ou selecione regiões reais. A prévia das saídas consulta o grafo de campanha,
para o rótulo do destino concordar com a transição. Verificar os logs finais para
resultados da integração ampliada e manter Android/Windows como pendência separada.
