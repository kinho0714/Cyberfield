# Validação Android — otimização/loading

Dispositivo alvo: Samsung A14. Godot 4.7.2. Esta lista não está marcada como
executada: testes headless Linux/PRoot não aprovam renderização, toque ou APK.
A evidência informada pelo proprietário antes desta rodada foi: jogo integrado
inicia, menus funcionam e gameplay é acessível, com quedas de fluidez percebidas.

## Atualização segura

1. Fechar a execução e o editor. Fazer backup integral da pasta de teste conhecida
   `/sdcard/Documents/Cyberfield_Marco1_Teste` antes de substituir qualquer arquivo.
2. Preservar também os dados user:// de campanhas/perfil do ambiente atual. O backup
   da pasta do projeto pode não incluir o armazenamento privado do editor/APK.
   Verificar o caminho real no debugger com OS.get_user_data_dir(); não apagar dados
   do aplicativo, não desinstalar e não alterar a identidade do projeto/APK.
3. Preferir uma pasta de projeto separada para homologação. Conferir a localização
   de user:// antes de abrir campanhas: uma pasta nova não garante isolamento de saves.
   Usar campanhas descartáveis ou cópia recuperável dos dados para esta rodada.
4. Copiar somente o conteúdo rastreado da branch de otimização identificada no
   relatório, incluindo scripts novos. Preservar os seis assets privados já presentes.
   Não espelhar diretórios com opções de exclusão, não limpar .godot nem user://.
5. Importar no Godot Android 4.7.2, aguardar a importação terminar e verificar erros.
   Esta missão não copiou nem editou a pasta de teste Android.
6. Somente após aprovação, aplicar os arquivos rastreados na cópia habitual, mantendo
   backup até confirmar criação/continuação e progresso. Reverter código pelo backup
   se necessário, conservando os saves e seus backups; não reverter dados às cegas.

## Comparação reproduzível

- Usar como antes o código 289a3ca e como depois o commit de código do relatório,
  com os mesmos assets privados, campanha descartável/seed, qualidade, resolução,
  limite de FPS e configuração. Manter cópias dos dados para repetir sem interferência.
- Repetir três vezes em cada condição: editor e APK exportado. Registrar aparelho,
  build, duração, bateria/temperatura e configurações. Dar tempo para resfriar entre
  rodadas; evitar gravação de tela/overlay ou registrar sua presença nas duas versões.
- Não incluir a importação inicial na medição normal de startup. Medir primeira
  abertura e abertura com recursos já importados separadamente.
- Roteiro de 60 s: Casa parada, deslocamento/pulo, Cidade Baixa com combate e
  minimapa, transição, retorno. Repetir o mesmo trajeto e número de inimigos.
- O gravador local opcional da versão nova é ativado pela propriedade exportada
  `performance_capture_enabled` do Main ou `--cyberfield-profile` no desktop.
  Também: `begin_performance_capture(60.0)` no debugger. Desativado por padrão.
- Capturas locais em user://performance, sem IDs/dados de jogadores, sem upload.
  Console imprime CYBERFIELD_PERFORMANCE com p50/p95/p99 de delta e arquivo local.
  Guardar os JSONs e remover manualmente quando não forem mais necessários.
- Para instrumentar a versão antiga, usar o mesmo `performance_capture.gd` apenas
  na cópia de benchmark, adicionado como filho do Main; registrar essa diferença.
  Esse script não altera balanceamento, saves nem redes.
- Registrar FPS/tempo de frame do profiler **gráfico**, CPU/process/physics, scripts
  no profiler, render/draw calls/GPU quando suportado, RAM, nós/recursos e tempo de
  loading (`LoadingTransition.last_duration_us`). Monitor TIME_PROCESS não é uma
  decomposição por script. Delta inclui limite de FPS/esperas; headless não é FPS real.
- Comparar medianas e p95/p99; não extrapolar editor → APK nem atribuir a redução
  de uma microfunção a um ganho percentual de FPS do jogo inteiro.

## Regressão funcional

- [ ] Menu inicial, idiomas, opções, campanhas, perfis/amigos, convites e lobby.
- [ ] Criar duas campanhas; continuar cada uma; confirmar isolamento e inventário.
- [ ] Fechar completamente/reabrir; CONTINUAR preserva vida, créditos, posição,
      equipamentos, blueprints/investigação, narrativa e mundo persistente.
- [ ] Casa → Cidade Baixa → Industrial/Laboratório; saídas alternativas, revisita,
      transições repetidas, câmera/HUD prontos antes de liberar os controles.
- [ ] Loading aparece antes do preparo; barra real somente na fase de recursos;
      demais fases indeterminadas; animação leve e texto legível em 20:9.
- [ ] Segurar/spammar toque durante loading não move/ataca/pula/dasha. Após concluir,
      os controles funcionam. Cancelar retorna ao estado anterior sem progresso duplicado.
- [ ] Falha/recurso ausente apenas em cópia descartável: mensagem clara, sem revisão
      vazia. Não corromper saves reais para testar recuperação.
- [ ] Matar processo durante transição em campanha descartável, reabrir e recuperar
      último snapshot íntegro. Suspender/retomar Android durante loading.
- [ ] Três dashes, bloqueio do quarto, recuperação após um/dois/três; oito quadros
      oficiais, pulo/pulo duplo, colisões, combate, knockback, IA e recompensas.
- [ ] Morte/retorno à Casa, pausa/inventário/HUD e troca de equipamento.
- [ ] Solo sem lobby aberto: LAN e ponte de gameplay inativos. Serviço privado
      autorizado mantém notificações; sair/entrar novamente conclui handshake.
- [ ] Dois APKs privados: movimento, região, bloqueio até snapshot, perda/retomada
      de conexão, indicador de espera, janela de 10 minutos e saída ao menu.
- [ ] Repetir com quatro APKs físicos e rede WAN. Não substituir por loopback.
- [ ] Comparar chuva, iluminação, partículas, reflexos, pixel art e animações. Nenhuma
      diferença visual perceptível é aprovada automaticamente por testes headless.

Aprovação: ausência de erros de script/perda de dados, invariantes funcionais acima,
frames longos reduzidos de forma reproduzível sem piora visual. Meta de FPS depende
da medição física; ainda não existe ganho de FPS Android aprovado nesta missão.
