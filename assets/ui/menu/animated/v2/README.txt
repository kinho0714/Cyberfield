CYBERFIELD — ANIMATED MENU ASSET PACK V2

SOURCE OF TRUTH
- concept_master_v2_16x9.png
- Exact 16:9: 1536x864
- Derived from the approved uploaded Master V2 by minimal centered crop only.
- No stretching was used.
- Master V2 contains no baked lightning bolt and no baked rain streak layer intended for animation.

RUNTIME REFERENCE
- concept_master_v2_1280x720.png
- Exact logical resolution of Cyberfield.

V2 OVERLAYS
- lights_cyan_v2.png
- lights_magenta_v2.png
- windows_warm_v2.png
- city_glow_soft_v2.png
- atmosphere_haze_v2.png
- lightning_flash_v2.png

LIGHTNING EVENT ASSETS
- lightning_bolt_a_v2.png
- lightning_bolt_b_v2.png
Both are transparent full-canvas event layers. They are normally invisible and must only appear during lightning events.

RAIN
- rain_back_drop_v2.png
- rain_front_drop_v2.png
Use as particle textures. Rain must be produced at runtime; do not bake rain into the master.

INTEGRATION RULES
1. V2 replaces V1 as the visual source for PASS 3.
2. Do not mix V1 light/glow overlays with Master V2.
3. Master + all full-canvas overlays must share identical transform.
4. At 1280x720 there must be no black border/letterboxing.
5. UI remains above all environmental effects.
6. Right side remains UI-safe; never recreate a black UI panel.
7. Lightning flash and bolt are event-only, alpha=0 when idle.
8. Rain, lights, atmosphere and lightning remain independently toggleable.
9. Preserve PASS 5 UI and the PackedInt32Array hotfix.
