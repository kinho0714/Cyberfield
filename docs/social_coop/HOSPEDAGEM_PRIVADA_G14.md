# Hospedagem privada no Moto G14 — projeto e roteiro (03/11/2026)

Estado: **PROJETO / ROTEIRO**. Nada foi publicado, nenhum túnel ou porta foi aberto,
nenhuma conta foi criada. Cada passo que expõe algo à internet exige autorização
explícita do proprietário antes de ser executado.

## Objetivo

Sessão privada para até quatro pessoas (proprietário + três amigos escolhidos), com o
Moto G14 como servidor inicial, sem que os amigos precisem entrar na rede Tailscale
pessoal do proprietário, sem VPN/Termux nos aparelhos deles e com transporte
criptografado.

## Arquitetura proposta

```
 Convidado (APK) ──WSS/TLS──►  borda pública do túnel  ──túnel de saída──►  G14
 Convidado (APK) ──WSS/TLS──►  (certificado válido)                        │
 Convidado (APK) ──WSS/TLS──►                                              ▼
                                                    relay.py em 127.0.0.1 (Termux)
 Anfitrião (APK no próprio G14 ou outro aparelho) ──WSS──►  mesmo endereço público
```

- `tools/private_coop/relay.py` (Codex, ampliado em 03/11) só escuta **127.0.0.1**,
  exige TLS, chave do anfitrião por variável de ambiente e convites de uso único.
- O túnel é uma conexão **de saída** do G14 (atravessa CGNAT sem abrir porta no
  roteador) e encaminha **apenas** o serviço do jogo. Nunca Termux, SSH, shell,
  painel administrativo ou diretórios.
- Os convidados usam o cliente nativo do jogo (WebSocketPeer + TLS do Godot), com
  validação normal de certificado. O endereço vai dentro do código de convite.

### Candidatos de túnel (nenhum configurado)

| Opção | Convidados precisam de conta/VPN? | Observações a verificar antes de escolher |
| --- | --- | --- |
| Cloudflare Tunnel (túnel nomeado) | Não | Requer conta e domínio; a borda termina TLS (a Cloudflare vê o tráfego — não é ponta a ponta); WebSockets suportados, conexões podem cair em manutenção. |
| Tailscale Funnel | Não (Funnel é público) | Endereço `*.ts.net` com certificado válido; portas públicas limitadas (443/8443/10000); **suporte no Android/Termux a confirmar**. Funnel publica para a internet, diferente de compartilhar a tailnet. |
| Porta aberta no roteador | Não | Depende de IP público (CGNAT provável em rede móvel); exige certificado válido próprio. Não recomendado. |

Os convidados **não** entram na tailnet pessoal em nenhuma das opções.

## Recursos do G14 (estimativas, não medidas no aparelho)

- Relay: um processo Python asyncio, mensagens JSON ≤ 96 KiB, snapshot ≤ 64 KiB,
  12 conexões e 8 salas no máximo, 40 msg/s por conexão (rajada 60). Para 4 pessoas o
  limite de rede é de dezenas de KiB/s por jogador enquanto não houver gameplay real.
- Memória/CPU **não foram medidas no G14**. Medir antes de prometer estabilidade:
  `top`/`ps -o rss` no Termux durante uma sessão real de quatro aparelhos.
- Android pode suspender o Termux: usar `termux-wake-lock` e manter o Termux em
  primeiro plano/notificação durante a sessão (a validar).

## Segurança (o que já existe e o que falta)

Existe e foi testado em loopback (TLS real, 4 clientes Godot reais):
- Convites: capacidade aleatória de uso único, expira em 10 min, só hash no servidor.
- Anfitrião revoga convites não usados (`revoke_invites`).
- Assentos atribuídos pelo servidor; reconexão com segredo rotacionado em memória.
- Entradas validadas (tipos, tamanhos, ações, sequência, revisões, cartões sociais).
- Nomes sanitizados no servidor (controles, quebras, marcas bidi/invisíveis).
- Sem log de payload, token, nome ou grafo social; snapshots em pasta 0700/0600.

Falta (antes de convidar pessoas reais):
- Conta/identidade verificada: hoje o convite autoriza **quem possui o código**.
- Restaurar salas/autorizações após reinício do relay ou do G14.
- Teste em rede real com quatro APKs, quedas e retorno.
- Gameplay sincronizado (ver `ARQUITETURA_SOCIAL_COOP.md`).

## Roteiro de teste local do proprietário (sem publicar nada)

1. No Termux: `pkg install python openssl` e
   `python -m pip install -r tools/private_coop/requirements.txt`.
2. Gerar a chave do anfitrião **no próprio aparelho**, sem colar em conversas:
   `export CYBERFIELD_HOST_KEY="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"`.
   Guardá-la num gerenciador de senhas; nunca no Git, no APK ou em logs.
3. Certificado: para teste local o Godot exige certificado válido para o nome usado;
   autoassinado só funciona no harness de testes (que confia nele explicitamente).
4. `python tools/private_coop/relay.py --cert CERT --key CHAVE --data-dir PASTA_COOP`.
5. Publicação (túnel) **somente após autorização explícita**, apontando apenas para
   `127.0.0.1:27842`.

## Checklist antes de publicar (exige "sim" do proprietário)

- [ ] Opção de túnel escolhida e conta própria do proprietário configurada.
- [ ] Endereço `wss://` com certificado válido testado num aparelho fora da rede.
- [ ] Chave do anfitrião gerada localmente e fora do Git/APK/logs.
- [ ] Nenhuma outra porta/serviço encaminhado (conferir configuração do túnel).
- [ ] Wake lock/foreground do Termux testado por uma sessão inteira.
- [ ] Plano de desligar: parar o túnel encerra o acesso público imediatamente.
