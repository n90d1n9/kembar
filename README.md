# Terminal Digital Twin — Yard 3D Container Placement

A Flutter + Riverpod slice of a Terminal Operating System's Digital Twin:
containers are placed at their **exact real yard position** (bay/row/tier
converted to true Cartesian meters using real ISO container dimensions and
real block pitches), rendered through **two interchangeable renderers** —
a full-fidelity GLB/lite_3d_core path and a native-Canvas path for true
instant updates — and kept live via a debounced or fully-live container
stream depending on which path is watching.

This is a focused, working vertical slice — not the full 30-step enterprise
platform from the source design doc. It's meant to be a correct, extensible
foundation for that larger roadmap (see **Next steps** below).

## Why these two packages, used this way

- **`lite_3d_core`** is the actual 3D scene engine — the same one that
  already powers the `tenun_3d` chart library (`Node3D`, `MeshBuilder.cuboid`,
  `GlbWriter` → GLB bytes → `flutter_3d_controller`). Containers are cuboids
  placed by `translation`, sized from real ISO 668 dimensions.
- **`goodmap`** is a lat/lng flat-map + globe library (MapLibre-based) — not
  a yard-slot tool. It's used for a *separate* "Geo Overview" tab (terminal
  location, vessels, gates), matching the multi-resolution twin concept from
  the wider design. Container placement does **not** go through goodmap.

## Architecture

```
domain/          pure Dart — entities, value objects, repository interfaces
application/      use-cases — position mapping, scene building (still no Flutter)
infrastructure/   adapters — lite_3d_core render adapter, GLB hosting, fake repos
presentation/     Flutter + Riverpod — providers, reusable widgets, screens
```

SOLID in practice here:
- **SRP** — mapping a slot to a position, building a scene, and rendering a
  scene are three separate classes, each independently testable.
- **OCP** — `ContainerPositionMapper` and `SceneRenderAdapter` are
  interfaces; a new placement strategy (e.g. RTLS-corrected) or render
  backend plugs in without editing existing code.
- **LSP/ISP** — small, specific interfaces (`ContainerRepository`,
  `YardLayoutRepository`) instead of one god-repository.
- **DIP** — everything above `infrastructure/` depends on interfaces, wired
  in `presentation/providers/repository_providers.dart`. Swapping the fake
  repositories for the real REST/WebSocket ones is a single provider
  override (`twinBackendConfigProvider`), not a rewrite — see **Real
  backend repositories** below.

## Two render paths — because "real-time" and "GLB reload" don't mix

