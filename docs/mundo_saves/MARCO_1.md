# Marco 1 — persistência solo (checkpoint de implementação)

Data: 03/11/2026. Base de auditoria: `803fa10`.
Branch: `codex/mundo-saves-marcos-0-1-2026-11-03`.

**Estado: IMPLEMENTADO PARCIALMENTE; ciclo básico solo TESTADO EM DISPOSITIVO
E APROVADO PELO PROPRIETÁRIO. Marco completo ainda não homologado nem concluído.**
O proprietário confirmou no Godot Android 4.7.2: criar/carregar uma campanha,
movimentar o personagem, encerrar completamente a execução, reabrir o jogo e usar
CONTINUAR restaurou corretamente o progresso e a posição. Evidência manual relatada
pelo proprietário; não é resultado de execução dos smoke tests automatizados.
Não existe executável Godot disponível neste Termux. Permanecem os critérios
específicos discriminados abaixo. Não avançar ao Marco 2 por instrução do proprietário.

## Arquivos e arquitetura

- `scene/persistence/campaign_store.gd`: IDs aleatórios de 128 bits; metadados de
  campanha; envelope v1; SHA-256; Variant binário sem objetos, codificado em Base64;
  gravação temporária, flush, releitura, rename no mesmo diretório; três revisões
  válidas (atual + dois backups). Revisões danificadas ficam preservadas.
  Recuperação escolhe a maior revisão íntegra, sem usar relógio local. Versão futura
  bloqueia carga e escrita. Conflitos de revisão são recusados. Exclusão exige o
  ID confirmado e move somente o diretório do slot para uma pasta `deleted_*`.
  Eventos narrativos têm IDs idempotentes e dados separados da run.
- `scene/persistence/session_snapshot.gd`: adaptador do estado real dos scripts,
  mapas BiomeMapState, RNGs, jogadores/gadgets, vida, armas, munição, atributos,
  cooldowns, posições, inimigos, loot e objetos com scripts da sala. Regera o cenário
  com a seed existente, compara a assinatura e reaplica o manifesto de objetos por
  IDs estáveis/caminhos. Recusa estruturas incompatíveis; não decodifica objetos.
  Objetos ausentes são recriados de cenas/scripts do próprio projeto; objetos já
  removidos na captura são removidos da reconstrução. Colisões de passagens são
  reaplicadas. Referências Node/Resource, sinais e callables ficam fora dos dados.
- `scene/persistence/campaign_controller.gd`: serviço filho do RoomManager, sem
  autoload ou dependência de rede. Controle solo, autosave de 30 s configurável em
  código (mínimo 5 s), eventos com intervalo mínimo de 2 s, suspensão e menu.
  Alterações permanentes podem ser gravadas mantendo o último snapshot consistente
  quando a sessão está em transição/combate. A restauração usa os dados permanentes
  mais recentes. Falha ao reconstruir não gera um snapshot substituto.
- `scene/persistence/campaign_panel.gd`: botão CAMPANHAS SOLO no menu real; criação,
  continuar, renomear, exclusão em dois passos e cópia explícita do perfil legado.
  Roteador de toque existente reutilizado. Teclado virtual solicitado no campo de
  nome. Sem conta obrigatória ou indicação de serviço online.
- `scene/room_manager.gd`: instancia o serviço e solicita salvar antes de sair.
- `scene/meta_progression.gd`: direciona gravação ao slot ativo; legado continua
  pelo fluxo anterior. Importação copia os dados v1–v4 por `_apply_save`, produzindo
  meta v4 em campanha nova; rejeita versões futuras. Não modifica o arquivo fonte.
- `scene/dev/dev_mode.gd`: captura antes da primeira ferramenta e restaura a sessão
  legítima ao desligar, inclusive vida, dinheiro, armas e mundo. Sem captura segura,
  a ferramenta é recusada. Falha na restauração mantém a run marcada DEV e bloqueia
  autosave real. Perfil DEV é marcado `dev_sandbox=true` e separado por campanha.
  O store aceita slots `mode=dev`, mas ainda não há fluxo de campanhas DEV completas
  na UI (o painel DEV existente continua usando seu perfil sandbox).

## Preservação

