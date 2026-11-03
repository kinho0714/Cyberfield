# Validação física — ainda pendente nesta missão

Não usar saves reais para cenários destrutivos. Criar campanha descartável.
Não apagar diretórios de campanhas/identity nem substituir assets privados.
Somente os resultados de saves relatados anteriormente pelo proprietário são
aprovações manuais; os recursos desta rodada não foram testados fisicamente.

## Dash (disponível diretamente no jogo)

1. Executar com Jhon e observar rolamento tático oficial. Dar um dash e pressionar
   rapidamente novamente antes de 0,15 s do término: tentativa deve ser rejeitada.
2. Dar três dashes, respeitando 0,15 s entre o fim de um e o próximo. Um quarto
   antes de 0,75 s do último término deve ser rejeitado.
3. Repetir usando somente um e somente dois. Esperar 0,75 s sem dash e confirmar
   sequência completa restaurada. Correr, pular e combater nesse intervalo.
4. Manter o botão pressionado e repetir toques muito rápidos/multitoque. Não pode
   superar o orçamento nem ignorar o intervalo. Toque rejeitado não reinicia recovery.
5. Usar dash no ar, em direção a parede/plataforma e após golpe final com cancel.
   Confirmar direção/colisões/combo/retorno de animação. Não há teleporte novo.
6. Testar interrupção por dano após iframes, downed, pausa e transição. Não recarregar
   no meio do movimento. Nova run começa com três; retomada de snapshot inativo
   conserva os campos escalares do orçamento e respeita o tempo de simulação.

## Mundo, IA e missões

- Área procedural/saídas A/B: mapa, escadas e passagens existentes devem continuar
  acessíveis, com as mesmas seeds e sem perda de posição/equipamento após salvar.
- Aproximar/afastar durante telegraph inimigo: ataque interrompido não deve acertar
  um alvo substituído. Congelar comuns, pesados e atiradores durante preparação.
- Revisita pelo mapa e missão pela UI dependem do Claude conectar as APIs do contrato.
  Não há botão paralelo nesta branch. Usar campanha descartável após integração:
  visitar A/B, ferir inimigo, abrir baú, coletar recompensa, voltar a A, sair/reabrir.
  Vida do inimigo e baú devem continuar preservados; dinheiro/inventário não retrocedem.
- Registrar definição técnica aprovada, ativar, cumprir eventos, receber recompensa,
  fechar/reabrir e tentar receber novamente. Nenhum crédito duplicado. Testar também
  pré-requisito, falha, DEV e duas campanhas independentes.

## Coop e G14

Os testes automatizados usam processos Godot Linux headless e TLS em loopback;
não são APKs físicos nem conexão de internet. Para teste em aparelhos é necessário
primeiro integrar a ponte no fluxo do Claude e obter autorização para um endpoint.
Não ativar túnel automaticamente a partir deste documento.

Depois da integração/deploy autorizado:
- Dois APKs primeiro; depois proprietário + três convidados, cada qual com APK e
  internet apenas. Verificar personagem/assento, movimento, animação, dano e transição.
- Testar convite inválido/usado, quinto jogador, replays e mensagens inválidas.
- Queda e retorno de convidado devem pausar e retomar sem input preso/recompensa extra.
- Separar reinício do relay de morte do host: retomada integral de host morto ainda
  é pendência de implementação, não promessa a validar como pronta.
- Medir RAM/CPU, temperatura, consumo e latência/jitter durante 30 min no Moto G14.
  Testar suspensão e troca Wi-Fi/dados. Nenhum número do microbenchmark é FPS/bateria.
- Usar inventários/campanhas descartáveis para a bateria de testes. Não comparar a
  cópia cooperativa a uma campanha solo modificada; os namespaces são separados.

Pendências de implementação detalhadas em COOP_CONTRATO.md. Quatro APKs pela
internet não estão homologados e o backend não foi publicado.
