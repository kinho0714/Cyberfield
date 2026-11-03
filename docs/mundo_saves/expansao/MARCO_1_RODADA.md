# Marco 1 — ampliação e testes reais no motor

Base confirmada: `2fafe4716a7899ccf29f23e1c15a64365aeb1d44`.
A autorização de expansão substitui a pausa anterior nos Marcos 2–5. Não implica
homologação dos requisitos ainda pendentes nem autorização para publicar serviços.

Evidência manual adicional recebida nesta missão: recuperação de campanha
interrompida e duas campanhas independentes sem sobreposição observada. Somada ao
ciclo solo anterior, permanece evidência relatada pelo proprietário no Android;
não é execução automatizada nem valida todos os campos.

Implementado: lista de revisões com diagnóstico; fallback também para snapshot
semanticamente incompatível; manutenção do ledger permanente mais novo durante
recuperação; bloqueio de escrita durante reconstrução; limite de tamanho antes da
publicação da revisão; falhas de exclusão reportadas; mensagens legíveis e indicação
em jogo quando a captura está adiada/armazenamento falha; intervalo de autosave
configurável pela API. Nas campanhas novas o ledger de resultados não é truncado
a 80 entradas, evitando reprocessamento antigo; legado mantém o comportamento.

Defeitos corrigidos em testes: `namespace` é palavra reservada no Godot 4.7.2 e
foi renomeada no teste; salas/nós retirados da árvore ainda recebiam callbacks de
state_changed antes de queue_free. A reconstrução agora libera essas instâncias
imediatamente, desconectando seus sinais antes de continuar. JSON inválido é tratado
sem despejar stack traces esperados de corrupção nos logs.

TESTADO AUTOMATICAMENTE no motor **Godot 4.7.2.stable.official.ed1daf0bf** Linux
ARM64 headless executado via PRoot no Termux. ZIP oficial conferido pelo SHA-512
publicado em godotengine/godot-builds (4.7.2-stable/SHA512-SUMS.txt):
`dd59918da086bd49bde2f5450b5e567ff8650cbde9abbd7b8f4ca1197ff8c609baa38834666d032deafb47099078d7822279e2a0e06e5665745468f26533e7e2`.
Motor, libc e PRoot extraídos apenas no temporário. Projeto copiado para teste;
assets binários referenciados em leitura; XDG_DATA_HOME/XDG_CONFIG_HOME separados.
Não foram usados saves reais. Nenhum serviço publicado ou pacote pago instalado.

- `campaign_store_smoke_test.gd`: failures=0. Criação, renomeação, independência,
  roundtrip Variant, conflito, eventos idempotentes, corrupção/incompleto/checksum,
  fallback e preservação dos bytes danificados, `.tmp`, versão futura, exclusão
  confirmada isolada, falha de diretório e migração de perfil legado.
- `campaign_session_smoke_test.gd`: failures=0. Main real/hub e procedural real;
  dois slots; vida/créditos; rollback DEV; seed, dinheiro/sucata, arma/munição e
  inimigo com ID estável restaurados; interrupção sem morte; fallback semântico;
  perfil legado não escrito. Logs em `session.log` e `store.log`.
- `dev_mode_smoke_test.gd`: failures=0; painel real, ferramentas e isolamento;
  evidência em `dev.log`.

Limites: o motor headless não é o APK nem o teste físico do G14. Sem fontconfig,
o sistema informa suporte a fontes do sistema indisponível; fontes do projeto
foram importadas. O teste de sessão ainda informa 9 ObjectDB/4 resources em uso
no encerramento; não há erro de script nas execuções finais. Não declarar motor
inteiramente sem avisos, desempenho medido ou zero vazamentos globais.

Estado do marco: núcleo solo IMPLEMENTADO e TESTADO AUTOMATICAMENTE; cenários
manuais anteriores TESTADOS EM DISPOSITIVO pelo proprietário. Persistem pendências
para homologação completa: cobertura física de baús/transições/loot e equipamentos,
falhas reais de armazenamento/rename, autosave durante suspensão/combate prolongado,
retentiva DEV completa, Windows e medidas de desempenho. Snapshot ainda adia captura
durante corrotinas de combate; não promete recuperar qualquer frame após crash.
Próximo conjunto autorizado: estrutura persistente do mundo, sem reescrever mapas.
