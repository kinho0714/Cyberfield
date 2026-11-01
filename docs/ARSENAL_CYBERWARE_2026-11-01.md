# Arsenal, cyberwares e slots ativos — 01/11/2026

Branch local `claude/cyberfield-patch-integration-7ek1p2`, criada de `dev/visual` (`ce3fae3`).
O trabalho noturno não commitado de 31/10 foi preservado num commit WIP na branch local
`visual-noturna-2026-10-31` (não mesclado). A branch local antiga de mesmo nome (29/10) foi
renomeada para `backup/claude-patch-integration-2026-10-29`. Sem push.

## Fluxo jogável
1. **Run:** armas aparecem nos pickups do bioma (pool = licenças + protótipos descobríveis),
   cada cópia com raridade sorteada (Comum/Incomum/Raro, viés por estágio, RNG próprio por
   `pickup_id`+seed — o RNG da geração do bioma não é consumido a mais). Pegar a arma registra o
   **blueprint** na run. Elites/pesados/chefe (e raramente comuns) derrubam **cyberware**
   ([USAR] instala se o slot estiver livre ou se for melhor).
2. **Fim da run:** blueprints chegam ao terminal **mesmo na derrota**; cyberware achado é
   extraído na vitória e vira sucata na derrota. O resumo da run mostra os dois.
3. **Casa do Jhon (terminal existente → "Oficina de Operações"):** estudar blueprint →
   fabricar com sucata na raridade escolhida → definir loadout (S1/S2) → fabricar/melhorar
   (MK1–3)/instalar/desmontar cyberwares → fabricar e equipar os dois acessórios (A1/A2).
4. **Próxima run:** `RoomManager.apply_meta_loadout()` aplica armas+raridade, implantes e
   acessórios ao entrar no hub e ao iniciar a run. Morte/retorno limpam o que era só da run.

## Armas (12; 7 categorias com comportamento próprio)
| Arma | Categoria | Comportamento |
|---|---|---|
| Lâmina de sucata, Sabre íon | lâmina | rápida, um alvo |
| Bastão de beisebol*, Cano de ferro*, Martelo quebrador | impacto | varre até 3 alvos (consulta de área), empurrão maior |
| Pistola improvisada*, Pistola corporativa* | pistola | tiro único, dispersão baixa/média |
| Carabina pulso | semiautomática | cadência alta, carregador grande, dispersão |
| Escopeta de sucata* | escopeta | 6 chumbos por raio, dano somado por alvo (inimigos ignoram golpes por 0,1 s) |
| Rifle de pulso* | rifle | feixe rápido que perfura 2 alvos |
| Emissor de arco, Arco neon* | arco | flecha em parábola (gravidade) que perfura |
`*` = nova. As 5 antigas mantêm números; mudança funcional: emissor de arco virou arco
(parábola + perfura 1), pedido explícito da missão.

## Cyberwares (6 linhas, 4 slots de `GameplayProgressionFoundation`)
Força (braços: empurrão, mergulho, cadência C/C) · Dano físico (braços: lâminas, mergulho,
pistolas, escopetas) · Velocidade (pernas) · Dash (pernas: duração, velocidade, invulnerabilidade)
· Intelecto (neural: dano à distância, recarga, precisão) · Saúde (torso: vida máx., cura das
poções). Efeito = por nível × nível × multiplicador da raridade. Raridade ≠ nível.

## Slots ativos (F/G · LT/D-pad ▲ · botões touch)
Granada criogênica (congela + lentidão, 2 cargas/9 s) · Granada incendiária (explosão + chão
em chamas + queimadura, 2/10 s) · Torreta portátil (12 s, mira o inimigo vivo mais próximo com
linha de visada, 1/22 s). Efeitos de status em `scene/combat/enemy_status.gd` (ajuste de
`move_speed` por razão, restaurado ao fim; dano de efeito não interrompe ataques).

## Raridade
`scene/equipment/rarity_table.gd`: Comum/Incomum/Raro ativos; Épico/Lendário descritos e
desligados (`enabled=false`) — ligar não exige reescrita.

## Arte (original, `tools/visual/arsenal_art.py`)
7 armas novas, 8 projéteis + 3 impactos, rastros de golpe (lâmina/impacto), 5 clarões de
cano, gelo/fogo (estado, explosão, chão em chamas), granadas e torreta animadas, 6 ícones de
cyberware + molduras de raridade, 3 ícones de acessório. A arma aparece sobreposta ao
personagem durante golpe/disparo (`scene/fx/weapon_fx.gd`); as folhas oficiais não mudaram.

## Persistência
`MetaProgression` v4: `armory`, `loadout_weapons`, `cyberwares`, `installed_cyberwares`,
`owned_accessories`, `equipped_accessories`. Saves v1–v3 carregam com esses campos vazios.

## Limitações conhecidas
- LAN: o loadout da Casa vale só para o jogador do host; clientes começam com a lâmina e não
  veem granadas/torreta (só o dano e os tiros da torreta replicados). Drops de cyberware só no host.
- A arma sobreposta é provisória: não há poses de personagem segurando cada arma.
- Sons: reaproveitam eventos existentes (`weapon_fire_*`, `weapon_impact`, `loot_open`).
- Balanceamento não medido em playtest.