Todos os arquivos novos usam `res://` e `user://` no código Godot. As campanhas são
criadas em `user://campaigns_v1`; o perfil legado não é convertido automaticamente.
O botão de jogar original continua usando o fluxo legado, cuja persistência direta
não foi substituída. Saves existentes não foram abertos pelo motor nem escritos
nesta execução. Nenhum comando de reset, limpeza ou checkout forçado foi usado.
Os seis assets privados continuam não rastreados e seus SHA-256 coincidem com a
entrada. Não foram alterados combate, gerador, lore, assets, cenas congeladas,
configuração de exportação ou protocolo LAN.

## Testes e evidências

`validation.json` registra os resultados efetivamente executados:

- TESTADO AUTOMATICAMENTE: parser de gramática gdtoolkit 4.5 em nove scripts;
  `mega_pass_priority1_static_test.py`; três testes de
  `pass6_hotfix2_static_test.py`; `menu_pass6_static_test.py`; diff sem erro de
  whitespace; hashes e ausência de rastreamento dos seis arquivos privados.
- A tentativa inicial do teste do menu encontrou `PIL` ausente. Pillow foi instalado
  somente no temporário do Termux e o teste foi reexecutado com sucesso.
- O parser e as dependências de teste foram instalados fora do repositório. Caches
  criados pela primeira execução foram movidos para o temporário; o validador passa
  a usar cache temporário e desliga geração de bytecode nos testes Python.
- **TESTADO EM DISPOSITIVO E APROVADO PELO PROPRIETÁRIO:** ciclo básico solo no
  Godot Android 4.7.2, conforme relato registrado nesta revisão: criar/carregar,
  movimentar, encerrar completamente a execução, reabrir e CONTINUAR com progresso
  e posição restaurados. Isso comprova execução da cena e persistência entre
  execuções nesse cenário; não equivale a auditoria de todos os scripts/autoloads.
- **PENDENTE:** execução dos smoke tests funcionais novos, testes de falha e demais
  cenários abaixo. O parser de gramática não valida tipos ou funcionamento; a
  evidência Android vem do relato do proprietário, separada dos testes locais.

Testes funcionais escritos, ainda não executados:

1. `tests/campaign_store_smoke_test.gd`: slots independentes, reabertura, tipos
   Vector2/StringName, conflito de revisão, evento idempotente, arquivo incompleto,
   checksum alterado, fallback, preservação de corrupção, `.tmp` interrompido,
   versão futura, exclusão isolada confirmada e migração do perfil legado.
2. `tests/campaign_session_smoke_test.gd`: instancia `main.tscn` real, cria duas
   campanhas, recupera vida/créditos, liga/desliga DEV e verifica rollback,
   inicia bioma procedural real com seed conhecida, salva/reabre e compara vida,
   localização e recursos. Usa namespaces `user://test_*` exclusivos; não remove
   nem acessa campanhas reais. Também verificar o smoke test DEV já existente.

