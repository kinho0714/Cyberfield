Visual Integration Pass 2 — Pause / inventory / settings presentation
Source: cyberfield_hud_ui_complete_integration_bundle_v1.zip
Source SHA-256: 584b0b31883dc2111a50f60a309af7479d68af50c03aec17c0663d6e0be0f12f
18 unmodified runtime-ready PNGs; used_assets.json records official metadata/hashes.
NinePatchRect and StyleBoxTexture retain manifest slice margins.

Pause uses a left action rail. Settings occupies the right content panel, with
JOGO / CONTROLES / ÁUDIO tabs filtering existing controls. No fake video settings.
Title-screen settings uses the same panel centered without the Pause rail.
Camera, touch scale, debug, audio persistence and popup/gesture backends remain.
Inventory retains two real equipped slots, with separate read-only preview and
STATUS / RUN summaries sourced from existing player/run data. Explicit activation
still equips; focus/hover only previews. No concept weapons, gadgets or new slots.
Decorations ignore input. Layout adapts to viewport size at resize, not per frame.

Physical Godot 4.7.2/Android validation is required: every page, long names,
focus return, LAN local modal behavior, all audio controls, repeated dropdown
selection, horizontal slider drag versus vertical scroll, and wide-screen layout.