This started with one renderer (GLB → `flutter_3d_controller`) and grew a
second one for a specific reason: **`flutter_3d_controller` has no way to
live-patch one container's color on an already-loaded model.** Its
`setTexture` API switches between a fixed set of texture/material
*variants* baked into the model at export time (the same mechanism as
glTF's `KHR_materials_variants`) — it's built for "switch the whole
model's finish," not "update container #4127's status independently of
the other 3,000." Every container mutation would mean regenerating the
whole GLB and reloading the whole viewer. That's not a minor inefficiency
for a "living, synchronized" twin — it's a fundamentally different feel
from real-time.

So there are now two interchangeable renderers behind a toggle in
`YardBlockTwinView`:

- **`DigitalTwinViewport`** — GLB via `lite_3d_core` + `flutter_3d_controller`.
  PBR materials, real lighting, the full fidelity of an actual 3D engine.
  Watches a **debounced** container stream (`debouncedContainersProvider`,
  400ms trailing-edge, first snapshot applied immediately) — bursts of
  updates coalesce into one rebuild instead of reloading the model on
  every single change.
- **`YardCanvasView` + `YardCanvasPainter`** — a native Flutter
  `CustomPainter`, no GLB/WebView/network involved at all. It projects
  `PlacedContainer`s straight from live data through a hand-built
  pinhole-camera model (`OrbitCamera`) every repaint. Watches the
  **un-debounced** stream (`placedContainersProvider`) directly, so a
  container mutation reaches the screen on the next frame — genuinely
  instant, not "reload, minus jank." The cost is fidelity: flat-shaded
  boxes with a fixed pseudo-light (top brighter than sides, sides
  brighter than bottom via simple backface-culling — see
  `application/scene/cuboid_geometry.dart`), not real PBR.

Neither one is strictly better — they're a genuine tradeoff between
fidelity and true liveness, made explicit and switchable rather than
picking one and hiding the cost.

**On "since `lite_3d_core` is your own project, you can improve it too":**
I only have `lite_3d_core`'s public API docs (fetched from pub.dev), not
its actual source or repository — I can't submit a real patch to files I
can't see. What I could do with confidence was build the Canvas path as a
genuine, independent addition, and be concrete about what a real fix
*inside* `lite_3d_core` would need: a `RendererBackend` (the abstraction
its own docs already reference, alongside FlutterScene/Three.js/WebGPU
adapters) that keeps a persistent, patchable scene in memory — e.g. a
`Flutter GPU`-backed backend where a per-node material color can be
mutated directly, without regenerating or re-parsing a GLB file at all.
`OrbitCamera` and `cuboid_geometry.dart` are pure Dart with no Flutter
dependency specifically so that math is directly reusable if that turns
into a real `lite_3d_core` backend later, rather than being stuck inside
this app.

Every non-trivial piece of the Canvas renderer's math was verified
numerically (in Python, before being written into Dart) rather than
trusted on the first derivation — worth knowing because the first version
of the camera's right-vector formula I wrote down by hand was wrong (a
sign/term error), and the numeric check is what caught it before it ever
became a silent "the box tilts the wrong way" bug.

## Real position, precisely

`SlotPositionMapper` (`application/mapping/slot_position_mapper.dart`)
converts `YardSlot(block, bay, row, tier)` into meters:

```
x (bay axis)  = (bay - 1)  * bayPitchM
z (row axis)  = (row - 1)  * rowPitchM
y (height)    = (tier - 1) * tierHeightM
```

then rotates by the block's `orientationDeg` and adds the block's real
`origin`, from `YardBlockLayout` — the terminal's own engineering data.
Container footprints use real ISO 668 dimensions (`IsoContainerSize`), so a
40ft container is placed and sized as 12.192 × 2.438 × 2.591 m, not an
arbitrary box. Verified by hand for a rotated block too: bay 2 at
`orientationDeg: 30` lands at `(5.629, 0, 3.25)`, not `(6.5, 0, 0)` — the
whole placement (including the ground plate under it, and the Canvas
renderer's box corners) rotates together using the same formula, not
three separately-derived ones that could quietly drift apart.

## Windowing — the actual answer to "will this scale"

`lite_3d_core` (v0.1.0) documents its GLB export as tuned for
tens-to-low-hundreds of nodes; a real yard block can hold thousands. The
honest constraint here: `flutter_3d_controller` doesn't expose camera
position or frustum back to Flutter, so there's no way to derive "what's
currently visible" and cull to it automatically — a "smart" LOD system
would be guessing. (The Canvas renderer doesn't have this specific
ceiling — it's plain Dart draw calls — but a real yard's container count
would still eventually want windowing for frame-time reasons on either
path.)

Instead, `YardWindowControl` puts a bay-range slider directly in the UI.
Narrowing it updates `yardWindowProvider(blockId)`, which both
`placedContainersProvider` and (via the debounced stream)
`twinGlbProvider` watch — so both renderers show only the containers
inside the window, and the container list is filtered to match (so you
can't tap a list entry for a container that isn't actually rendered).

## Tap-to-select on the Canvas renderer

Unlike the GLB path (no per-mesh picking available), the Canvas renderer
owns its own projection math, so it can genuinely hit-test taps against
container geometry. `application/scene/projected_scene.dart` computes
each visible face's screen-space polygon once; both `YardCanvasPainter`
(drawing) and `cuboid_hit_test.dart`'s `hitTestProjectedScene` (tap
selection) build on that same function, so what you can tap and what you
see are structurally guaranteed to agree — there's no separate hit-test
geometry that could quietly drift out of sync with the drawn one.

