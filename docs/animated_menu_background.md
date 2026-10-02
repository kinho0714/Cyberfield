# Animated menu background — PASS 4 / official V3

## Baseline and asset audit

Incremental over current PASS 3, branch master, HEAD 63a31efaaf5d96dd90b640561d39f304fc27f148. Historical changes preserved.
ZIP SHA256: ded7ee2ae904a27e17aadb00720f40e5f9dcf8eccca25b519985adf874cd8464.
24 SHA256SUMS entries matched; all 22 PNGs decoded. Masters RGB; all environmental textures RGBA with nonempty alpha. Original files copied byte-identically into assets/ui/menu/animated/v3, including README, metadata and hashes. No generated import files or global settings changes.

Separate reference is 1536x864; technical Master is 1664x936, normalized by the producer from 1672x941 with crop (4,2,1668,938). Visual composition agrees, but separate reference and package are not pixel-identical. Runtime source is the official packaged 1664x936 Master. Runtime-reference 1280x720 variant is retained unused.

## Fullscreen and depth

Same PASS 3 cover formula: factor=max(viewport_width/1664,viewport_height/936), centered, clipped by the root. At1280x720 factor=10/13, position=(0,0), output exactly1280x720. Other aspects uniformly cover and crop excess. Every full-canvas overlay shares Composition transform. No active V1/V2 path; legacy files remain untouched.

Sibling draw order: Master; flash; six bolts; Back A/B/mask; Front A/B/mask; atmosphere; city light overlays/glow; native rain. UI remains above environment CanvasLayer89. Bolts therefore remain beneath transparent clouds, with cloud alpha naturally attenuating them. No new panel behind UI.

## Clouds

Four cloud Sprite2D plus two event-only light-mask Sprite2D. Back moves left-to-right2 source px/s, Front3.5; logical speeds1.538/2.692 px/s at1280x720. Base opacity .65/.80. All four official cloud textures are used; masks start alpha0.

Assets have nonzero, mismatched side-edge alpha. Direct adjacent tiling would create seams. menu_clouds.gdshader samples each official texture at two horizontal phases half a canvas apart. Smooth weights drop to zero near each sample edge; their sum is always at least1, so a non-seam sample covers every phase. Premultiplied color mixing avoids transparent-edge halos. UV.x-scroll moves right; fposmod phase wrap is continuous. No PNG modification, generated cloud artwork, extra viewport or GDScript pixel loop. Periods832s back and475.43s front; visual seam quality remains an Android test.

Masks use the same group scroll and loop math. During events a smooth horizontal localization centers on the selected bolt's alpha-weighted x centroid, measured from supplied textures: .200271,.475109,.718880,.314004,.574766,.826206. This approximates internal cloud lighting cheaply; masks are not permanent extra cloud layers.

clouds_enabled hides all six nodes, stops phase updates and zeros masks. Disabling lightning also clears masks; other modules remain independent. Phase is retained during page navigation through existing persistent environment.

## Lightning

Six full-canvas sprites, original positions unmodified: Large1/2/3 and Short1/2/3. Every event first chooses category:65%short,35%large. Then uniformly chooses a variant excluding previous variant. No immediate repetition; all six reachable. Interval12–30s, independent of other events.

Sequence:20–60ms weak localized cloud pre-glow (up to.15); main flash+bolt decay220ms; cloud response.65 decays420ms. City glow adds up to.10 above normal base.30%chance second pulse, same bolt, starts340ms after main,140ms duration,45%strength; cloud afterglow up to.40 decays320ms. By700ms after main, all event strengths explicitly zero. Main flash intensity.85. All bolts/flash/masks alpha0 at idle. Disabling module resets event. No coroutine/timer/Tween callbacks.

## Rain/lights/atmosphere

Existing native CPUParticles2D retained:112back+28front, two emitters,30Hz. V3 drop textures only. Source velocities widened modestly:209.1–300.9back;418.2–601.8front. Multiply10/13 for1280x720. Scale ranges .40–.60 / .65–.85, alpha .72/.90; lifetimes5.6/3.2s, randomness.08, spread2 degrees, direction-16degrees. Emission width now derives from Master width with upstream wind margin. No per-drop GDScript.

Opacity intensity variation .82–1.18 every9–18s, smooth .035/s. Existing right-side falloff to55% preserved. No aggressive count increase.

V3 cyan,magenta,warm windows,city glow retain PASS3 behavior and event cadence6–12s. Windows regions0..555,555..1110,1110..1664; magenta halves832pixels; region position matches source crop exactly. Haze V3 remains separate from clouds, alpha.32–.52, no translation. Dimming additive overlays does not erase baked city illumination.

## Inspector, lifecycle, persistence

Exports retained: rain_enabled,lights_enabled,atmosphere_enabled,lightning_enabled; rain_base_amount/variation/angle/speed; light_event_min/max_interval; lightning_min/max_interval/intensity. Added clouds_enabled,cloud_back_speed,cloud_front_speed. Debug rain/lights/lightning all false. No debug panel or extra cloud debug needed: temporarily raise exposed cloud speed in Remote Inspector, then restore2/3.5.

