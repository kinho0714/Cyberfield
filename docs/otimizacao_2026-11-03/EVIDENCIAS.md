# Evidências da missão — 03/11/2026

Todas as execuções Godot ocorreram em cópias congeladas sob `/data/data/.../tmp`,
com XDG/user:// separados. Nenhuma execução abriu os saves reais nem a pasta de
teste Android.

- `baseline-proof.json`: 179 arquivos runtime e `project.godot` conferidos contra
  `289a3ca`; nenhuma divergência.
- `static-final.log`: 43 PASS, 0 FAIL; as outras duas entradas são runtime não
  executado por esse verificador e testes físicos Android pendentes.
- `engine-final/engine-results.json`: 22/22 testes headless de integração.
- `affected-final/engine-results.json`: save, sessão e loading depois das correções
  de erro/cancelamento e serialização única.
- `snapshot-final/engine-results.json`: sessão e loading depois da redução de
  consultas de propriedades no snapshot. Ambos os logs indicam `failures=0`.
- `lan-final/engine-results.json`: lobby LAN/toque, 1/1.
- `network-security-final.log`: TLS/WSS, relay, limites, sessão e social em loopback,
  14/14. Não é teste de WAN.
- `network-gameplay-final.log` e `network-gameplay-repeat.log`: três execuções
  documentadas com dois clientes Godot completos; todas validam a região, o dano e a
  reconexão. `network-gameplay-final.log` também contém a rodada de quatro assentos.
- `network-four-seat-final.log`: rodada final de quatro assentos, com um host de
  gameplay e três clientes Godot de transporte simulados; reconexão ao mesmo assento,
  região e dano validados. Não representa quatro jogos completos nem quatro aparelhos.
- `benchmark-controlled/results.json`: três pares com seed/assinatura iguais. Os
  campos de FPS não existem: são tempos de CPU isolados com simulação congelada.
- `benchmark-seed-confounded/`: comparação exploratória anterior, inválida para
  ganhos por geometria procedural diferente; mantida só para rastreabilidade.
- `remaining-exits-preliminary.json`: códigos de um fluxo preliminar encerrado após
  a regressão de teste; não representa a execução final.
- `assets.json`: 533 assets rastreados, 4 grupos de bytes duplicados preservados e
  zero exclusões.

Há avisos ObjectDB/recursos/RID ao encerrar algumas execuções headless. Os testes
passam pelos critérios funcionais, mas esses avisos impedem afirmar que todos os
recursos são liberados ou que a memória de uma sessão longa é estável. A primeira
falha WSS do convidado não guardou o estado do transporte; a causa exata não foi
reproduzida nas rodadas com diagnósticos. Veja as pendências físicas no relatório e
no checklist Android.
