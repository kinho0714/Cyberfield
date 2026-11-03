# Exploração, missões e combate — contrato técnico

Branch codex/gameplay-mundo-coop-2026-11-03. Nenhuma alteração de menus/HUD.
Base: origin/codex/expansao-privada-2026-11-03, 9b8d843.

## Exploração e revisita

WorldTracker.remember_current_area() captura uma área consistente da run, com
seed, assinatura, objetos, baús, inimigos e posição de retorno. A saída regional
existente chama essa API antes da transição. visited_areas() retorna somente IDs e
localizações da run atual; visited_areas_changed avisa a interface.
revisit_area(area_id) retorna bool e rejeita DEV/LAN/hub, transições, combate
assíncrono, outra run e a própria área atual. A restauração mantém o inventário,
vida, créditos e dinheiro ATUAIS, assim como o ledger cumulativo da run e mapas;
restaura somente contexto/geometria/objetos da área. Falha tenta restaurar a cena
anterior. save_now persiste após sucesso; falha de escrita deixa dirty para retry.

Arquivos de áreas ficam no próprio world da campanha, protegidos pela mesma
revisão/backups. Arquivos legados sem visited_areas funcionam normalmente. Na
primeira captura de outra run os arquivos de áreas anteriores são substituídos
somente em memória; descobertas permanentes permanecem em world.exploration.
Não há reconstrução permanente de áreas de runs anteriores nem novos cenários
canônicos. Hierarquia, dez estados, sete slots reservados e três investigativos
continuam conforme catálogo anterior. Seeds e grafos existentes foram preservados.

## Missões

CampaignController.geography fornece:
- register_mission(definition: Dictionary) -> bool
- activate_mission(id: String) -> bool
- record_gameplay_event(type, event_id, payload={}) -> void
- claim_mission_reward(id: String) -> bool
- mission_states() -> Dictionary (cópia defensiva)
- mission_states_changed (sinal)

Definição confiável do projeto: id, prerequisites (IDs já registrados), objectives
(array de {id, event, target opcional, count}), reward_credits opcional. Estados:
blocked/available/active/completed/failed. MissionLedger.fail implementa falha.
Missões são únicas, sem repetição automática. Versão atual não concede itens ou
armas: apenas créditos explicitamente definidos pelo autor do conteúdo. Exemplos
com recompensa ficam exclusivamente nas fixtures descartáveis dos testes.

Eventos aceitos: location_discovered, npc_interacted, enemy_defeated,
item_collected, investigation, region_transition. Descobertas/salas, transições,
mortes e coleta de dinheiro reais estão conectados. NPCs e investigações futuras
precisam chamar record_gameplay_event com ID estável; não existe diálogo novo.
O mesmo evento não conta duas vezes na mesma missão; morte repetida também é
rejeitada no RunManager. Prerequisitos liberam missões após conclusão, não após
receber recompensa. Crédito e recibo reward_claimed são gravados na mesma revisão
antes de mudar o saldo em memória, impedindo recompensa repetida após retomada.

A Bíblia externa Cyberfield_Bible_Lore_2026-10-31.md foi consultada. Ela deixa ordem
exata das missões e cinco Guardas pendentes. Nenhuma missão canônica, identidade,
diálogo ou descoberta narrativa foi inventada. O framework fica disponível para
definições aprovadas; não há campanha narrativa completa jogável nesta entrega.

## IA e combate

Auditoria: Enemy já patrulha com RNG por ID, seleção de alvo com margem de troca,
checagem de piso/parede, knockback e geração de ataque. RangedEnemy possui máquina
de estados própria; HeavyEnemy deriva Enemy. Esses sistemas foram mantidos.
Correção: sair da detecção/trocar alvo invalida o windup; coroutine antiga não limpa
o estado de ataque novo. Alcance é revalidado no impacto. Congelar cancela ataques
e impede reinício em comuns/pesados/atiradores. Armas/danos/velocidades não foram
rebalanceados. Hitboxes, colisões e designs oficiais permanecem existentes.

## Evidência

Godot 4.7.2 Linux ARM64 headless via PRoot, cópia/XDG isolados:
- gameplay_progression_smoke_test: failures=0; campanha real, área procedural,
  retorno com vida do inimigo preservada e economia atual, missão por evento real,
  pré-requisito, recibo único e reabertura da campanha, estado de falha.
- enemy_interruption_smoke_test: failures=0; saída durante windup e congelamento
  nas três classes existentes.
- Store, sessão, mundo e rotas: failures=0 na regressão desta rodada.

Persistem avisos de recursos/ObjectDB ao encerrar alguns testes integrados, como na
base. Não anunciar ausência de leaks. Faltam playtest Android de revisita/colisões,
falhas reais de armazenamento, narrativa aprovada, UI do Claude e cobertura física
ampla de IA. Não são testes manuais nem validação do APK/Windows.
