You are generating Mac App Store marketing screenshots for the app
{{APP_NAME}} (built app at {{APP_PATH}}). Produce polished, upload-ready
images — but do not upload anything to Apple. Stage them locally and open the
folder for human review first.

Hard requirements
- Output: exactly 2560×1600 PNG (valid Mac App Store size); every image in the
 set must match. (Other valid sizes: 1280×800, 1440×900, 2880×1800 — pick one,
 use it for all.)
- Output folder: {{REPO}}/appstore-screenshots/en-US/, named 01-*.png,
02-*.png… in display order.
- Capture the real running app — never mock the UI.
- Scrub sensitive data (customer names, internal URLs, emails, secrets,
private filenames). Populate demo data or flag to the human before publishing.
- Leave the app running when done; kill any duplicate instances you launched.

Tools (macOS, no ImageMagick)
- screencapture -x -R<x>,<y>,<w>,<h> — region capture in points; Retina
outputs at 2× (1280×800-point region → 2560×1600 px).
- osascript/System Events — resize/move/frontmost windows, click menu-bar
items.
- sips — read/verify dimensions.
- Python 3 + PIL — precise cropping and final compositing. Fonts:
/System/Library/Fonts/SFNS.ttf (set_variation_by_name("Bold"/"Regular")).

Workflow
1. Launch & inventory — open the app, enumerate windows (size/position), pick
key screens (primary view, settings, signature feature).
2. Stage cleanly — resize primary window to 16:10 (e.g. 1280×800 pts) at a
known position, set frontmost, press Escape to dismiss stray menus, ensure no
overlap.
3. Capture raw — full-bleed windows via screencapture -R on the window
geometry; transient elements (menu-bar popovers) via full-screen capture then
PIL crop, iterating until only the element + its corner/arrow remain with no
background bleed.
4. Inspect every raw capture by Read-ing the PNG inline.
5. Compose with PIL (2560×1600 canvas each): dark vertical gradient
(#0E0F16→#1E1C2E) + soft radial glow (hue varied per screen); bold ~104px
white headline (~y=120) + ~46px gray subtitle (~y=250); app art scaled to fit
(full-bleed ~1840px wide, dialogs ~1600px, tall popovers ~1040px tall) with
rounded corners (r≈28) and a drop shadow (blur≈60, offset (0,30), alpha≈160),
centered, top ≈ y=360. Verify each is exactly 2560×1600 with sips.
6. Review handoff — open the folder, Read each final image inline, present a
table (filename → screen → headline), state nothing was sent to Apple, and
flag any sensitive data seen. Ask before scrubbing/regenerating or wiring an
upload lane.

Reusable PIL compositor: implement gradient(), rounded(img, radius),
with_shadow(art, blur, offset, alpha), centered text, and compose(art_path,
headline, sub, out_name, target_art_w|target_art_h, glow_color) → 2560×1600
PNG; call once per screen.

Do/Don't: ✅ real UI, verify dimensions, scrub data, leave app running, open
folder. ❌ no upload, no mocked UI, no mismatched sizes, no exposed internal
data, no skipping inline image verification.
