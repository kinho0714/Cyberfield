# Backend G14 — preparação local, sem implantação pública

## Papéis e limites

O serviço Python tools/private_coop/relay.py aceita WSS em loopback e até oito
salas, doze conexões totais. Cada sala fixa 2–4 assentos ao criar; padrão quatro.
Uma chave de proprietário de alta entropia autoriza criação; convites de uso único
autorizam entrada e capacidades de retomada são rotacionadas. Isso NÃO autentica
contas/pessoas. O host Godot é autoridade da simulação. O Python continua relay de
protocolo com admissão/limites/checkpoints; não calcula física/dano nem impede um
proprietário malicioso. Não anunciar servidor dedicado autoritativo Python.

No G14 ambos precisam permanecer ativos: backend Termux ARM64 e host Godot/APK.
Somente o backend não executa a partida. Lock de atividade, suspensão do Android,
foreground service, temperatura e consumo sustentado precisam ser medidos.

## Preparação (revisar antes de executar no aparelho)

- Python 3, dependência fixada em tools/private_coop/requirements.txt e OpenSSL.
- Instalar dependências em ambiente isolado; não versionar venv, tokens ou chaves.
- Certificado de servidor válido para o hostname e chave privada fora do projeto,
  em diretório privado de Termux (não Download/armazenamento compartilhado).
- Chave do proprietário aleatória de pelo menos 32 caracteres via variável de
  ambiente CYBERFIELD_HOST_KEY; não colocar no argumento, log, histórico do shell,
  configuração versionada ou APK. Os convidados recebem somente seu convite.
- Diretório exclusivo de dados cooperativos, permissões 0700/0600 e backup privado.
- Inicialização local: python tools/private_coop/relay.py --cert <certificado>
  --key <chave-privada> --data-dir <diretorio-privado> --port 27842
- Bind continua fixo em 127.0.0.1. Nenhum túnel, regra de roteador ou serviço público
  foi criado nesta missão. Não expor SSH, Termux, diretórios ou administração.

## Retomada e segurança

Checkpoints separados dos saves solo guardam estado compartilhado, recibos e
hashes de capacidades; não guardam os tokens em claro. Após reiniciar o serviço,
as salas recuperáveis entram pausadas e exigem as capacidades existentes de cada
assento. Convites não são recuperados. Todos os assentos devem retornar. Arquivos
corrompidos são ignorados, versões anteriores válidas são mantidas. Checkpoints
com mais de dez minutos ou suspensos não reativam a sessão após reinício.
Somente três checkpoints válidos por sala são retidos pelo mecanismo existente.

Teste de recuperação instancia outro Relay sobre arquivos descartáveis e valida
a retomada/rotação por cada assento. Isso não comprova recuperação de um APK host
morto: tokens do cliente ficam em memória; Keystore/token storage e reconstrução
integral do host ainda não existem. Não persistir tokens em JSON para contornar.

Limites existentes: TLS >=1.2, mensagens <=96 KiB, snapshots <=64 KiB,
40 mensagens/s com burst de 60 por conexão, profundidade/complexidade limitadas,
inputs booleanos em allowlist, sequência monotônica, estado/eventos somente host,
recibos únicos <=1024/sala. Retomada mantém a sequência recebida. Eventos de chat e
RPC arbitrária são recusados. Não existe chat/E2EE nem autenticação de contas.

Dados em repouso não são criptografados; permissões protegem o sandbox, checksum
verifica corrupção e não substitui autenticação/criptografia. Avaliar Android
Keystore para capacidades futuras e proteção do backup. Não guardar contatos ou
dados pessoais no snapshot de gameplay. Logs não devem incluir tokens/cabeçalhos,
conteúdo dos convites ou snapshots. Retenção das salas encerradas precisa de uma
API explícita de exclusão e política do proprietário antes de uso público;
esta rodada não apaga automaticamente diretórios existentes.

## Internet e CGNAT

CGNAT não foi medido; ENet/UDP direto requer conectividade de entrada. Não presumir
IP público ou port forwarding. Tailscale privado exige cliente dos participantes
e não satisfaz sozinho o requisito de convidados com apenas APK.

O [Funnel oficial](https://tailscale.com/docs/features/tailscale-funnel) oferece
proxy público TLS em 443/8443/10000 com DNS ts.net, políticas e limites de banda;
exige plataforma com CLI. O aplicativo Android instalado não comprova suporte ao
Funnel no Termux nem valida a combinação no G14. Precisa de investigação prática
separada; nenhuma regra foi ativada.

[Cloudflare Tunnel](https://developers.cloudflare.com/tunnel/concepts/) usa conexão
de saída, candidato a contornar CGNAT somente para o serviço de jogo. A documentação
[WebSockets](https://developers.cloudflare.com/network/websockets/) informa suporte,
quedas por reinício e ausência de inspeção dos frames pelo WAF após o upgrade.
Inferência: o túnel nomeado é candidato, mas exige endpoint, configuração do
certificado/CA do origin e validação da cadeia TLS, sem desativar verificação.
Conta/domínio, disponibilidade/gratuidade e execução ARM64 precisam ser confirmados
antes de implantação. Não contratar plano ou publicar endpoint sem autorização.

## Medição

benchmark_protocol.py mede parsing de 10 mil mensagens e vinte checkpoints de
32 KiB em dados descartáveis, sem abrir sockets. Evidência:
evidencias/protocol-benchmark.json. RSS é o pico do processo Python; não representa
RAM de quatro Godot, temperatura, FPS, bateria, banda, ping ou capacidade online.

Pendente no G14: medir host + relay por 30 minutos com quatro APKs, jitter/p95,
CPU/RAM, bateria/temperatura, troca Wi-Fi/dados, suspensão/retomada, queda de host,
reinício do serviço e autorização negativa. Convidados não instalarão Termux/VPN;
somente um endpoint WSS aprovado deverá ser embutido/configurado pelo cliente.
