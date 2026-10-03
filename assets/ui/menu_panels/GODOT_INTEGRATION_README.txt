Checkpoint 4 — Pause / inventory / settings presentation
Source: cyberfield_hud_ui_complete_integration_bundle_v1.zip
Source SHA-256: 584b0b31883dc2111a50f60a309af7479d68af50c03aec17c0663d6e0be0f12f
13 unmodified runtime-ready PNGs; used_assets.json records official metadata/hashes.
NinePatchRect and StyleBoxTexture use the exact manifest slice margins.

Existing right-side Pause/Settings layout, scroll, popup and callbacks remain.
Settings keeps its approved single scrolling list rather than adding category tabs
or fake video settings. Camera zoom, mobile scale, debug and all four audio buses
retain their backend and input contracts. Slider styles are signal-driven.
Inventory presents only the two actual equipped weapon slots and WeaponCatalog
values. Activating a slot still uses the existing explicit equip action; merely
focusing it does not equip anything. No gadgets, concept items or empty future
slots. Details remain inside existing cards; no fictitious status/run tabs.
Panel decorations are behind contents and ignore input. A Node2D holder excludes
Pause/Settings decoration from VBox layout. No new per-frame processing.
All menus retain original anchor/layout contracts instead of enforcing concept
screenshot dimensions. Inventory receives a 22px panel inset. Fullscreen dimming
is 0.60, while official panel textures provide localized contrast.

Physical Godot 4.7.2/Android validation remains required: navigate every page,
return focus/input, test LAN local-only modal behavior, scroll all audio controls,
open/select/close camera dropdown, drag sliders horizontally and scroll vertically.
