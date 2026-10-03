CYBERFIELD — CASA DE JHON JHONES — GODOT INTEGRATION README
ENGINE: Godot 4.7.2 | Renderer: GL Compatibility | PC + Android
Logical resolution: 1280x720 | Structural grid: 64x64 | Character reference: 64 px

SOURCE OF TRUTH
24945.png, approved Casa de Jhon concept. Assembly references are documentation, never new art sources.

BUNDLE
assets/: canonical runtime atlases and environment reference crops.
manifests/casa_jhon_master_manifest_v1.json: canonical asset IDs, exact atlas regions and metadata.
layouts/: complete per-stage instances in top-left documentary coordinates (+X right, +Y down).
deltas/: Stage N-1 -> Stage N additions/removals/replacements/overlays/moves.
references/: assembly references and blocked/reference-only SPARK visual.
reports/: validation results.

GODOT
For atlas assets use AtlasTexture regions exactly as listed in master manifest.
Structural collision_candidate=true means collision should be authored deliberately; do not infer collision from alpha.
recommended_origin_x/y are local asset anchors. Layout position_x/y are documentary world placement anchors.
Interactive objects remain separate Node2D/Sprite2D/Area2D candidates and are not baked into structure.
P0=PERMANENT, P1=PERSISTENT_WITH_MODIFICATION, S=SLOT, E=EXPANSION, D=DECORATIVE.

PROGRESSION
Stage0 is historical base. Stage1=Stage0+Delta1. Stage2=Stage1+Delta2. Stage3=Stage2+Delta3.
Do not rebuild later stages as independent maps.

SPARK
Slot E anchor is present in every layout. spark_project_reference is BLOCKED/REFERENCE_ONLY because clean alpha cannot be guaranteed from the approved concept. Do not use it as runtime art.

BACKGROUNDS
Current FAR/MID/NEAR files are REFERENCE_ONLY due source resolution. Do not upscale them into runtime backgrounds.
Foreground/atmosphere runtime assets are BLOCKED where source information is insufficient.

ASSEMBLY REFERENCES
Documentation only. Never import them as full runtime scenery. Reconstruct runtime from master manifest + stage layout.

PIXEL ART
Do not apply arbitrary upscale or blurred filtering. Preserve source pixels. Test texture filtering and mobile import settings physically.
