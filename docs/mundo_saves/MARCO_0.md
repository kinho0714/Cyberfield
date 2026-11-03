# Marco 0 — auditoria, 03/11/2026

Estado: IMPLEMENTADO (auditoria documental). Sem teste físico ou aprovação do proprietário.

Base: `dbffe330990c90836223639622f79a2d176c768d`, branch original
`cyberfield-p0p1-2026-11-02`. Raiz real: diretório que contém este repositório e
`project.godot` (Cyberfield, features 4.7 / GL Compatibility).
Branch de implementação: `codex/mundo-saves-marcos-0-1-2026-11-03`.
Nenhuma mudança rastreada na entrada; seis assets privados não rastreados,
registrados por SHA-256 em `private_files_baseline.json`, sem copiar seu conteúdo.
Não houve reset, limpeza, troca forçada ou acesso de escrita aos saves existentes.

## Fontes

Missão lida integralmente em Download/CYBERFIELD_MISSAO_MUNDO_SAVES_COOP_CODEX.txt.
Bíblia encontrada e consultada em Download/Cyberfield_Bible_Lore_2026-10-31.md.
Sete Guardas, Kai ex-02, Mara e Viktor confirmados; demais postos pendentes.
Este marco não cria lore, estados ou distribuição. PDF de análise e Map_legend.webp
encontrados em Download; conteúdo não analisado neste marco de persistência.
Vídeo `2026_11_02_18_01_48.mp4` não encontrado em Download nem no repositório.
Fluxograma geral não identificado com segurança. Não afirmar leitura dessas fontes.
Checkpoint anterior e CLAUDE.md consultados. Nenhum AGENTS.md encontrado na árvore pai.

## Arquitetura real e riscos

- `scene/main.tscn` compõe serviços como filhos, sem seção de autoload no projeto.
- `scene/room_manager.gd`: menu → hub → run, criação dos jogadores, geração,
  transições, câmera e retorno. Integração de persistência deve respeitar
  `is_transitioning`, solo e autoridade LAN.
- `scene/run_manager.gd`: seeds, estágios, economia temporária, participantes,
  resultados, loot e mapas. `map_states` contém objetos BiomeMapState e exige
  serialização explícita (`to_dictionary`/`apply_dictionary`).
- `scene/meta_progression.gd`: perfil v4 global em `user://cyberfield_meta_v1.json`.
  Blueprints, arsenal, casa, créditos e IDs de resultados processados. Gravação
  direta, sem checksum, backup ou snapshot. Loader tolera legado v1–v3.
- `scene/dev/dev_mode.gd`: muda perfil para sandbox antes de ações artificiais;
  desligar recarrega meta, mas deixa vida/equipamento/economia da sessão vivos.
  Corrigir restaurando a sessão legítima capturada ANTES da primeira ferramenta.
- `scene/biomes/`: geração existente, diretores, mapa, loot, saídas e armadilhas.
  Reusar seed e verificar assinatura antes de restaurar objetos.
- `entities/player.gd`: estado de rede já cobre vida, armas, munição, implantes,
  atributos e gadgets; rede não equivale a snapshot completo de execução.
- `scene/network/lan_session.gd`: LAN real existente, snapshots de jogadores,
  inimigos e pickups. Desconexão do host retorna ao menu; não há protocolo de
  campanha compartilhada/reconexão persistente. Não alterar no Marco 1.
- `scene/mode_select.gd`, `pause_menu.gd`, `meta_lab_ui.gd`: interfaces existentes;
  touch manual porque emulação de mouse está desligada. Adicionar acesso aos slots
  sem reescrever as opções congeladas ou os controles.
- `tests/`: muitos smoke tests Godot e verificações estáticas Python. Nenhum
  executável Godot encontrado em PATH, home (profundidade 4) ou /tmp. Registros
  antigos de Godot no scratchpad não comprovam disponibilidade neste Termux ARM64.
  Windows e Android usam `res://`/`user://`; não adicionar caminhos absolutos.

## Plano ligado ao código

1. Serviço de armazenamento independente: envelope versionado, checksum, arquivo
   temporário, rename, duas revisões anteriores válidas, fallback por revisão,
   rejeição de versão futura, slots com IDs aleatórios e exclusão confirmada.
2. Adaptador da sessão existente: metaprogressão, run, mapas, jogadores e objetos
   da sala, seed/assinatura; ignorar referências Node/Resource na serialização.
3. Controlador solo: campanhas novas independentes do perfil legado, autosave
   configurável, suspensão/menu, continuar explícito, sem carregar automaticamente
   nem converter o perfil antigo. Campanhas DEV não podem gravar no slot real.
4. Isolamento DEV: snapshot anterior à primeira alteração; restauração ao desligar.
5. Testes de corrupção/backup/slots/versão e cena real em scripts Godot, além de
   verificações executáveis disponíveis no Termux. Sem motor, marcar integração
   como não comprovada e registrar instruções de teste Android.

Próximo: Marco 1. Critério de conclusão exige salvar/restaurar uma sessão real no
motor; código e parser sozinhos não satisfazem esse critério.
