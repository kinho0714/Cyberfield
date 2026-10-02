CYBERFIELD — Animated Menu Asset Pack v1
Source of truth: concept_master_official.png
Source dimensions: 1536x864
IMPORTANT: Do not regenerate, repaint, crop, or reinterpret the Concept Master.

Assets:
- lights_cyan.png: conservative cyan emissive-pixel overlay.
- lights_magenta.png: conservative magenta/red emissive-pixel overlay.
- windows_warm.png: warm window/light overlay.
- city_glow_soft.png: blurred city-light glow overlay.
- atmosphere_haze.png: subtle full-frame cool haze; animate alpha/offset minimally.
- rain_back_drop.png: small rain particle texture.
- rain_front_drop.png: larger foreground-city rain particle texture.
- lightning_flash_overlay.png: cold flash overlay; animate alpha only.

Integration rules:
1. All overlays use the exact master canvas 1536x864; align at identical origin/scale.
2. UI always renders above every background effect.
3. Keep the right side UI-safe; do not add a black panel.
4. Rain particles use the provided textures; do not implement per-drop GDScript.
5. Light overlays should normally be nearly invisible and animate alpha in independent groups.
6. Lightning overlay normally alpha=0; briefly animate during rare lightning events.
7. Atmosphere is subtle and optional.
8. Preserve module toggles: rain/lights/atmosphere/lightning.
9. Keep the background persistent through Main/Mode/Difficulty/Coop/LAN/Options as appropriate; Pause overlays it rather than replacing it.
10. Do not alter PASS 5 UI or PackedInt32Array hotfix.

Note:
The Concept Master itself contains baked rain and a baked visible lightning bolt. This pack does not destructively remove them.
