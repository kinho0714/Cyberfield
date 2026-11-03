# Expansão integrada — relatório e continuidade

Base real: `2fafe4716a7899ccf29f23e1c15a64365aeb1d44`.
Branch: `codex/mundo-saves-marcos-0-1-2026-11-03`. Sem push/deploy.
A missão ampla autoriza o avanço antes suspenso; não equivale a homologação de
requisitos não testados. Saves reais não foram usados para testes nem reescritos
pelos comandos desta rodada. Assets privados continuam não rastreados, com hashes
conferidos. Nenhum personagem/asset aprovado, lore, export ou combate foi substituído.

| Conjunto | Implementação e evidência | Pendência essencial |
| --- | --- | --- |
| Marco 1 | Revisões/backups, fallback semântico, ledger permanente, DEV e mensagens; store/session/DEV no motor real; evidências manuais anteriores preservadas | Android/Windows da rodada, falhas de armazenamento reais, cobertura completa de estados assíncronos e desempenho |
| Marco 2 | Catálogo versionado, hierarquia, descobertas/posição, sete slots reservados fixos por campanha e visão pública filtrada; testes no motor | Conteúdo/geografia futuros e validação física; não inventar personagens pendentes |
| Marco 3 | Seeds campanha/run/área, rotas, ramificações, requisitos opcionais, assinatura/grafo salvos, transições reais; testes de determinismo/conectividade e exploração existente | Toda a campanha geográfica, habilidades físicas em todos os destinos e Android |
| Marco 4 | Perfil offline, privacidade, contatos/solicitações locais e bloqueios, backup; UI real e testes | Autenticação e amizades online com backend real; bloqueios vinculados a contas |
| Marco 5 | Relay WSS privado e cliente Godot, quatro assentos autorizados, inputs/estado por papel, revisão, reconexão, timeout, caches separados e segurança; sockets TLS reais | Ponte de gameplay, implantação aprovada, quatro APKs reais, recuperação após reinício total do G14/relay |

**Não declarar os cinco marcos completos.** Núcleos locais e protocolo são reais;
coop jogável por quatro convidados pela internet ainda não está pronto.

## Commits por conjunto

- `d1f79b0`: saves, recuperação compatível e testes reais de sessão.
- `7e622a6`: mundo persistente, rotas/áreas determinísticas e UI geográfica.
- `0c21fc8`: perfis locais, cliente WSS/interface e guards DEV/saídas regionais.
- Backend privado, harness TLS, documentação e evidências finais ficam no commit
  seguinte, identificável por `feat(coop): add private four-seat WSS relay prototype`.

## Validações executadas e limites

Godot **4.7.2.stable.official.ed1daf0bf**, Linux ARM64 headless via PRoot no Termux,
ZIP oficial com SHA-512 verificado. Projeto copiado e XDG isolado no temporário.
Após instalar bibliotecas de suporte no temporário, fontes do sistema não são
necessárias ao teste; fontes oficiais do projeto continuam importadas. Esta é uma
execução real do motor, não equivalência à exportação APK ou ao Windows.

- `final/engine-results.json`: sete suítes, com marcador positivo, exit code e
  ausência de SCRIPT ERROR como critérios. Store, sessão integrada, mundo, rotas,
  perfil, DEV e exploração física preexistente. Sessão cobre baú sem respawn,
  equipamento/munição, inimigo por ID, transição e prévia de destino, fallback,
  início de run em DEV sem alterar mundo legítimo, derrota, blueprint e recompensa
  idempotente. A exploração cobre 30 gerações dos três biomas, escadas e dash.
- `relay-tests.log`: seis testes, conexões WSS/TLS reais em loopback e certificado
  validado, incluindo um host Godot real e três clientes Python de protocolo.
  Entradas/autoridade/revisões/convites/reconexão/rate limit e backups foram exercitados.
  Prazo de dez minutos testado com relógio controlado. Não são quatro APKs/jogadores.
- `static-results.json`: 31 verificações aprovadas (gramática ampliada, regressões,
  whitespace e seis hashes/ausência de rastreamento dos assets privados). Gramática
  não é usada como substituto dos testes do motor.
- Logs preservam avisos de ObjectDB/recursos/RIDs em uso ao encerrar sessão/exploração.
  Não alegar aplicação inteira sem leaks ou FPS/latência medidos.
- TESTADO EM DISPOSITIVO/APROVADO PELO PROPRIETÁRIO: somente os cenários manuais
  anteriores explicitamente informados, incluindo duas campanhas independentes e
  recuperação de interrompida. Novos recursos não herdam essa aprovação.

## Próxima etapa recomendada

1. Validar no Godot Android os fluxos de `VALIDACAO_ANDROID.md`, preservando os saves
   reais. Investigar avisos de cleanup e medir custo de snapshots em biomas longos.
2. Integrar o transporte privado à replicação/autoridade do gameplay, sem fundir
   estado compartilhado com campanhas solo nem enfraquecer autorização do relay.
3. Escolher backend de contas/amigos e infraestrutura gratuita de teste; obter
   aprovação antes de publicar endpoint/túnel. Não pedir segredos na conversa.
4. Só depois testar proprietário + três convidados em APKs e redes reais, quedas,
   retomada e recuperação. Não anunciar coop operacional com base em sockets locais.

Detalhes por conjunto: `MARCO_1_RODADA.md`, `MARCOS_2_3.md`, `MARCO_4_CLIENTE.md` e
`MARCOS_4_5_SEGURANCA.md`. Os runners, fixtures e instruções de Android/Windows ficam
versionados; binários, chaves, certificados e dependências temporárias não.
