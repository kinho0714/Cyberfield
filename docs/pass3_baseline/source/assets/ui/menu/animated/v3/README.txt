CYBERFIELD — ANIMATED MENU ASSET PACK V3

SOURCE OF TRUTH
master/concept_master_v3_16x9.png
This is the approved V3 composition normalized to exact 16:9.
master/concept_master_v3_1280x720.png is the runtime-reference derivative.

V3 PRINCIPLE
Master V3 contains the permanent city/person/sky composition. Rain, lightning and moving cloud masses are runtime systems.

CLOUD PACK
Four RGBA cloud layers plus two illumination masks. Move left-to-right slowly. Use multiple copies/offsets for seamless coverage; do not expose an empty edge. Cloud light masks are event-only and should brighten locally during lightning.

LIGHTNING PACK
3 large + 3 short full-canvas transparent variants. Lightning renders BEHIND cloud layers. Avoid immediate repetition of the same variant. Short bolts may be more common than large bolts.

LIGHTNING COMPOSITION
normal -> localized cloud pre-glow -> flash + bolt -> city/glow response -> bolt decay -> cloud afterglow -> normal.
Bolts and flash alpha must be zero while idle.

LIGHTS
V3-only cyan, magenta, warm-window and city-glow overlays. Do not mix V1/V2 light overlays with Master V3.

RAIN
Runtime procedural particles only. Two provided drop textures. Do not bake rain into Master V3.

UI
All environmental systems remain behind UI. Preserve PASS 5 navigation/touch/cyan selection behavior until a dedicated compact-menu presentation pass.

ANDROID
Keep effects cheap for GL Compatibility / Samsung A15. No heavy blur, extra viewport or per-drop GDScript.