trigger_lightning() or one-shot debug_force_lightning tests full pre-glow/bolt/flash/afterglow. debug_force_rain increases opacity only; debug_force_lights tests overlay intensity. Debug respects enabled flags. Rain constructor parameters need disable/re-enable to rebuild emitters.

No changes to MenuEnvironment bridge, main scene, UI scripts, Options/LAN/Pause. Existing single instance persists across Main/Mode/Difficulty/Coop/LAN/Options. Gameplay Pause does not insert city. No page-dependent cloud reset. Modules update only while enabled/visible; rain is freed on disable; all nodes/materials owned by background, no orphan async callbacks.

## Validation and physical limits

Eight Python/Pillow static tests pass: hashes/decode/modes/alpha, paths/resources, region alignment, uniform cover, lightning idle/depth/no-repeat, cloud weight coverage and speeds, persistence/UI contracts, native rain/toggles. git diff --check passes. Patch is checked/applied/reverse-checked against an isolated copy of the exact local PASS3 baseline, with byte comparison.

UI and cyan selection, PackedInt32Array hotfix, export_presets.cfg, gameplay, networking, InputMap and other historical files are byte-identical to pre-task baseline. No commit/push. No file deletions.

GODOT RUNTIME: NÃO TESTADO — GODOT 4.7.2 INDISPONÍVEL NO AMBIENTE.
External GDScript parser unavailable too. Static tests do not compile GDScript/shaders or prove visual correctness.

A15 tests must validate cloud appearance/seams/depth, mask alignment/local glow, all six bolts/idle cleanup, fullscreen, rain, UI/touch, persistence and FPS. Six cloud/mask full-canvas nodes add fill-rate cost; two texture samples each, no blur/Light2D/additionalViewport. Masks have zero alpha outside events. No visual runtime approval claimed.

## PASS 5 — environmental tuning and compact menu

Authoritative UI baseline: user-uploaded main_menu_alive.gd from Android, applied before computing task delta. Local previous copy is retained outside repository for recovery. The uploaded _move_focus is preserved literally. Unlike the prompt's historical description, this file has no ItemList/PackedInt32Array branch; no := replacement was introduced. Its OptionButton branch calls ensure_current_is_visible(), while current input/process callers return before dispatching when popup is open. This preexisting branch was not rewritten in a visual-only pass; actual Godot navigation validation remains required. No claim of runtime parser or OptionButton verification is made.

Environment changes only exported defaults and four cloud node alphas:
- Back speed2 ->7 source px/s; Front3.5 ->11.5. At1280x720:5.385/8.846 logical px/s, displacement26.9/44.2px over5s.
- Back node alpha.65 ->.85; Front.80 ->.98. These multiply original texture alpha, not opaque clouds. Loop shader, light masks, transforms and source assets unchanged.
- Rain112/28 ->168/42; native simulation, velocity ranges209.1–300.9 /418.2–601.8 unchanged.
- Lightning12–30s ->7–16s, Inspector lower limit adjusted; six variants,65/35, no-repeat, pre-glow/afterglow,30%second pulse unchanged.
- City lights, atmosphere, Master/fullscreen and MenuEnvironment unchanged.

Menu uses same VBox pages and node paths/callbacks. Existing Center nodes become MarginContainers with right anchor1,48px inset, centered vertically via minimum-size growth. Base content widths:340 main/mode/difficulty/coop;440 Pause/Options;460 LAN. At1280 these occupy x892..1232, x792..1232, x772..1232 before larger text minimums. Growth direction is left, keeping right edge stable. Native minimum size handles long button text; labels wrap without max-line truncation. Frame extends8px horizontally (visible right margin40px),10px vertically. Main visual frame width356px (~27.8%screen); natural height follows content (~242px main). No full-height right panel.

Shared visual script: title28px (was40), main options26px (was30), dense page24px, secondary20px. Action targets56px high, dense52px; slider remains native. Padding and current-text cyan selection geometry unchanged. Thin1px cyan chamfered outline, alpha.55; fill alpha.10; single title separator alpha.25. Drawing adds no input Controls. Fade180ms retained. Functional methods including _move_focus, _input, _process, focus and transitions compared byte-for-byte to uploaded baseline. All node paths, UI texts, callback connections and attached scripts preserved. No new confirmation or flow; existing Solo goes directly from difficulty to run request/Laboratory. Coop and LAN retained.

No input hint added: optional, and no new device-detection mechanism or unverified binding label is introduced. InputMap unchanged. Settings controls and gameplay Pause behavior preserved; gameplay pause's original dimming overlay remains distinct from the small menu frame. UI smaller hit areas still require A15 physical confirmation.

Static tests updated for new speed defaults and exact authoritative _move_focus hash, replacing an assertion for the absent historical ItemList line. Eight tests pass. Scene structure/text/callback invariants checked against baseline. All unrelated file hashes unchanged. No PNG, shader, gameplay, network, InputMap, export_presets.cfg or Laboratory edit. No new/deleted project files.

GODOT RUNTIME: NÃO TESTADO — GODOT 4.7.2 INDISPONÍVEL NO AMBIENTE.
Android must test compact geometry/long text, keyboard/mouse/touch/gamepad/Options, no overflow, faster cloud seams,210particle performance and lightning frequency. Static checks are not runtime approval.