The point-in-polygon test is the standard ray-casting ("PNPOLY")
algorithm, verified against hand-checked cases (an axis-aligned square, a
rotated diamond, points just outside each edge) before being written into
Dart. Tap detection itself deliberately avoids `onTap`/`onScaleUpdate` on
one `GestureDetector` — see Known limits below for why — and instead
infers a tap from near-zero total pointer movement inside the scale
gesture.

## Real backend repositories

`RestYardLayoutRepository` and `WebSocketContainerRepository`
(`infrastructure/repositories/`) are complete, if unverified-against-a-
real-server, implementations — not wired in as the default, since there's
no live backend in this project to point them at. Switching to them is
one override at app startup, nothing else changes:

```dart
runApp(ProviderScope(
  overrides: [
    twinBackendConfigProvider.overrideWithValue(
      TwinBackendConfig(
        httpBaseUrl: Uri.parse('https://your-backend.example.com/twin/'),
        wsBaseUrl: Uri.parse('wss://your-backend.example.com/twin/'),
      ),
    ),
  ],
  child: const TerminalDigitalTwinApp(),
));
```

`TwinBackendConfig`'s doc comment specifies the REST/WebSocket wire format
these repositories expect — adjust `ContainerTwinDto`/`YardBlockLayoutDto`
and the path segments in the two repositories if your backend's shape
differs. The WebSocket repository reconnects with capped exponential
backoff (2s → 4s → 8s → 16s → 30s, holding at 30s) and ties the real
socket's lifetime to subscriber count via the stream's onListen/onCancel —
though that teardown only actually fires in practice if these providers
are used as `.autoDispose` (a plain family provider keeps one internal
subscription alive for the app's lifetime once first read).

## Running it

This environment has no Flutter/Dart SDK and no pub.dev access, so the code
could not be compiled or `flutter analyze`'d here. To run it:

```bash
cd terminal_digital_twin
flutter create .        # generates android/, ios/, web/, etc. — do this first
flutter pub get
```

Then, **before running on web**, add to `web/index.html`'s `<head>` (per
each package's own install docs):

```html
<script src="https://unpkg.com/maplibre-gl@5.23.0/dist/maplibre-gl.js"></script>
<link href="https://unpkg.com/maplibre-gl@5.23.0/dist/maplibre-gl.css" rel="stylesheet" />
<script type="module" src="./assets/packages/flutter_3d_controller/assets/model_viewer.min.js" defer></script>
```

For Android/iOS, `flutter_3d_controller` needs `minSdkVersion 21`, the
`INTERNET` permission (already required — the app also runs a **loopback-
only** HTTP server, see below), and `io.flutter.embedded_views_preview` set
in `Info.plist`. `goodmap`'s flat map needs iOS 13+ / `minSdkVersion 21`
too. Full details are in each package's pub.dev "Installing" tab.

Then:

```bash
flutter run
```

## A design decision worth knowing about

`flutter_3d_controller`'s documented `src` supports Flutter assets and
URLs — not confirmed arbitrary local file paths. Rather than gamble on
undocumented behavior, `GlbHostingStrategy` hosts each generated scene
behind a real URL:

- **Native (`glb_hosting_strategy_io.dart`)** — a tiny `dart:io
  HttpServer` bound to `127.0.0.1` on an ephemeral port, serving scenes
  from an in-memory map. No extra dependency, not reachable off-device.
- **Web (`glb_hosting_strategy_web.dart`)** — a `Blob` object URL, which
  `<model-viewer>` accepts natively.

Selected via a standard Dart conditional export
(`glb_hosting_strategy_factory.dart`), so no `dart:io`/`dart:html` import
ever reaches a platform that doesn't have it.

## Known limits (being upfront, not hiding them)

1. **The demo data is fake and leaks timers.** `FakeContainerRepository`
   never cancels its `Timer.periodic` — fine for one long-lived demo
   screen, not for production. `WebSocketContainerRepository` does this
   properly, which is the intended real-world replacement.
2. **`EquirectangularGeoTransformer` is an approximation**, valid for a
   terminal's own footprint, not for large-area geodesy.
3. **The REST/WebSocket wire format is invented**, not drawn from a real
   backend's spec — documented in `TwinBackendConfig` and easy to adjust,
   but treat it as a starting contract, not a given one.
4. **The GLB renderer still resets on mode toggle.** `YardCanvasView`
   (Canvas) now stays mounted (`Offstage`, not destroyed) across toggles
   specifically so its camera survives switching away and back — but
   `DigitalTwinViewport` doesn't get the same treatment, since keeping a
   WebView-backed 3D viewer alive off-screen indefinitely is a real
   resource cost. An accepted, asymmetric tradeoff.
5. **Double-tap-to-reset and tap-to-select can both fire from one
   double-tap** on the Canvas renderer. Tap detection deliberately avoids
   mixing `onTap` with `onScaleStart`/`onScaleUpdate` on one
   `GestureDetector` (Flutter's own docs note scale is a strict superset
   of pan, and there are confirmed reports of `onScale` firing for
   apparent taps) — instead it infers a tap from near-zero total movement
   inside the scale gesture itself. The tradeoff: a double-tap's first
   tap can also read as a zero-movement scale gesture, so a container
   might get selected right before the camera resets. Minor UX quirk,
   not broken behavior.
6. **Container-stream errors are swallowed by the debounce listener** —
   `DebouncedContainersController` only forwards `valueOrNull`, so an
   `AsyncValue.error` on the underlying stream never reaches
   `twinGlbProvider`. Neither current repository ever actually puts the
   stream itself in an error state (`WebSocketContainerRepository`
   handles failures internally via reconnect, never `controller.addError`),
   so this doesn't bite today — but a future repository that does emit
   stream errors would need this listener extended to check `next.hasError`.
7. **Unverified against a real compiler.** No Flutter SDK was available in
   this sandbox — treat your first `flutter pub get && flutter analyze` as
   the real verification step, especially for `lite_3d_core` (0.1.0) and
   `goodmap` (0.6.0). Every relative import path and brace/paren balance
   across all 55 files was checked programmatically; the position math,
   the orbit camera's basis vectors, the face-culling logic, and the
   point-in-polygon hit-test were all hand-verified numerically in Python
   before being written into Dart (catching one real sign error in the
   camera math, and one real gesture-semantics mistake around
   `focalPointDelta` vs `scale`, before either shipped) — but none of
   that substitutes for a real `flutter analyze`.

## Next steps (toward the fuller platform design)

- Lift `OrbitCamera` state to a provider so the *GLB* path's camera can
  survive mode toggles too, not just the Canvas path's.
- Chunk very large blocks by sub-block and lazy-load on pan/zoom, on top
  of the bay-range window, if a single block's container count is high
  even within a narrowed window.
- Add other twin types (RTG, QC, trucks, vessels) using
  `GeoToLocalTransformer` for GPS-tracked equipment, composited into the
  same scene as containers — on the Canvas path this is a plain data
  addition; on the GLB path it goes through `Lite3dSceneRenderAdapter`.
- Time-travel / snapshot replay (`TwinHistory` in the source design) by
  adding a `DateTime` parameter to the repositories and letting the fake
  (then real) implementation replay historical state.
- Point `twinBackendConfigProvider` at a real backend and adjust the DTOs/
  path segments to match its actual wire format.
- If `lite_3d_core` ever grows a persistent/patchable renderer backend
  (see the design note above), the GLB path could adopt true per-node
  live updates too, closing the gap with the Canvas path's immediacy
  without losing PBR fidelity.
