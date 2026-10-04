CYBERFIELD HUD/UI — GODOT INTEGRATION README
Target: Godot 4.7.2 Stable, GL Compatibility, logical 1280x720, PC + Android.

SOURCE OF TRUTH
Only the five approved reference screenshots in references/. They are documentation, never runtime textures.

SHARED VS MOBILE
assets/shared is used on PC and Android. assets/mobile is touch/mobile-only and should be hidden when touch UI is not active.

MANIFEST + LAYOUTS
cyberfield_hud_ui_master_manifest_v1.json contains stable asset IDs, dimensions, 9-slice margins, states, anchors and bindings.
layouts/*.json contains 1280x720 placements. Coordinates are top-left logical pixels unless anchor says otherwise.

9-SLICE
Use NinePatchRect for assets with scalable=true. Use the exact margins in the manifest. Do not stretch decorative corners.

DYNAMIC CONTENT
Use manifests/dynamic_bindings_v1.json. HP fill, portrait, counters, timer, minimap, inventory item content, settings values and input hints are runtime.
Use Godot Labels for UI text. Do not bake changing numbers/text into textures.

HUD
Normal HUD is modular. Low HP adds player_frame_critical_accent + low_hp_vignette; it is not a second independent HUD.
Godot controls vignette opacity/pulse and HP fill clipping.

MOBILE
Joystick base and knob are separate. Action frame and icon are separate. Labels CURAR/USAR/DASH/PULO/ATQ1/ATQ2 are runtime.
Pressed/disabled/cooldown visual behavior is IMPLEMENTATION_STYLE via modulate/opacity/mask/animation because no distinct approved sprite state exists.

INVENTORY
Concept item illustrations are not canonical Cyberfield weapon/item assets and were deliberately not extracted. Slots/cards accept runtime item textures and text.

SETTINGS
Build tabs, rows, sliders and difficulty cards from modular components. Values and labels are runtime.

MINIMAP
Only frame/decoration is static. Map content is always runtime.

REFERENCE_ONLY/BLOCKED
Never use reference screenshots or any blocked/reference-only entry as runtime art.
No GDScript is included and this bundle does not modify the Godot project.
