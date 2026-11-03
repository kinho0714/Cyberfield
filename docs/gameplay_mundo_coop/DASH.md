# Dash — três usos e recuperação por inatividade

Base publicada: 9b8d84332ddaff7c7b8db7a13f7eb0ede48aba4d.
Branch de trabalho: codex/gameplay-mundo-coop-2026-11-03. Sem push.

Player exporta dash_capacity=3, dash_minimum_interval=0.15 e
 dash_recovery_delay=0.75. Intervalos começam ao terminar/interromper o movimento.
O relógio usa delta de física; a fração restante do tick após o término conta
como inatividade. Não acumula recuperação no movimento, não depende de render FPS.
A entrada real _start_dash valida orçamento/combate, incluindo chamadas diretas.
Bloqueios não consomem cargas, não reiniciam o relógio e não alteram o combo.
Pulo/ataque/corrida continuam disponíveis conforme regras anteriores. O dash aéreo
existente continua permitido e consome o mesmo orçamento. Pausa congela simulação.
Dano, downed e desabilitação de input encerram movimento sem devolver cargas.
Nova run reinicia o orçamento. As folhas oficiais, movimento e colisões não mudam.

API para a UI do Claude: Player.get_dash_available() e
 dash_sequence_changed(available: int). Nenhuma alteração de HUD/menu.

Executado no Godot 4.7.2 Linux ARM64 via PRoot, projeto e XDG isolados:
- dash_sequence_smoke_test: failures=0 (1/2/3 usos, quarto bloqueado, spam direto,
  intervalo, recuperação parcial/completa, interrupção, 30/60/120 passos por segundo).
- jhon_design_b_animation_smoke_test: JHON_B_REPORT failures=0.
- exploration_routes_smoke_test: EXPLORATION_REPORT failures=0 (geometria existente).

Ainda pendente: toque rápido/multitoque no Godot Android/APK, sensação de intervalo,
rolamento oficial de oito quadros durante saltos, colisões, paredes, plataformas,
ataques e pausas em aparelho real. Nenhuma nova aprovação manual foi presumida.
Os testes são executados em cópia temporária; saves existentes não são usados.