Com Godot disponível, na raiz:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/campaign_store_smoke_test.gd
godot --headless --path . --script res://tests/campaign_session_smoke_test.gd
godot --headless --path . --script res://tests/dev_mode_smoke_test.gd
```

Para repetir verificações locais: executar `python -B
 tools/validate_campaign_milestone.py` com gdtoolkit/Pillow disponíveis no PYTHONPATH.
O script só informa runtime pendente; nunca transforma ausência do motor em teste
funcional aprovado. Suas saídas são JSON; nenhum executável/dependência é versionado.

## Limites técnicos e próximos passos obrigatórios

1. Snapshot de corrotinas arbitrárias não é suportado. Capturas são adiadas durante
   ataque, hurt, dash, morte animada ou gadgets ativos; mantém-se a revisão segura
   anterior. Combate prolongado pode atrasar a captura completa. Progresso permanente
   usa transação separada, mas captura de combate a qualquer instante ainda exige
   adaptadores explícitos para estados assíncronos. Não declarar recuperação completa
   de todos os instantes/sistemas com esta implementação genérica.
2. Reabertura após encerramento completo da execução e restauração de progresso/
   posição foram confirmadas pelo proprietário. O método de encerramento não foi
   detalhado: não estender a evidência a force-stop nas configurações Android,
   crash, perda de energia ou encerramento pelo sistema por falta de memória.
   Pausa/troca de apps, falta de espaço, falha de rename, performance/latência e
   consumo de memória continuam pendentes. Arrays/objetos não serializáveis são
   omitidos; auditar projéteis, efeitos, colisões e estados de interação em runtime.
3. Snapshot depende da geração instalada. Se o gerador mudar e a assinatura divergir,
   a carga é recusada e as revisões permanecem intactas. Migrações de geometria ou
   schemas futuros precisam de implementação explícita; não são simuladas.
4. Flush + rename não garantem durabilidade absoluta após perda de energia. Não há
   fsync de diretório pela API usada. SHA-256 detecta dano, não autentica o arquivo.
   Tamanho máximo de envelope aceito: 32 MiB; medir payload real em celulares.
5. Ajuste de intervalo por UI, painel de diagnóstico de recuperação, escolha manual
   de revisão e migração de schemas futuros ficam pendentes. Fallback de corrupção
   existe no store; incompatibilidade semântica de sessão ainda não tenta reconstruir
   automaticamente cada backup anterior.
6. Política de loot/morte segue o legado. O limite existente de 80 IDs de resultados
   processados não foi reescrito; eventos novos do store mantêm IDs persistentes.
   Não introduzir preços, percentuais, membros ou acontecimentos narrativos.
7. DEV precisa de teste físico em hub, run e coop local. Slots completos DEV,
   recuperação de falha de restauração e indicação visual mais detalhada são parciais.
8. Amigos, mundo/Pavilhão 9, coop compartilhado e reconexão pertencem aos próximos
   marcos; não foram declarados funcionais nem alteraram a LAN existente.

Teste Android: criar A; mudar vida/munição/loot; salvar; trocar app; forçar encerramento;
reabrir e CONTINUAR; criar B e alternar; corromper SOMENTE namespace de teste;
verificar fallback; testar DEV ligado/desligado e exclusão confirmada de slot de teste.
Repetir em Windows, incluindo reconciliação de assinatura e roundtrip de tipos.
A evidência de sessão real salva/restaurada no ciclo básico foi recebida.
Antes de considerar Marco 1 concluído: executar os demais testes no motor, corrigir
falhas e validar a cobertura dos snapshots e a recuperação em condições de falha.

Referência da API binária consultada: documentação oficial
https://docs.godotengine.org/en/4.4/tutorials/io/binary_serialization_api.html
(`bytes_to_var`/`var_to_bytes`, sem habilitar objetos).

## Hotfix de inferência — validação Android iniciada pelo proprietário

O proprietário relatou erro de compilação no Godot Android 4.7.2 em
`campaign_controller.gd:118`. A declaração anterior usava
`var restored := game.mode_selected and SNAPSHOT.restore(game, candidate.session)`.
`game` tem tipo estático Node e `mode_selected` é propriedade do script concreto,
logo o operando esquerdo é dinâmico. O analisador não consegue estabelecer um tipo
para a expressão completa com `:=`, embora `restore` declare retorno bool.

Correção: `var restored: bool = bool(game.mode_selected) and
SNAPSHOT.restore(game, candidate.session)`. Preserva o curto-circuito: a restauração
só é chamada quando o modo foi selecionado. Os dicionários de snapshot/campanha no
controlador e o resultado de restauração no DEV também receberam tipos explícitos.
Nenhuma mudança no formato ou no conteúdo dos saves, nas transições ou no schema.

Revisados todos os `:=` nos quatro scripts novos de persistência e nos dois smoke
tests do Marco 1, além do ponto de integração DEV. Não foi identificada outra
expressão equivalente de inferência sobre propriedade dinâmica; os demais casos
usam literais, construtores, casts ou funções com retorno declarado. Esta revisão
não substitui a análise semântica do motor.

Verificações disponíveis: nove scripts passaram na gramática; verificações
estáticas de prioridade 1, rolagem e menu passaram; seis hashes privados conferidos;
`git diff --check` sem erros. Evidência: `validation_inference_hotfix.json`.
A validação sintática anterior não detectava o erro de inferência agora reportado.
Na entrega do hotfix, não havia executável Godot local e a nova validação Android
estava pendente. O relato posterior abaixo confirma o ciclo básico funcionando;
os demais critérios permanecem pendentes. Sem avanço ao Marco 2.


## Evidência funcional Android recebida — ciclo básico aprovado

Fonte: relato direto do proprietário nesta conversa, após o hotfix de inferência.
Ambiente informado: Godot Android 4.7.2. Não foram fornecidos logs, captura ou hash
da build executada; não foi realizado teste adicional pelo agente nesta revisão.

Sequência confirmada: criou e carregou uma campanha; movimentou o personagem;
fechou completamente a execução; reabriu o jogo; acionou CONTINUAR. Resultado
informado: campanha restaurou corretamente progresso e posição do personagem.
O proprietário aprovou este teste funcional. Não foi especificado se ocorreu no
hub ou em bioma, nem quais itens/atributos compunham o progresso observado.

| Critério | Estado e alcance da evidência |
| --- | --- |
| Criar/carregar uma campanha solo | TESTADO EM DISPOSITIVO; APROVADO PELO PROPRIETÁRIO, no ciclo relatado |
| Reabrir execução e CONTINUAR | TESTADO EM DISPOSITIVO; APROVADO PELO PROPRIETÁRIO |
| Restaurar posição e progresso observado | TESTADO EM DISPOSITIVO; APROVADO PELO PROPRIETÁRIO; campos não discriminados |
| Verificações estáticas locais anteriores | TESTADO AUTOMATICAMENTE, conforme JSONs históricos; não reclassificados como testes funcionais |
| Smoke tests store/session/DEV | ESCRITOS; execução no motor ainda não confirmada |
| Dois slots, renomeação, exclusão confirmada e importação legada | PENDENTES de validação funcional |
| Integridade, recuperação por backup, escrita interrompida, versões e conflitos | PENDENTES de validação funcional |
| Isolamento DEV, morte e progresso permanente sem duplicação | PENDENTES de validação funcional |
| Campos detalhados da run, objetos e transições procedurais | PENDENTES de validação funcional |
| Autosave periódico/eventos/suspensão, separadamente | PENDENTES; o ciclo aprovado não identifica qual gatilho gravou o snapshot |
| Windows, falhas de armazenamento e desempenho mobile | PENDENTES |

Próximos testes, por prioridade, usando campanhas/arquivos descartáveis separados
das campanhas reais e sem alterar os saves existentes:

1. **Isolamento DEV:** no hub e na run de teste, anotar vida, créditos, dinheiro e
   equipamentos; usar ferramentas DEV; desativar; verificar retorno aos valores
   legítimos; encerrar/reabrir e conferir ausência de ganhos artificiais no slot real.
2. **Integridade e recuperação:** executar `campaign_store_smoke_test.gd` em seu
   namespace exclusivo; validar arquivo incompleto, checksum alterado, `.tmp`, backup
   anterior íntegro, preservação dos dados danificados, versão futura e conflito de
   revisão. Nunca provocar corrupção em saves reais. Incluir falhas de escrita/
   armazenamento, ainda não cobertas integralmente pelo smoke test atual.
3. **Independência dos slots e legado:** criar A/B com estados distintos; alternar e
   reabrir; renomear; cancelar exclusão e confirmar somente a de um slot descartável;
   conferir o outro intacto. Copiar perfil legado para campanha nova e verificar
   migração/compatibilidade e que o arquivo de origem permanece idêntico.
4. **Cobertura de estado e morte:** registrar valores de vida, munição, armas,
   cyberwares/acessórios, recursos, blueprints e descobertas; coletar loot/abrir baús,
   derrotar inimigos e abrir passagens; atravessar estágios; reabrir e comparar.
   Testar derrota versus interrupção, permanentes preservados e ausência de loot/
   recompensas duplicadas. Executar os smoke tests session e DEV existentes.
5. **Gatilhos e plataformas:** distinguir autosave periódico de eventos, menu e
   suspensão; trocar de app e voltar; testar encerramento forçado/crash em campanha
   descartável; repetir o ciclo no Windows. Medir latência/tamanho/frequência de
   gravação e verificar UI touch/teclado além dos controles já usados no relato.

Marco 1 permanece em validação parcial. Nenhum código, save, asset ou sistema foi
alterado para registrar esta evidência. Marco 2 continua não autorizado nesta etapa.

## Rodada de expansão autorizada

A nova missão autoriza avançar nas partes independentes dos Marcos 2–5, preservando
as pendências. O proprietário também confirmou recuperação de campanha interrompida
e dois slots sem sobreposição observada. Agora há testes automatizados executados
no Godot oficial 4.7.2 headless em ambiente temporário isolado: store, sessão real e
DEV passaram. Detalhes, correções e limites em `expansao/MARCO_1_RODADA.md`.
Esta evidência atualiza a indisponibilidade histórica do motor; não equivale a
Windows ou à execução do APK Android. Marco completo continua com pendências.
