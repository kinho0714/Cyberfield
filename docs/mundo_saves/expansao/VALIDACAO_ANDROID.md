# Validação no Godot Android 4.7.2 / Windows

Esta rodada altera somente código/dados/menus/documentação. Não requer importar
outro projeto, substituir sprites, apagar saves ou executar reset. Abra o projeto
original, aguarde importação e execute a cena principal. Conserve os seis assets
privados locais. A criação/continuação/recuperação básica e dois slots independentes
já têm aprovação manual anterior; os recursos novos abaixo ainda precisam dela.

## Testes manuais prioritários

1. Continue uma campanha existente. Confirme posição, vida, recursos e equipamentos.
   Verifique que apareceu MUNDO CONHECIDO sem perder o save anterior; os nomes
   provisórios não são lore oficial. Crie uma campanha descartável para os demais
   testes, mantendo as campanhas reais intactas.
2. No hub, abra MUNDO/SESSÃO. Confira regiões conhecidas, teclado/toque/rolagem e
   seleção para a próxima run. Ajuste autosave 15/30/60 s e reabra para confirmar.
   Não deve aparecer localização/distribuição interna dos Guardas.
3. Inicie uma run; abra um baú, colete arma/munição/recursos e danifique um inimigo.
   Saia pela rota B; compare rótulo e destino. Encerre a execução após salvamento
   consistente e reabra: estado, baú, inimigo e transição devem permanecer, sem
   duplicar pickups. Combate com corrotinas adia a captura; observe a indicação.
4. No hub e na run descartáveis, anote valores e use DEV para alterar vida, dinheiro,
   arma e créditos; inicie uma run ainda em DEV, depois desative. Deve voltar à
   sessão legítima anterior, sem consumir contador/seed do mundo real nem publicar
   geografia artificial. Derrota deve manter permanentes e reiniciar temporários
   conforme a política existente; repetir apresentação do resultado não duplica prêmio.
5. A/B: alterne campanhas, renomeie, cancele exclusão e exclua somente um slot de
   teste. O outro deve permanecer. Exclusão é arquivamento do slot, não apagamento
   físico. Copiar perfil legado deve criar uma campanha nova sem modificar a origem.
6. Troque de app, suspenda, encerre e reabra em pontos distintos; verifique intervalo
   de autosave, falta de espaço em ambiente de teste e desempenho. Não corrompa
   manualmente saves reais. Corrupção/versões/falhas são cobertas primeiro pelos
   fixtures dos testes automatizados, que usam namespaces `test_*` separados.
7. PERFIL/AMIGOS: nome, identificador público local, adicionar/remover contato,
   solicitação local não enviada, bloquear/desbloquear e reabrir. Deve mostrar offline
   e não exigir conta para solo. Perfil e campanhas não compartilham identificadores
   privados ou arquivos de progresso.

Repetir em Windows, incluindo gravação/rename/carga, toque quando disponível e
transições entre os três biomas. Não estender um teste aprovado a todos os campos
sem registrar o que foi realmente observado. Registrar versão/commit, contexto
hub/bioma, passos, resultado esperado/observado e erro completo se houver.

## Testes automatizados no motor

Os scripts novos usam namespaces descartáveis próprios. O runner integrado exige
uma cópia de teste para evitar executar sobre o workspace original. Nesta rodada
foi usada cópia temporária com dados XDG separados e Godot 4.7.2 oficial headless;
a cópia não é outro jogo e não é entregue como substituta do projeto.

```sh
godot --headless --path CAMINHO_DA_COPIA --editor --import
python -B tools/validate_integrated_expansion.py --godot CAMINHO_DO_GODOT --project CAMINHO_DA_COPIA --output CAMINHO_DOS_LOGS
```

O runner executa store, sessão integrada, mundo, rotas, perfil, DEV e exploração
física existente (30 biomas de fixture, escadas e passagem de dash). Exige marcador
de aprovação e ausência de SCRIPT ERROR; mantém avisos do motor nos logs. Não
transforma simples exit code 0 em aprovação. O teste WSS específico precisa do
harness Python, não deve ser iniciado sozinho sem fixture TLS.

```sh
python -m pip install -r tools/private_coop/requirements.txt
python -B tests/private_relay_test.py
```

OpenSSL é dependência de teste para certificado descartável. O teste de cliente
Godot dentro do harness exige variáveis `CYBERFIELD_GODOT` (executável/launcher) e
`CYBERFIELD_TEST_PROJECT` (cópia isolada importada). Sem elas esse caso é SKIPPED,
não aprovado; os demais casos de protocolo continuam executáveis. Dependências
podem ser instaladas em venv/temporário; não são plugins adicionais no APK.

## Coop privado: teste futuro, não disponível publicamente agora

Não há endpoint, conta backend ou túnel configurado. O menu WSS é protótipo de
transporte: não cria jogadores no cenário nem inicia gameplay sincronizado. Não
interpretar estado `active` do protocolo como coop completo. Os testes atuais são
loopback, com um host Godot e três clientes de protocolo Python; não são quatro APKs.

Antes de convidados reais: escolher/aprovar infraestrutura gratuita compatível e
endereço TLS válido; configurar somente o serviço de jogo no G14/relay, sem expor
Termux, SSH, shell ou diretórios. Segredo do proprietário fica fora de APK/Git/logs;
três capacidades privadas expiráveis são entregues individualmente aos convidados.
Não enviar segredos nesta conversa. Os convidados precisam de endpoint + convite
no APK; nenhuma VPN/Termux é prevista nos aparelhos deles.

O serviço implementado só abre loopback e exige certificado/chave e diretório de
coop explícitos. Para teste local do proprietário, após configurar o segredo via
ambiente local e certificados apropriados (não versionados):

```sh
python tools/private_coop/relay.py --cert CAMINHO_CERT --key CAMINHO_CHAVE --data-dir DIRETORIO_COOP_DESCARTAVEL
```

Isso não publica o serviço. Publicação/túnel dependem de autorização e configuração
separadas. Mesmo após conectar os quatro, ainda é necessário integrar o transporte
à autoridade/replicação do gameplay e testar quatro APKs em redes reais, queda do
host e retorno, prazo real de dez minutos, backup do participante, recuperação de
reinício do relay/G14 e ausência de duplicação. Não prometer esses resultados antes
de executá-los. Identidade/amigos online precisam de backend autenticado real.
